import { useState } from "react";
import { useNavigate } from "react-router";
import { Upload, Briefcase, Loader2, Sparkles } from "lucide-react";
import { useApp } from "../context/AppContext";
import { generateResumeSuggestions } from "../utils/resumeAnalyzer";

export function ResumeUpload() {
  const navigate = useNavigate();
  const { setResumeText, setResumeSuggestions } = useApp();
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [dragActive, setDragActive] = useState(false);

  const handleFileUpload = async (file: File) => {
    setIsAnalyzing(true);

    // Simulate file reading
    const reader = new FileReader();
    reader.onload = async (e) => {
      const text = e.target?.result as string;
      setResumeText(text);

      // Simulate AI analysis
      await new Promise((resolve) => setTimeout(resolve, 1500));

      const suggestions = generateResumeSuggestions(text);
      setResumeSuggestions(suggestions);

      setIsAnalyzing(false);
      navigate("/resume-review");
    };

    reader.readAsText(file);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileUpload(e.dataTransfer.files[0]);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      handleFileUpload(e.target.files[0]);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-600 to-purple-600 flex flex-col">
      {/* App Header */}
      <div className="px-6 pt-12 pb-6">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center">
            <Briefcase className="w-7 h-7 text-blue-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">ResuMatch</h1>
            <p className="text-sm text-blue-100">Your AI Career Assistant</p>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 bg-white rounded-t-3xl px-6 py-8">
        <div className="max-w-md mx-auto">
          <div className="text-center mb-8">
            <h2 className="text-3xl font-bold text-slate-900 mb-3">
              Find Your Dream Job
            </h2>
            <p className="text-slate-600">
              Upload your resume and get matched with opportunities tailored just for you
            </p>
          </div>

          <div
            className={`border-2 border-dashed rounded-3xl p-8 text-center transition-all mb-6 ${
              dragActive
                ? "border-blue-500 bg-blue-50 scale-105"
                : "border-slate-300 bg-slate-50"
            }`}
            onDragEnter={() => setDragActive(true)}
            onDragLeave={() => setDragActive(false)}
            onDragOver={(e) => e.preventDefault()}
            onDrop={handleDrop}
          >
            {isAnalyzing ? (
              <div className="flex flex-col items-center gap-4 py-4">
                <Loader2 className="w-16 h-16 text-blue-600 animate-spin" />
                <p className="text-lg font-medium text-slate-900">Analyzing resume...</p>
                <p className="text-sm text-slate-500">
                  Checking skills, experience, and more
                </p>
              </div>
            ) : (
              <>
                <div className="w-20 h-20 mx-auto mb-4 bg-gradient-to-br from-blue-500 to-purple-500 rounded-2xl flex items-center justify-center">
                  <Upload className="w-10 h-10 text-white" />
                </div>
                <p className="text-lg font-medium mb-2 text-slate-900">
                  Upload Your Resume
                </p>
                <p className="text-sm text-slate-500 mb-6">
                  PDF, DOC, DOCX, or TXT
                </p>
                <label className="block w-full py-4 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-2xl cursor-pointer font-medium shadow-lg shadow-blue-500/30 active:scale-95 transition-transform">
                  <input
                    type="file"
                    className="hidden"
                    accept=".pdf,.doc,.docx,.txt"
                    onChange={handleChange}
                  />
                  Choose File
                </label>
              </>
            )}
          </div>

          <div className="space-y-4">
            <div className="bg-gradient-to-r from-blue-50 to-purple-50 p-5 rounded-2xl border border-blue-100">
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center flex-shrink-0">
                  <Sparkles className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-semibold text-slate-900 mb-1">AI-Powered Analysis</h3>
                  <p className="text-sm text-slate-600">
                    Instant feedback on typos, formatting, and missing skills
                  </p>
                </div>
              </div>
            </div>
            <div className="bg-gradient-to-r from-green-50 to-emerald-50 p-5 rounded-2xl border border-green-100">
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 bg-green-600 rounded-xl flex items-center justify-center flex-shrink-0">
                  <svg
                    className="w-5 h-5 text-white"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
                    />
                  </svg>
                </div>
                <div>
                  <h3 className="font-semibold text-slate-900 mb-1">Smart Job Matching</h3>
                  <p className="text-sm text-slate-600">
                    Find roles that perfectly match your experience
                  </p>
                </div>
              </div>
            </div>
            <div className="bg-gradient-to-r from-purple-50 to-pink-50 p-5 rounded-2xl border border-purple-100">
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 bg-purple-600 rounded-xl flex items-center justify-center flex-shrink-0">
                  <svg
                    className="w-5 h-5 text-white"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                    />
                  </svg>
                </div>
                <div>
                  <h3 className="font-semibold text-slate-900 mb-1">Application Tracking</h3>
                  <p className="text-sm text-slate-600">
                    Manage every step of your job search journey
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}