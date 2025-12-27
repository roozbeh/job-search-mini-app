import express from 'express';
import cors from 'cors';
import OpenAI from 'openai';
import multer from 'multer';
import { PDFParse } from 'pdf-parse';

// PDFParse is a class, but can be called as a function when used with await
// It returns a promise that resolves to the parsed PDF data
const pdf = PDFParse;

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Configure multer for file uploads (store in memory)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    // Accept PDF and TXT files by mimetype or extension
    // Some browsers send PDFs as application/octet-stream, so we check extension too
    const isPdf = file.mimetype === 'application/pdf' ||
      file.mimetype === 'application/octet-stream' ||
      file.originalname?.toLowerCase().endsWith('.pdf');
    const isTxt = file.mimetype === 'text/plain' ||
      file.originalname?.toLowerCase().endsWith('.txt');

    if (isPdf || isTxt) {
      cb(null, true);
    } else {
      cb(new Error(`Only PDF and TXT files are allowed. Received: ${file.mimetype}`));
    }
  },
});

const PORT = process.env.PORT || 3001;

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'job-search-mini-app-backend'
  });
});

app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'job-search-mini-app-backend'
  });
});

// Job Search API configuration - using AgnicPay proxy
const AGNIC_PAY_BASE = 'https://api.agnicpay.xyz/api/x402/fetch';
const JOB_SEARCH_API_BASE = 'https://api.agnichub.xyz/v1/custom/job-search';

// AgnicPay LLM base URL
const AGNIC_LLM_BASE = 'https://api.agnicpay.xyz/v1';

// Search jobs endpoint
app.post('/api/jobs/search', async (req, res) => {
  try {
    const { query, apiKey } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'Query is required' });
    }

    if (!apiKey) {
      return res.status(400).json({ error: 'API key is required' });
    }

    const targetUrl = `${JOB_SEARCH_API_BASE}/search?query=${encodeURIComponent(query)}`;

    const response = await fetch(
      `${AGNIC_PAY_BASE}?url=${encodeURIComponent(targetUrl)}`,
      {
        method: 'POST',
        headers: {
          'X-Agnic-Token': apiKey,
          'Content-Type': 'application/json',
        },
      }
    );

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Job search error:', error);
    res.status(500).json({ error: 'Failed to search jobs' });
  }
});

// Get job details endpoint
app.post('/api/jobs/details', async (req, res) => {
  try {
    const { job_id, apiKey } = req.body;

    if (!job_id) {
      return res.status(400).json({ error: 'Job ID is required' });
    }

    if (!apiKey) {
      return res.status(400).json({ error: 'API key is required' });
    }

    const targetUrl = `${JOB_SEARCH_API_BASE}/job-details?job_id=${encodeURIComponent(job_id)}`;

    const response = await fetch(
      `${AGNIC_PAY_BASE}?url=${encodeURIComponent(targetUrl)}`,
      {
        method: 'POST',
        headers: {
          'X-Agnic-Token': apiKey,
          'Content-Type': 'application/json',
        },
      }
    );

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Job details error:', error);
    res.status(500).json({ error: 'Failed to get job details' });
  }
});

// Get estimated salary endpoint
app.post('/api/jobs/salary', async (req, res) => {
  try {
    const { job_title, location, apiKey } = req.body;

    if (!job_title || !location) {
      return res.status(400).json({ error: 'Job title and location are required' });
    }

    if (!apiKey) {
      return res.status(400).json({ error: 'API key is required' });
    }

    const targetUrl = `${JOB_SEARCH_API_BASE}/estimated-salary?job_title=${encodeURIComponent(job_title)}&location=${encodeURIComponent(location)}&location_type=ANY&years_of_experience=ALL`;

    const response = await fetch(
      `${AGNIC_PAY_BASE}?url=${encodeURIComponent(targetUrl)}`,
      {
        method: 'POST',
        headers: {
          'X-Agnic-Token': apiKey,
          'Content-Type': 'application/json',
        },
      }
    );

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Salary estimation error:', error);
    res.status(500).json({ error: 'Failed to get salary estimation' });
  }
});

