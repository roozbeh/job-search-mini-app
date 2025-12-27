# n8n Workflow Instructions for Job Search Mini App

This document provides detailed instructions for creating an n8n workflow that replicates the backend functionality of the job search mini app.

## Overview

The workflow should accept a webhook request with CV text and job preferences, then:
1. Analyze CV using OpenAI to extract job search criteria and provide improvement suggestions
2. Search for jobs based on preferences
3. Return CV analysis and job results

**Note:** PDF parsing is handled client-side in the HTML file using PDF.js. The webhook will only receive plain text CV content, so no PDF parsing is needed in the workflow.

## Workflow Structure

### 1. Webhook Trigger Node

**Node Type:** Webhook
**Settings:**
- **HTTP Method:** POST
- **Path:** `/job-search` 
- **Response Mode:** Respond to Webhook
- **Response Data:** JSON

**Expected Input Format:**
```json
{
  "cvText": "string (CV content as plain text - PDFs are parsed client-side)",
  "preferences": {
    "jobTitles": ["string array"],
    "locations": ["string array"],
    "isRemote": boolean,
    "salaryMin": number | null,
    "salaryMax": number | null
  }
}
```

**Note:** The HTML frontend uses PDF.js to parse PDF files client-side and extract text before sending to the webhook. The workflow only needs to handle plain text CV content.

---

### 2. Environment Variables Setup

Create the following environment variables in n8n:
- `OPENAI_API_KEY`: Your OpenAI API key (stored securely)
- `AGNIC_API_KEY`: Your AgnicPay API key (stored securely)
- `AGNIC_PAY_BASE`: `https://api.agnicpay.xyz/api/x402/fetch`
- `JOB_SEARCH_API_BASE`: `https://api.agnichub.xyz/v1/custom/job-search`
- `AGNIC_LLM_BASE`: `https://api.agnicpay.xyz/v1`

---

### 3. CV Analysis Node (OpenAI)

**Note:** PDF parsing is handled client-side in the HTML file. The webhook will always receive plain text CV content, so you can proceed directly to CV analysis.

---

### 3. CV Analysis Node (OpenAI)

**Node Type:** OpenAI Node (or HTTP Request to OpenAI API)

**Configuration:**
- **Model:** `gpt-4o`
- **Base URL:** `{{ $env.AGNIC_LLM_BASE }}`
- **API Key:** `{{ $env.OPENAI_API_KEY }}`
- **Temperature:** 0.7
- **Response Format:** JSON Object

**System Prompt:**
```
You are an expert CV and résumé reviewer with experience equivalent to a senior recruiter and hiring manager across multiple industries.

Your task is to analyze a user-provided CV and give professional, constructive, and actionable feedback. You are not a cheerleader or a grammar checker; you are an expert advisor whose goal is to improve the CV's effectiveness in real hiring situations.

When analyzing a CV, you must consider the following dimensions:

1. **Context Awareness**
   * Infer role level, industry, and seniority from the CV.
   * Adapt feedback to realistic expectations for that context.
   * Avoid one-size-fits-all rules (e.g., "one page only").

2. **Clarity and Impact**
   * Evaluate whether the candidate's value is clear within a quick scan.
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

Provide 3-5 distinct improvement suggestions, prioritizing high-impact issues.
```

**User Message:**
```
Please analyze this CV and provide job search criteria and improvement suggestions:

{{ $json.cvText }}
```

**Expected Output:**
The node should return a JSON object matching the structure defined in the system prompt.

---

### 4. Merge CV Analysis with Preferences

**Node Type:** Code Node or Set Node

**Purpose:** Combine CV analysis extracted criteria with user-provided preferences, prioritizing user preferences.

**Logic:**
```javascript
const cvAnalysis = $input.item.json;
const preferences = $('Webhook').item.json.preferences;

// Merge preferences: use user preferences if provided, otherwise use CV analysis
const finalPreferences = {
  jobTitles: preferences.jobTitles.length > 0 
    ? preferences.jobTitles 
    : cvAnalysis.extractedCriteria.jobTitles || [],
  locations: preferences.locations.length > 0 
    ? preferences.locations 
    : cvAnalysis.extractedCriteria.preferredLocations || [],
  isRemote: preferences.isRemote !== undefined 
    ? preferences.isRemote 
    : cvAnalysis.extractedCriteria.isRemotePreferred || false,
  salaryMin: preferences.salaryMin !== null 
    ? preferences.salaryMin 
    : cvAnalysis.extractedCriteria.salaryRange?.min || null,
  salaryMax: preferences.salaryMax !== null 
    ? preferences.salaryMax 
    : cvAnalysis.extractedCriteria.salaryRange?.max || null,
};

return {
  json: {
    cvAnalysis: cvAnalysis,
    preferences: finalPreferences
  }
};
```

