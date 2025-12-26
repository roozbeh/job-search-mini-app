import { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Upload, FileText, Sparkles, X, Loader2 } from 'lucide-react';
import { getApiUrl } from '../utils/api';
import type { CVAnalysis, JobPreferences } from '../types';

interface CVUploadProps {
  onAnalysisComplete: (analysis: CVAnalysis) => void;
  onApplyCriteria: (preferences: Partial<JobPreferences>) => void;
  apiKey: string | null;
}

export function CVUpload({ onAnalysisComplete, onApplyCriteria, apiKey }: CVUploadProps) {
  const [cvText, setCvText] = useState('');
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysis, setAnalysis] = useState<CVAnalysis | null>(null);
  const [dragActive, setDragActive] = useState(false);
  const [error, setError] = useState<string | null>(null);
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
    if (!apiKey) {
      setError('Please enter your API key first');
      return;
    }

    if (!cvText.trim()) {
      setError('Please enter your CV content');
      return;
    }

    setIsAnalyzing(true);
    setError(null);

    try {
      const response = await fetch(getApiUrl('/api/cv/analyze'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cvText, apiKey }),
      });

      const data = await response.json();
      
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
            className={`border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-all ${
              dragActive 
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
            className="w-full h-48 bg-surface border border-border rounded-2xl p-4 text-text placeholder:text-text-dim focus:border-accent transition-colors resize-none"
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
            disabled={isAnalyzing || !cvText.trim() || !apiKey}
            className="w-full mt-6 bg-gradient-to-r from-lavender to-coral text-white font-semibold py-4 px-6 rounded-2xl flex items-center justify-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            {isAnalyzing ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                Analyzing your CV...
              </>
            ) : !apiKey ? (
              <>
                <Sparkles className="w-5 h-5" />
                Enter API Key to Analyze
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
            <div className="bg-surface rounded-2xl p-5 mb-6">
              <p className="text-text-muted leading-relaxed">{analysis.summary}</p>
            </div>

            {/* Extracted Criteria */}
            <div className="mb-6">
              <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
                <FileText className="w-5 h-5 text-accent" />
                Extracted Search Criteria
              </h3>
              <div className="grid grid-cols-2 gap-3 mb-4">
                <div className="bg-surface rounded-xl p-4">
                  <p className="text-text-dim text-sm mb-1">Job Titles</p>
                  <div className="flex flex-wrap gap-1">
                    {analysis.extractedCriteria.jobTitles.map((title) => (
                      <span key={title} className="text-accent text-sm">{title}</span>
                    ))}
                  </div>
                </div>
                <div className="bg-surface rounded-xl p-4">
                  <p className="text-text-dim text-sm mb-1">Experience</p>
                  <p className="text-text font-medium">{analysis.extractedCriteria.yearsOfExperience} years</p>
                </div>
                <div className="bg-surface rounded-xl p-4">
                  <p className="text-text-dim text-sm mb-1">Locations</p>
                  <div className="flex flex-wrap gap-1">
                    {analysis.extractedCriteria.preferredLocations.map((loc) => (
                      <span key={loc} className="text-mint text-sm">{loc}</span>
                    ))}
                  </div>
                </div>
                <div className="bg-surface rounded-xl p-4">
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
                className="w-full bg-accent/20 hover:bg-accent/30 text-accent font-medium py-3 rounded-xl transition-colors"
              >
                Apply to Search Preferences
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
                    className="bg-surface rounded-xl p-4"
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
    </motion.div>
  );
}