// Parse PDF/TXT file and return extracted text
app.post('/api/cv/parse', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    console.log('File received:', {
      mimetype: req.file.mimetype,
      size: req.file.size,
      originalname: req.file.originalname,
    });

    let text = '';

    if (req.file.mimetype === 'application/pdf' ||
      req.file.mimetype === 'application/octet-stream' ||
      req.file.originalname?.endsWith('.pdf')) {
      // Parse PDF
      try {
        console.log('Attempting to parse PDF...');
        // Convert Buffer to Uint8Array as required by PDFParse
        const uint8Array = new Uint8Array(req.file.buffer);
        const parser = new pdf(uint8Array);
        const pdfData = await parser.getText();
        text = pdfData.text || '';
        console.log('PDF parsed successfully, text length:', text.length);
      } catch (pdfError) {
        console.error('PDF parsing error:', pdfError);
        return res.status(500).json({
          error: 'Failed to parse PDF file',
          details: pdfError.message
        });
      }
    } else if (req.file.mimetype === 'text/plain' || req.file.originalname?.endsWith('.txt')) {
      // Parse TXT
      text = req.file.buffer.toString('utf-8');
      console.log('TXT file parsed, text length:', text.length);
    } else {
      return res.status(400).json({
        error: 'Unsupported file type. Please upload a PDF or TXT file.',
        receivedMimeType: req.file.mimetype
      });
    }

    if (!text.trim()) {
      return res.status(400).json({ error: 'Could not extract text from file. The file might be empty or corrupted.' });
    }

    res.json({ status: 'OK', data: { text: text.trim() } });
  } catch (error) {
    console.error('File parse error:', error);
    res.status(500).json({
      error: 'Failed to parse file',
      details: error.message
    });
  }
});

