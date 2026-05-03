import asyncio
import hashlib
import json
import logging
from datetime import datetime, timezone, timedelta
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException
from openai import AsyncOpenAI
from pydantic import BaseModel

from ..config import settings
from ..database import get_db

logger = logging.getLogger(__name__)

router = APIRouter()

_CACHE_TTL_HOURS = 6
_EXPAND_MODELS = ["openai/gpt-5", "anthropic/claude-sonnet-4"]
_EXPAND_BATCH_SIZE = 6   # titles per extra search query
_EXPAND_BATCH_COUNT = 2  # max extra queries (2 × 6 = 12 expanded titles searched)


# ── Request bodies ────────────────────────────────────────────────────────────

class JobSearchRequest(BaseModel):
    jobTitles: list[str] = []
    locations: list[str] = []
    isRemote: bool = False
    salaryMin: int | None = None
    jobTypes: list[str] = []   # multi-select; empty = any
    jobType: str = "Any"       # legacy single-select fallback
    resumeText: str = ""
    apiKey: str


class JobDetailsRequest(BaseModel):
    job_id: str
    apiKey: str


class SalaryRequest(BaseModel):
    job_title: str
    location: str
    apiKey: str


# ── Query helpers ─────────────────────────────────────────────────────────────

def _build_query(req: JobSearchRequest) -> str:
    parts = []
    if req.jobTitles:
        parts.append(" OR ".join(req.jobTitles))
    if req.locations:
        parts.append("in " + " or ".join(req.locations))
    if req.isRemote:
        parts.append("remote")
    types = req.jobTypes or ([req.jobType] if req.jobType and req.jobType != "Any" else [])
    if types:
        parts.append(" OR ".join(types))
    return " ".join(parts) or "software engineer"


def _build_titles_query(titles: list[str], req: JobSearchRequest) -> str:
    """Like _build_query but with a custom title list (for expanded batches)."""
    parts = [" OR ".join(titles)]
    if req.locations:
        parts.append("in " + " or ".join(req.locations))
    if req.isRemote:
        parts.append("remote")
    types = req.jobTypes or ([req.jobType] if req.jobType and req.jobType != "Any" else [])
    if types:
        parts.append(" OR ".join(types))
    return " ".join(parts)


# ── Cache ─────────────────────────────────────────────────────────────────────

def _cache_key(query: str) -> str:
    return hashlib.md5(query.lower().encode()).hexdigest()


async def _get_cached(query: str) -> list[dict] | None:
    try:
        db = get_db()
        key = _cache_key(query)
        doc = await db.job_cache.find_one({"_id": key})
        if not doc:
            return None
        age = datetime.now(timezone.utc) - doc["cached_at"].replace(tzinfo=timezone.utc)
        if age > timedelta(hours=_CACHE_TTL_HOURS):
            return None
        return doc["jobs"]
    except Exception:
        return None


async def _set_cached(query: str, jobs: list[dict]) -> None:
    try:
        db = get_db()
        key = _cache_key(query)
        await db.job_cache.replace_one(
            {"_id": key},
            {"_id": key, "query": query, "jobs": jobs, "cached_at": datetime.now(timezone.utc)},
            upsert=True,
        )
    except Exception:
        pass


# ── LLM title expansion ───────────────────────────────────────────────────────

async def _llm_expand_titles(
    resume_text: str,
    existing_titles: list[str],
    model: str,
    api_key: str,
) -> list[str]:
    """Ask one LLM model for creative job title suggestions based on the resume."""
    key = api_key or settings.agnicpay_api_key
    if not key:
        return []
    existing_str = ", ".join(existing_titles) if existing_titles else "none"
    client = AsyncOpenAI(api_key=key, base_url=settings.agnic_llm_base)
    try:
        resp = await client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a creative career counselor. "
                        "Return ONLY a JSON array of job title strings — no markdown, no explanation."
                    ),
                },
                {
                    "role": "user",
                    "content": (
                        f"Given this resume, suggest 15 job titles this person could succeed at.\n"
                        f"Include obvious matches AND surprising career pivots "
                        f"(e.g. a software engineer could be a CS educator, technical writer, "
                        f"product manager, UX researcher, etc).\n"
                        f"The candidate already has these in mind: {existing_str}\n"
                        f"Suggest DIFFERENT titles — diverse and creative.\n\n"
                        f"Resume:\n{resume_text[:3000]}\n\n"
                        f'Return ONLY a JSON array, e.g. ["Title 1", "Title 2", ...]'
                    ),
                },
            ],
            temperature=0.85,
        )
        content = resp.choices[0].message.content or ""
        start = content.find("[")
        end = content.rfind("]") + 1
        if start >= 0 and end > start:
            parsed = json.loads(content[start:end])
            if isinstance(parsed, list):
                return [str(t).strip() for t in parsed if t]
    except Exception as e:
        logger.warning("_llm_expand_titles model=%s failed: %s", model, e)
    return []


