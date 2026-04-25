import json
import logging
from io import BytesIO

from fastapi import APIRouter, File, HTTPException, UploadFile
from openai import AsyncOpenAI
from pydantic import BaseModel
from pypdf import PdfReader

from ..config import settings

logger = logging.getLogger(__name__)

router = APIRouter()


# ── Request bodies ──────────────────────────────────────────────────────────

class AnalyzeRequest(BaseModel):
    cvText: str
    apiKey: str = ""


# ── Helpers ──────────────────────────────────────────────────────────────────

def _openai_client(api_key: str) -> AsyncOpenAI:
    key = api_key or settings.agnicpay_api_key
    if not key:
        raise HTTPException(status_code=500, detail="No API key configured on server")
    return AsyncOpenAI(api_key=key, base_url=settings.agnic_llm_base)


def _raise_ai_error(exc: Exception) -> None:
    msg = str(exc)
    if "expired" in msg or "invalid_api_key" in msg or "401" in msg:
        raise HTTPException(status_code=401, detail="Agnic token expired — please sign in again")
    raise HTTPException(status_code=502, detail=f"AI call failed: {exc}")


async def _chat_json(api_key: str, system: str, user: str) -> dict:
    client = _openai_client(api_key)
    logger.info("Calling AI API at base_url=%s model=openai/gpt-4o", settings.agnic_llm_base)
    resp = await client.chat.completions.create(
        model="openai/gpt-4o",
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        response_format={"type": "json_object"},
        temperature=0.7,
    )
    return json.loads(resp.choices[0].message.content)


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/parse")
async def parse_cv(cv: UploadFile = File(...)):
    """Accept a PDF or TXT résumé and return its plain text."""
    content = await cv.read()
    filename = cv.filename or ""

    if cv.content_type == "application/pdf" or filename.lower().endswith(".pdf"):
        try:
            reader = PdfReader(BytesIO(content))
            text = "\n".join(page.extract_text() or "" for page in reader.pages)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"PDF parsing failed: {e}")
    elif cv.content_type == "text/plain" or filename.lower().endswith(".txt"):
        text = content.decode("utf-8", errors="replace")
    else:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{cv.content_type}'. Upload a PDF or TXT.",
        )

    text = text.strip()
    if not text:
        raise HTTPException(
            status_code=400, detail="Could not extract text. File may be empty or image-only."
        )

    return {"status": "OK", "data": {"text": text}}


@router.post("/analyze")
async def analyze_cv(body: AnalyzeRequest):
    """Run AI analysis on résumé text. Returns extracted criteria + improvements."""
    logger.info("analyze_cv: apiKey_len=%d cvText_len=%d", len(body.apiKey), len(body.cvText))
    system = """You are an expert CV and résumé reviewer — senior recruiter and hiring manager across multiple industries.

Analyze the provided CV and return a JSON object with exactly this structure:
{
  "extractedCriteria": {
    "jobTitles": ["2-4 suitable job titles based on experience"],
    "skills": ["key technical and soft skills"],
    "yearsOfExperience": <integer>,
    "preferredLocations": ["locations mentioned or inferred"],
    "isRemotePreferred": <boolean>,
    "salaryRange": { "min": <integer or null>, "max": <integer or null>, "currency": "USD" },
    "industries": ["relevant industries"]
  },
  "improvements": [
    {
      "title": "Short improvement title",
      "description": "Specific, actionable explanation. Avoid generic advice.",
      "priority": "high" | "medium" | "low"
    }
  ],
  "summary": "2-3 sentence candidate profile summary"
}

Provide 3-5 distinct improvement suggestions prioritising high-impact issues."""

    try:
        data = await _chat_json(
            body.apiKey,
            system,
            f"Please analyse this CV:\n\n{body.cvText}",
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error("AI analysis failed: %s: %s", type(e).__name__, e, exc_info=True)
        _raise_ai_error(e)

    return {"status": "OK", "data": data}


@router.post("/detailed-review")
async def detailed_review(body: AnalyzeRequest):
    """Section-by-section review plus ATS compatibility scoring."""
    system = """You are an expert CV reviewer and ATS specialist.

Return a JSON object with exactly this structure:
{
  "sectionFeedback": [
    {
      "section": "<section name e.g. Summary, Experience, Skills, Education>",
      "status": "success" | "warning" | "error",
      "message": "<brief assessment of this section>",
      "suggestions": ["specific actionable fix with Before/After examples from their actual CV"]
    }
  ],
  "atsEvaluation": {
    "score": <integer 0-100>,
    "breakdown": {
      "parseability": <0-25>,
      "keywordAlignment": <0-30>,
      "formattingSimplicity": <0-15>,
      "sectionCompleteness": <0-15>,
      "roleSignalStrength": <0-15>
    },
    "explanation": "What most affected the ATS score",
    "topFixes": ["top 5 ATS-specific fixes"],
    "warnings": ["critical parsing warnings"]
  }
}

Score breakdown maximums: parseability 25, keywordAlignment 30, formattingSimplicity 15, sectionCompleteness 15, roleSignalStrength 15."""

    try:
        data = await _chat_json(
            body.apiKey,
            system,
            f"Please perform a detailed review and ATS evaluation for this CV:\n\n{body.cvText}",
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error("AI detailed-review failed: %s: %s", type(e).__name__, e, exc_info=True)
        _raise_ai_error(e)

    return {"status": "OK", "data": data}