---

### 5. Build Search Queries

**Node Type:** Code Node

**Purpose:** Generate multiple search queries based on job titles and locations.

**Logic:**
```javascript
const preferences = $input.item.json.preferences;
const queries = [];

for (const title of preferences.jobTitles) {
  if (preferences.locations.length > 0) {
    for (const location of preferences.locations) {
      queries.push(`${title} in ${location}`);
    }
  } else if (preferences.isRemote) {
    queries.push(`remote ${title}`);
  } else {
    queries.push(title);
  }
}

// Add remote-specific queries if preference is set
if (preferences.isRemote && preferences.locations.length > 0) {
  for (const title of preferences.jobTitles) {
    queries.push(`remote ${title}`);
  }
}

// Limit to reasonable number (e.g., 5 queries max)
const limitedQueries = queries.slice(0, 5);

return limitedQueries.map(query => ({
  json: { query: query }
}));
```

---

### 6. Job Search Loop

**Node Type:** HTTP Request Node (inside a Loop)

**Configuration:**
- **Method:** POST
- **URL:** `{{ $env.AGNIC_PAY_BASE }}?url={{ encodeURIComponent($env.JOB_SEARCH_API_BASE + '/search?query=' + encodeURIComponent($json.query)) }}`
- **Headers:**
  - `X-Agnic-Token`: `{{ $env.AGNIC_API_KEY }}`
  - `Content-Type`: `application/json`
- **Body:** Empty (POST with no body)

**Expected Response Format:**
```json
{
  "status": "OK",
  "data": [
    {
      "job_id": "string",
      "job_title": "string",
      "employer_name": "string",
      "job_city": "string",
      "job_state": "string",
      "job_country": "string",
      "job_salary": "string",
      "job_description": "string",
      "job_posted_at_datetime_utc": "ISO date string",
      "job_apply_link": "string",
      "employer_logo": "string",
      "job_is_remote": boolean,
      "job_employment_type": "string"
    }
  ]
}
```

---

### 7. Aggregate Job Results

**Node Type:** Code Node

**Purpose:** Collect all job results, remove duplicates, and format them.

**Logic:**
```javascript
const allJobs = [];
const searchResults = $input.all();

for (const result of searchResults) {
  if (result.json.status === 'OK' && Array.isArray(result.json.data)) {
    const jobs = result.json.data.map(job => ({
      id: job.job_id || job.id || Math.random().toString(36),
      title: job.job_title || job.title || 'Unknown Title',
      company: job.employer_name || job.company || 'Unknown Company',
      location: job.job_city
        ? `${job.job_city}${job.job_state ? `, ${job.job_state}` : ''}${job.job_country ? `, ${job.job_country}` : ''}`
        : job.location || 'Location not specified',
      salary: job.job_salary || job.salary_range || null,
      description: job.job_description || job.description || null,
      postedDate: job.job_posted_at_datetime_utc
        ? new Date(job.job_posted_at_datetime_utc).toLocaleDateString()
        : job.posted_date ? String(job.posted_date) : null,
      applicationUrl: job.job_apply_link || job.apply_link || job.url || null,
      companyLogo: job.employer_logo || job.company_logo || null,
      isRemote: job.job_is_remote || job.is_remote || false,
      employmentType: job.job_employment_type || job.employment_type || null,
    }));
    allJobs.push(...jobs);
  }
}

// Remove duplicates based on title + company
const uniqueJobs = allJobs.filter((job, index, self) =>
  index === self.findIndex(j =>
    j.title.toLowerCase() === job.title.toLowerCase() &&
    j.company.toLowerCase() === job.company.toLowerCase()
  )
);

// Sort by posted date (newest first)
uniqueJobs.sort((a, b) => {
  if (!a.postedDate) return 1;
  if (!b.postedDate) return -1;
  const dateA = new Date(a.postedDate).getTime();
  const dateB = new Date(b.postedDate).getTime();
  return dateB - dateA;
});

return {
  json: {
    jobs: uniqueJobs
  }
};
```

---

### 8. Prepare Final Response

**Node Type:** Code Node

**Purpose:** Combine CV analysis and job results into final response.

**Logic:**
```javascript
const cvAnalysis = $('CV Analysis').item.json;
const jobs = $input.item.json.jobs;

return {
  json: {
    status: 'OK',
    cvAnalysis: cvAnalysis,
    jobs: jobs
  }
};
```

---

### 9. Webhook Response

**Node Type:** Respond to Webhook (or HTTP Response)

