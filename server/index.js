import express from 'express';
import cors from 'cors';
import OpenAI from 'openai';
import multer from 'multer';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const pdfParseModule = require('pdf-parse');

// pdf-parse exports PDFParse class, but also works as a function when called directly
// Try to get the function directly or use the module as-is
const pdf = typeof pdfParseModule === 'function' 
  ? pdfParseModule 
  : (pdfParseModule.default || pdfParseModule.PDFParse || pdfParseModule);

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Configure multer for file uploads (store in memory)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    // Accept PDF and TXT files by mimetype or extension
    const isPdf = file.mimetype === 'application/pdf' || 
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

    if (req.file.mimetype === 'application/pdf' || req.file.originalname?.endsWith('.pdf')) {
      // Parse PDF
      try {
        console.log('Attempting to parse PDF...');
        const pdfData = await pdf(req.file.buffer);
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
          content: `You are an expert career advisor and CV analyst. Analyze the provided CV and extract job search criteria, plus provide improvement suggestions.

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
      "description": "Detailed explanation of what to improve and why",
      "priority": "high" | "medium" | "low"
    }
  ],
  "summary": "A brief 2-3 sentence summary of the candidate's profile"
}

Provide exactly 3 improvement suggestions, prioritized by impact.`
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

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