async def _expand_job_titles(
    resume_text: str,
    existing_titles: list[str],
    api_key: str,
) -> list[str]:
    """Run GPT-5 and Claude Sonnet 4 in parallel; merge and dedup results."""
    results = await asyncio.gather(
        *[_llm_expand_titles(resume_text, existing_titles, m, api_key) for m in _EXPAND_MODELS],
        return_exceptions=True,
    )
    seen = {t.lower() for t in existing_titles}
    merged: list[str] = []
    for r in results:
        if isinstance(r, Exception):
            logger.warning("_expand_job_titles model failed: %s", r)
            continue
        for title in r:
            if title.lower() not in seen:
                seen.add(title.lower())
                merged.append(title)
    logger.info(
        "_expand_job_titles: models=%s counts=%s merged=%d",
        _EXPAND_MODELS,
        [len(r) if not isinstance(r, Exception) else 0 for r in results],
        len(merged),
    )
    return merged


# ── Provider dispatch ─────────────────────────────────────────────────────────

async def _search_serpapi(query: str) -> list[dict]:
    if not settings.serpapi_key:
        raise HTTPException(status_code=500, detail="SERPAPI_KEY not configured on server")
    logger.info("serpapi search query=%s", query)
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(
            "https://serpapi.com/search.json",
            params={"engine": "google_jobs", "q": query, "api_key": settings.serpapi_key},
        )
    if resp.status_code == 401:
        raise HTTPException(status_code=500, detail="SerpAPI key invalid or expired")
    resp.raise_for_status()
    data = resp.json()
    raw_jobs = data.get("jobs_results", [])
    return [_normalize_serpapi_job(j) for j in raw_jobs]


async def _search_agnic(query: str, api_key: str) -> list[dict]:
    effective_key = api_key or settings.agnicpay_api_key
    if not effective_key:
        raise HTTPException(status_code=500, detail="No Agnic API key configured")
    url = f"{settings.agnic_job_search_base}/search?query={httpx.URL(query)}"
    proxy_url = f"{settings.agnic_fetch_proxy}?url={httpx.URL(url)}"
    logger.info("agnic_fetch url=%s key_source=%s", url, "user" if api_key else "server")
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            proxy_url,
            headers={"X-Agnic-Token": effective_key, "Content-Type": "application/json"},
        )
    if resp.status_code == 401:
        logger.warning("agnic_fetch 401 from proxy url=%s", url)
        raise HTTPException(status_code=401, detail="Agnic token expired — please sign in again")
    resp.raise_for_status()
    raw_jobs = _extract_jobs(resp.json())
    return [_normalize_job(j) for j in raw_jobs]


async def _dispatch_search(query: str, api_key: str) -> list[dict]:
    provider = settings.job_search_provider.lower()
    logger.info("job_search provider=%s query=%s", provider, query)
    if provider == "serpapi":
        return await _search_serpapi(query)
    if provider == "agnic":
        return await _search_agnic(query, api_key)
    raise HTTPException(status_code=500, detail=f"Unknown JOB_SEARCH_PROVIDER: {provider}")


# ── Normalizers ───────────────────────────────────────────────────────────────

def _normalize_serpapi_job(raw: dict) -> dict:
    detected = raw.get("detected_extensions", {})
    salary = detected.get("salary")
    return {
        "id": raw.get("job_id", raw.get("title", "") + raw.get("company_name", "")),
        "title": raw.get("title", ""),
        "company": raw.get("company_name", ""),
        "location": raw.get("location", ""),
        "salary": salary,
        "description": raw.get("description"),
        "postedDate": detected.get("posted_at"),
        "applicationUrl": (raw.get("apply_options") or [{}])[0].get("link"),
        "companyLogo": raw.get("thumbnail"),
        "isRemote": "remote" in raw.get("location", "").lower(),
        "employmentType": detected.get("schedule_type"),
    }


