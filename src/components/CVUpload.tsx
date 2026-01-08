import { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Upload, FileText, Sparkles, X, Loader2, FileCheck } from 'lucide-react';
import { getApiUrl } from '../utils/api';
import { requestChatCompletionWithOAuth } from '../utils/agnicPay';
import type { CVAnalysis, JobPreferences, DetailedReview } from '../types';
import { DetailedReviewModal } from './DetailedReviewModal';

interface CVUploadProps {
  onAnalysisComplete: (analysis: CVAnalysis) => void;
  onApplyCriteria: (preferences: Partial<JobPreferences>) => void;
  apiKey: string | null;
  oauthToken: string | null;
}

export function CVUpload({ onAnalysisComplete, onApplyCriteria, apiKey, oauthToken }: CVUploadProps) {
  const [cvText, setCvText] = useState('');
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysis, setAnalysis] = useState<CVAnalysis | null>(null);
  const [dragActive, setDragActive] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const canUseAuth = Boolean(apiKey || oauthToken);

  const [showDetailedReview, setShowDetailedReview] = useState(false);
  const [isDetailedAnalyzing, setIsDetailedAnalyzing] = useState(false);
  const [detailedReview, setDetailedReview] = useState<DetailedReview | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      await handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleFile = async (file: File) => {
    const isPdf = file.type === 'application/pdf' || file.name.endsWith('.pdf');
    const isTxt = file.type === 'text/plain' || file.name.endsWith('.txt');

    if (!isPdf && !isTxt) {
      setError('Please upload a PDF or TXT file.');
      return;
    }

    if (isTxt) {
      const text = await file.text();
      setCvText(text);
      return;
    }

    // For PDF, send to backend for parsing
    setIsAnalyzing(true);
    setError(null);

    try {
      const formData = new FormData();
      formData.append('file', file);

      const response = await fetch(getApiUrl('/api/cv/parse'), {
        method: 'POST',
        body: formData,
      });

      const data = await response.json();

      if (data.status === 'OK' && data.data?.text) {
        setCvText(data.data.text);
      } else {
        setError(data.error || 'Failed to parse PDF');
      }
    } catch (err) {
      setError('Failed to parse PDF. Please try pasting the content instead.');
    } finally {
      setIsAnalyzing(false);
    }
  };

  const analyzeCV = async () => {
    if (!apiKey && !oauthToken) {
      setError('Please enter your API key or login with AgnicPay first');
      return;
    }

    if (!cvText.trim()) {
      setError('Please enter your CV content');
      return;
    }

    setIsAnalyzing(true);
    setError(null);

    try {
      let data: Record<string, unknown>;
      if (apiKey) {
        const response = await fetch(getApiUrl('/api/cv/analyze'), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ cvText, apiKey }),
        });

        data = await response.json();
      } else if (oauthToken) {
        const response = await requestChatCompletionWithOAuth(
          {
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
          },
          oauthToken
        ) as { choices?: Array<{ message?: { content?: string } }> };

        const choice = response?.choices?.[0]?.message?.content;
        if (!choice) {
          throw new Error('Missing analysis response');
        }
        data = { status: 'OK', data: JSON.parse(choice) };
      } else {
        throw new Error('Missing authentication');
      }

      if (data.status === 'OK') {
        setAnalysis(data.data);
        onAnalysisComplete(data.data);
      } else {
        setError(data.error || 'Failed to analyze CV');
      }
    } catch (err) {
      setError('Failed to analyze CV. Please check your connection.');
    } finally {
      setIsAnalyzing(false);
    }
  };

  const applyExtractedCriteria = () => {
    if (analysis) {
      onApplyCriteria({
        jobTitles: analysis.extractedCriteria.jobTitles,
        locations: analysis.extractedCriteria.preferredLocations,
        isRemote: analysis.extractedCriteria.isRemotePreferred,
        salaryMin: analysis.extractedCriteria.salaryRange.min,
        salaryMax: analysis.extractedCriteria.salaryRange.max,
      });
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'high': return 'text-coral bg-coral/10';
      case 'medium': return 'text-warning bg-warning/10';
      case 'low': return 'text-mint bg-mint/10';
      default: return 'text-text-muted bg-surface-light';
    }
  };

  const generateDetailedReview = async () => {
    if (!apiKey && !oauthToken) {
      setError('Please enter your API key or login with AgnicPay first');
      return;
    }

    setShowDetailedReview(true);

    // If we already have the review, don't fetch again
    if (detailedReview) return;

    setIsDetailedAnalyzing(true);
    try {
      let data: Record<string, unknown>;
      if (apiKey) {
        const response = await fetch(getApiUrl('/api/cv/detailed-review'), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ cvText, apiKey }),
        });

        data = await response.json();
      } else if (oauthToken) {
        const response = await requestChatCompletionWithOAuth(
          {
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
          },
          oauthToken
        ) as { choices?: Array<{ message?: { content?: string } }> };

        const choice = response?.choices?.[0]?.message?.content;
        if (!choice) {
          throw new Error('Missing detailed review response');
        }
        data = { status: 'OK', data: JSON.parse(choice) };
      } else {
        throw new Error('Missing authentication');
      }

      if (data.status === 'OK') {
        setDetailedReview(data.data);
      } else {
        // Show error in the modal or close it? 
        // For now let's just log it and maybe set an error state in the modal if we had one
        console.error(data.error);
        setError(data.error || 'Failed to generate detailed review');
        setShowDetailedReview(false);
      }
    } catch (err) {
      setError('Network error during detailed review');
      setShowDetailedReview(false);
    } finally {
      setIsDetailedAnalyzing(false);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.3 }}
      className="glass rounded-3xl p-6 md:p-8"
    >
      <h2 className="text-2xl font-display font-semibold mb-6 flex items-center gap-2">
        <Sparkles className="w-6 h-6 text-lavender" />
        AI CV Analysis
      </h2>

      {!analysis ? (
        <>
          {/* Upload Zone */}
          <div
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={handleDrop}
            onClick={() => fileInputRef.current?.click()}
            className={`border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-all ${dragActive
              ? 'border-accent bg-accent/10'
              : 'border-border hover:border-accent/50 hover:bg-surface/50'
              }`}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf,.txt"
              onChange={(e) => e.target.files?.[0] && handleFile(e.target.files[0])}
              className="hidden"
            />
            <Upload className={`w-12 h-12 mx-auto mb-4 ${dragActive ? 'text-accent' : 'text-text-dim'}`} />
            <p className="text-text-muted mb-1">Drop your CV here or click to upload</p>
            <p className="text-text-dim text-sm">PDF and TXT files supported</p>
          </div>

          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-border" />
            </div>
            <div className="relative flex justify-center">
              <span className="px-4 bg-deep text-text-dim text-sm">or paste your CV</span>
            </div>
          </div>

          {/* Text Input */}
          <textarea
            value={cvText}
            onChange={(e) => setCvText(e.target.value)}
            placeholder="Paste your CV content here..."
            className="w-full h-48 bg-surface-light border border-border rounded-2xl p-4 text-text placeholder:text-text-dim focus:border-accent transition-colors resize-none"
          />

          {error && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-4 p-3 bg-coral/10 border border-coral/30 rounded-xl text-coral text-sm flex items-center gap-2"
            >
              <X className="w-4 h-4" />
              {error}
            </motion.div>
          )}

          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={analyzeCV}
            disabled={isAnalyzing || !cvText.trim() || !canUseAuth}
            className="w-full mt-6 bg-gradient-to-r from-lavender to-coral text-white font-semibold py-4 px-6 rounded-2xl flex items-center justify-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            {isAnalyzing ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                Analyzing your CV...
              </>
            ) : !canUseAuth ? (
              <>
                <Sparkles className="w-5 h-5" />
                Login or enter API key to analyze
              </>
            ) : (
              <>
                <Sparkles className="w-5 h-5" />
                Analyze with AI
              </>
            )}
          </motion.button>
        </>
      ) : (
        <AnimatePresence mode="wait">
          <motion.div
            key="results"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
          >
            {/* Summary */}
            <div className="bg-surface-light rounded-2xl p-5 mb-6">
              <p className="text-text-muted leading-relaxed">{analysis.summary}</p>
            </div>

            {/* Extracted Criteria */}
            <div className="mb-6">
              <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
                <FileText className="w-5 h-5 text-accent" />
                Extracted Search Criteria
              </h3>
              <div className="grid grid-cols-2 gap-3 mb-4">
                <div className="bg-surface-light rounded-xl p-4">
                  <p className="text-text-dim text-sm mb-1">Job Titles</p>
                  <div className="flex flex-wrap gap-1">
                    {analysis.extractedCriteria.jobTitles.map((title) => (
                      <span key={title} className="text-accent text-sm">{title}</span>
                    ))}
                  </div>
                </div>
                <div className="bg-surface-light rounded-xl p-4">
                  <p className="text-text-dim text-sm mb-1">Experience</p>
                  <p className="text-text font-medium">{analysis.extractedCriteria.yearsOfExperience} years</p>
                </div>
                <div className="bg-surface-light rounded-xl p-4">
                  <p className="text-text-dim text-sm mb-1">Locations</p>
                  <div className="flex flex-wrap gap-1">
                    {analysis.extractedCriteria.preferredLocations.map((loc) => (
                      <span key={loc} className="text-mint text-sm">{loc}</span>
                    ))}
                  </div>
                </div>
                <div className="bg-surface-light rounded-xl p-4">
                  <p className="text-text-dim text-sm mb-1">Remote</p>
                  <p className="text-text font-medium">
                    {analysis.extractedCriteria.isRemotePreferred ? 'Yes' : 'No'}
                  </p>
                </div>
              </div>
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={applyExtractedCriteria}
                className="w-full bg-accent/20 hover:bg-accent/30 text-accent font-medium py-3 rounded-xl transition-colors mb-3"
              >
                Apply to Search Preferences
              </motion.button>

              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={generateDetailedReview}
                className="w-full bg-gradient-to-r from-mint to-teal-500 text-white font-medium py-3 rounded-xl transition-all shadow-lg shadow-mint/20 flex items-center justify-center gap-2"
              >
                <FileCheck className="w-5 h-5" />
                Get Detailed Review & ATS Score
              </motion.button>
            </div>

            {/* Improvement Suggestions */}
            <div>
              <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-lavender" />
                CV Improvement Suggestions
              </h3>
              <div className="space-y-3">
                {analysis.improvements.map((improvement, index) => (
                  <motion.div
                    key={index}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: index * 0.1 }}
                    className="bg-surface-light rounded-xl p-4"
                  >
                    <div className="flex items-start gap-3">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${getPriorityColor(improvement.priority)}`}>
                        {improvement.priority}
                      </span>
                      <div>
                        <h4 className="text-text font-medium mb-1">{improvement.title}</h4>
                        <p className="text-text-muted text-sm">{improvement.description}</p>
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>

            {/* Reset Button */}
            <button
              onClick={() => { setAnalysis(null); setCvText(''); }}
              className="mt-6 text-text-dim hover:text-text text-sm transition-colors"
            >
              ← Analyze a different CV
            </button>
          </motion.div>
        </AnimatePresence>
      )}

      <DetailedReviewModal
        isOpen={showDetailedReview}
        onClose={() => setShowDetailedReview(false)}
        review={detailedReview}
        isLoading={isDetailedAnalyzing}
      />
    </motion.div>
  );
}