**Response Format:**
```json
{
  "status": "OK",
  "cvAnalysis": {
    "extractedCriteria": { ... },
    "improvements": [ ... ],
    "summary": "..."
  },
  "jobs": [
    {
      "id": "string",
      "title": "string",
      "company": "string",
      "location": "string",
      "salary": "string | null",
      "description": "string | null",
      "postedDate": "string | null",
      "applicationUrl": "string | null",
      "companyLogo": "string | null",
      "isRemote": boolean,
      "employmentType": "string | null"
    }
  ]
}
```

---

## Error Handling

Add error handling nodes throughout the workflow:

1. **Try-Catch Nodes:** Wrap API calls in try-catch blocks
2. **Error Response:** Return error messages in consistent format:
   ```json
   {
     "status": "ERROR",
     "error": "Error message here"
   }
   ```
3. **Validation:** Validate webhook input before processing

## Additional Features (Optional)

### Detailed CV Review Endpoint

If you want to add a separate endpoint for detailed CV review:

**Additional Webhook:** `/cv/detailed-review`

**System Prompt for Detailed Review:**
```
You are an expert CV reviewer and ATS specialist. Your task is to provide a detailed section-by-section review of a CV AND an ATS compatibility evaluation.

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
```

### Job Details Endpoint

**Additional Webhook:** `/jobs/details`

**HTTP Request:**
- **URL:** `{{ $env.AGNIC_PAY_BASE }}?url={{ encodeURIComponent($env.JOB_SEARCH_API_BASE + '/job-details?job_id=' + encodeURIComponent($json.job_id)) }}`
- **Method:** POST
- **Headers:** Same as job search

### Salary Estimation Endpoint

**Additional Webhook:** `/jobs/salary`

**HTTP Request:**
- **URL:** `{{ $env.AGNIC_PAY_BASE }}?url={{ encodeURIComponent($env.JOB_SEARCH_API_BASE + '/estimated-salary?job_title=' + encodeURIComponent($json.job_title) + '&location=' + encodeURIComponent($json.location) + '&location_type=ANY&years_of_experience=ALL') }}`
- **Method:** POST
- **Headers:** Same as job search

---

## Testing the Workflow

1. **Test Webhook:** Use the n8n webhook test feature or Postman
2. **Sample Request:**
   ```json
   {
     "cvText": "John Doe\nSoftware Engineer\n5 years experience...",
     "preferences": {
       "jobTitles": ["Frontend Developer"],
       "locations": ["San Francisco, CA"],
       "isRemote": true,
       "salaryMin": 100000,
       "salaryMax": 150000
     }
   }
   ```
3. **Verify Response:** Check that CV analysis and job results are returned correctly

---

## Notes

- **API Key Security:** Store API keys in n8n environment variables, never hardcode them
- **Rate Limiting:** Consider adding rate limiting if needed
- **Caching:** Optionally cache CV analysis results to reduce API calls
- **Parallel Processing:** Job searches can be done in parallel using n8n's parallel execution
- **Error Logging:** Log errors for debugging and monitoring

---

## Workflow Diagram Summary

```
Webhook Trigger (receives plain text CV)
    ↓
CV Analysis (OpenAI)
    ↓
Merge CV Analysis + Preferences
    ↓
Build Search Queries
    ↓
[Loop] Job Search (HTTP Request)
    ↓
Aggregate Job Results
    ↓
Prepare Final Response
    ↓
Webhook Response
```

**Note:** PDF parsing happens client-side in the HTML file before the webhook is called, so the workflow only processes plain text CV content.

---

## Agent Prompt for n8n AI Vibe Coder

Use this prompt when generating the workflow with n8n AI:

```
Create an n8n workflow that:

1. Accepts a POST webhook with JSON body containing:
   - cvText: string (CV content as plain text - PDFs are parsed client-side before sending)
   - preferences: object with jobTitles (array), locations (array), isRemote (boolean), salaryMin (number|null), salaryMax (number|null)

2. Analyzes the CV using OpenAI GPT-4o via AgnicPay proxy:
   - Base URL: https://api.agnicpay.xyz/v1
   - Extract job search criteria (job titles, skills, experience, locations, salary range)
   - Provide improvement suggestions with priorities
   - Return summary

3. Merges CV-extracted criteria with user preferences (user preferences take priority)

4. Builds search queries from job titles and locations (e.g., "Frontend Developer in San Francisco")

5. Searches for jobs using AgnicPay proxy:
   - Proxy URL: https://api.agnicpay.xyz/api/x402/fetch
   - Target API: https://api.agnichub.xyz/v1/custom/job-search/search
   - Use X-Agnic-Token header with API key from environment variable

6. Aggregates all job results, removes duplicates, sorts by date

7. Returns JSON response with:
   - status: "OK"
   - cvAnalysis: { extractedCriteria, improvements, summary }
   - jobs: array of formatted job objects

Use environment variables for API keys. Handle errors gracefully. Use parallel execution where possible.
```