def _normalize_job(raw: dict) -> dict:
    if "job_id" in raw:
        loc_parts = [raw.get("job_city"), raw.get("job_state"), raw.get("job_country")]
        location = ", ".join(p for p in loc_parts if p) or raw.get("job_location", "")
        sal_min = raw.get("job_min_salary")
        sal_max = raw.get("job_max_salary")
        salary = None
        if sal_min and sal_max:
            salary = f"${sal_min:,.0f} – ${sal_max:,.0f}"
        elif sal_min:
            salary = f"${sal_min:,.0f}+"
        emp_type_map = {
            "FULLTIME": "Full-time", "PARTTIME": "Part-time",
            "CONTRACTOR": "Contract", "INTERN": "Internship",
        }
        emp_type = raw.get("job_employment_type", "")
        return {
            "id": raw["job_id"],
            "title": raw.get("job_title", ""),
            "company": raw.get("employer_name", ""),
            "location": location,
            "salary": salary,
            "description": raw.get("job_description"),
            "postedDate": raw.get("job_posted_at_datetime_utc"),
            "applicationUrl": raw.get("job_apply_link"),
            "companyLogo": raw.get("employer_logo"),
            "isRemote": bool(raw.get("job_is_remote", False)),
            "employmentType": emp_type_map.get(emp_type, emp_type) or None,
        }
    return {
        "id": raw.get("id", raw.get("job_id", "")),
        "title": raw.get("title", raw.get("job_title", "")),
        "company": raw.get("company", raw.get("employer_name", "")),
        "location": raw.get("location", ""),
        "salary": raw.get("salary"),
        "description": raw.get("description", raw.get("job_description")),
        "postedDate": raw.get("postedDate", raw.get("posted_date")),
        "applicationUrl": raw.get("applicationUrl", raw.get("apply_link")),
        "companyLogo": raw.get("companyLogo", raw.get("employer_logo")),
        "isRemote": bool(raw.get("isRemote", raw.get("is_remote", False))),
        "employmentType": raw.get("employmentType", raw.get("employment_type")),
    }


def _extract_jobs(data: Any) -> list[dict]:
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ("jobs", "data", "results", "items"):
            val = data.get(key)
            if isinstance(val, list):
                return val
            if isinstance(val, dict):
                inner = _extract_jobs(val)
                if inner:
                    return inner
    return []


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/search")
async def search_jobs(body: JobSearchRequest):
    original_query = _build_query(body)

    # Build extra queries from LLM-expanded titles (only when resume provided)
    extra_queries: list[str] = []
    if body.resumeText.strip():
        try:
            expanded = await _expand_job_titles(body.resumeText, body.jobTitles, body.apiKey)
            for i in range(0, min(len(expanded), _EXPAND_BATCH_SIZE * _EXPAND_BATCH_COUNT), _EXPAND_BATCH_SIZE):
                batch = expanded[i : i + _EXPAND_BATCH_SIZE]
                if batch:
                    extra_queries.append(_build_titles_query(batch, body))
        except Exception as e:
            logger.warning("title expansion failed, falling back to original query: %s", e)

    all_queries = [original_query] + extra_queries

    # Fetch cache hits and misses in parallel
    cached_results = await asyncio.gather(*[_get_cached(q) for q in all_queries])

    uncached = [(q, i) for i, (q, r) in enumerate(zip(all_queries, cached_results)) if r is None]

    if uncached:
        fetched = await asyncio.gather(
            *[_dispatch_search(q, body.apiKey) for q, _ in uncached],
            return_exceptions=True,
        )
        results: list[list[dict]] = list(cached_results)  # type: ignore[arg-type]
        for (q, idx), result in zip(uncached, fetched):
            if isinstance(result, Exception):
                logger.warning("search failed query=%s: %s", q, result)
                results[idx] = []
            else:
                await _set_cached(q, result)
                results[idx] = result
    else:
        results = list(cached_results)  # type: ignore[arg-type]

    # Raise if original query (index 0) hard-failed
    if not results[0] and not extra_queries:
        raise HTTPException(status_code=502, detail="Job search failed")

    # Merge and dedup by job ID — original results first
    seen_ids: set[str] = set()
    all_jobs: list[dict] = []
    for job_list in results:
        for job in (job_list or []):
            jid = job.get("id", "")
            if jid and jid not in seen_ids:
                seen_ids.add(jid)
                all_jobs.append(job)

    logger.info(
        "search_jobs: queries=%d total_jobs=%d (original=%d expanded_batches=%d)",
        len(all_queries),
        len(all_jobs),
        len(results[0] or []),
        len(extra_queries),
    )
    return {"status": "OK", "data": {"jobs": all_jobs}}


@router.post("/details")
async def job_details(body: JobDetailsRequest):
    target_url = f"{settings.agnic_job_search_base}/job-details?job_id={body.job_id}"
    try:
        data = await _agnic_fetch(target_url, body.apiKey)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Job details fetch failed: {e}")
    return data


@router.post("/salary")
async def salary_estimate(body: SalaryRequest):
    target_url = (
        f"{settings.agnic_job_search_base}/estimated-salary"
        f"?job_title={httpx.URL(body.job_title)}"
        f"&location={httpx.URL(body.location)}"
        f"&location_type=ANY&years_of_experience=ALL"
    )
    try:
        data = await _agnic_fetch(target_url, body.apiKey)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Salary estimate failed: {e}")
    return data