// Analyze CV endpoint - uses AgnicPay LLM proxy with user's API key
app.post('/api/cv/analyze', async (req, res) => {
  try {
    const { cvText, apiKey } = req.body;

    if (!cvText) {
      return res.status(400).json({ error: 'CV text is required' });
    }

    if (!apiKey) {
      return res.status(400).json({ error: 'API key is required' });
    }

    // Create OpenAI client with AgnicPay proxy and user's API key
    const openai = new OpenAI({
      apiKey: apiKey,
      baseURL: AGNIC_LLM_BASE,
    });

    const completion = await openai.chat.completions.create({
      model: 'openai/gpt-4o',
      messages: [
        {
          role: 'system',
          content: `You are an expert CV and résumé reviewer with experience equivalent to a senior recruiter and hiring manager across multiple industries.

Your task is to analyze a user-provided CV and give professional, constructive, and actionable feedback. You are not a cheerleader or a grammar checker; you are an expert advisor whose goal is to improve the CV’s effectiveness in real hiring situations.

When analyzing a CV, you must consider the following dimensions:

1. **Context Awareness**
   * Infer role level, industry, and seniority from the CV.
   * Adapt feedback to realistic expectations for that context.
   * Avoid one-size-fits-all rules (e.g., “one page only”).

2. **Clarity and Impact**
   * Evaluate whether the candidate’s value is clear within a quick scan.
   * Identify vague, filler-heavy, or responsibility-only bullet points.
   * Recommend outcome-focused, specific phrasing where appropriate.

3. **Structure and Readability**
   * Assess section order, formatting consistency, spacing, and scannability.
   * Flag issues that reduce readability or professional signaling.

4. **Achievements and Credibility**
   * Distinguish between activities and achievements.
   * Evaluate whether metrics, scope, and claims feel proportional and credible.
   * Gently flag overstatement or ambiguity as perception risks.

5. **Skills Alignment**
   * Check consistency between listed skills and demonstrated experience.
   * Identify missing critical skills for the inferred role.
   * Flag generic or non-differentiating skill entries.

6. **Language and Tone**
   * Prefer clear, direct, professional language.
   * Identify buzzwords, passive voice, or vague corporate phrasing.
   * Suggest improvements without rewriting the entire CV unless asked.

7. **ATS Compatibility**
   * Consider how the CV would perform in applicant tracking systems.
   * Flag formatting, structure, or keyword issues that may reduce parsing accuracy.

8. **Career Narrative**
   * Evaluate role progression, transitions, and gaps for coherence.
   * Highlight areas where a brief explanation could improve interpretation.

9. **Risk Signals**
   * Identify potential red flags (e.g., frequent short tenures, unclear titles).
   * Frame all risks as recruiter perception issues, not accusations.

### Output Requirements
Return a JSON response with this exact structure:
{
  "extractedCriteria": {
    "jobTitles": ["string array of 2-4 suitable job titles based on experience"],
    "skills": ["string array of key skills"],
    "yearsOfExperience": number,
    "preferredLocations": ["string array of locations mentioned or inferred"],
    "isRemotePreferred": boolean,
    "salaryRange": {
      "min": number or null,
      "max": number or null,
      "currency": "USD"
    },
    "industries": ["string array of relevant industries"]
  },
  "improvements": [
    {
      "title": "Short title for the improvement",
      "description": "Detailed explanation of what to improve and why. Be concise but specific. Avoid generic advice.",
      "priority": "high" | "medium" | "low"
    }
  ],
  "summary": "A brief 2-3 sentence summary of the candidate's profile"
}

Provide 3-5 distinct improvement suggestions, prioritizing high-impact issues.`
        },
        {
          role: 'user',
          content: `Please analyze this CV and provide job search criteria and improvement suggestions:\n\n${cvText}`
        }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.7,
    });

    const analysis = JSON.parse(completion.choices[0].message.content);
    res.json({ status: 'OK', data: analysis });
  } catch (error) {
    console.error('CV analysis error:', error);
    res.status(500).json({ error: 'Failed to analyze CV. Please check your API key.' });
  }
});

// Detailed CV Review endpoint
app.post('/api/cv/detailed-review', async (req, res) => {
  try {
    const { cvText, apiKey } = req.body;

    if (!cvText) {
      return res.status(400).json({ error: 'CV text is required' });
    }

    if (!apiKey) {
      return res.status(400).json({ error: 'API key is required' });
    }

    const openai = new OpenAI({
      apiKey: apiKey,
      baseURL: AGNIC_LLM_BASE,
    });

    const completion = await openai.chat.completions.create({
      model: 'openai/gpt-4o',
      messages: [
        {
          role: 'system',
          content: `You are an expert CV reviewer and ATS specialist. Your task is to provide a detailed section-by-section review of a CV AND an ATS compatibility evaluation.

PART 1: DETAILED SECTION REVIEW
Analyze each section of the CV (Summary, Experience, Education, Skills, etc.).
For each section, provide:
1. A status evaluation (success/warning/error).
2. A brief feedback summary.
3. **Specific, actionable recommendations** that include concrete examples based on the *actual content* of the CV.
   - When suggesting improvements, provide a "Before" (what they have now) vs "After" (how it should be rewritten) example.
   - Show exactly how to quantify achievements or clarify skills using the user's specific experience.

PART 2: ATS EVALUATION
You are an Applicant Tracking System (ATS)–focused résumé analyzer. Analyze the résumé and produce an ATS Compatibility Score from 0 to 100 based on these dimensions:
1. **Parseability (0–25 points)**: Standard headers, clean text, consistent dates, logical order.
2. **Keyword Alignment (0–30 points)**: Role-relevant keywords, natural embedding, balance, no stuffing.
3. **Formatting Simplicity (0–15 points)**: Plain fonts, no tables/columns/images, standard bullets.
4. **Section Completeness (0–15 points)**: Contact info, experience details, skills, education.
5. **Role Signal Strength (0–15 points)**: Alignment of title/skills/experience, clear focus.

OUTPUT FORMAT (JSON):
{
  "sectionFeedback": [
    {
      "sectionName": "string (e.g., 'Summary', 'Experience')",
      "status": "success" | "warning" | "error",
      "feedback": "string (brief assessment)",
      "recommendations": ["string array of specific actionable fixes. INCLUDE EXAMPLES from their CV. e.g. 'Change \"Managed team\" to \"Led a team of 5 developers...\"'"]
    }
  ],
  "atsEvaluation": {
    "score": number,
    "breakdown": {
      "parseability": number,
      "keywordAlignment": number,
      "formattingSimplicity": number,
      "sectionCompleteness": number,
      "roleSignalStrength": number
    },
    "explanation": "Brief explanation of what most affected the score",
    "topFixes": ["string array of top 5 ATS specific fixes"],
    "warnings": ["string array of critical parsing warnings"]
  }
}
`
        },
        {
          role: 'user',
          content: `Please perform a detailed review and ATS evaluation for this CV:\n\n${cvText}`
        }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.7,
    });

    const analysis = JSON.parse(completion.choices[0].message.content);
    res.json({ status: 'OK', data: analysis });
  } catch (error) {
    console.error('Detailed review error:', error);
    res.status(500).json({ error: 'Failed to generate detailed review. Please check your API key.' });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
