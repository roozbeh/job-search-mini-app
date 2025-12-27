
export interface JobPreferences {
  jobTitles: string[];
  locations: string[];
  isRemote: boolean;
  salaryMin: number | null;
  salaryMax: number | null;
}

export interface Job {
  id: string;
  title: string;
  company: string;
  location: string;
  salary: string | null;
  description: string | null;
  postedDate: string | null;
  applicationUrl: string | null;
  companyLogo: string | null;
  isRemote: boolean;
  employmentType: string | null;
}

export interface Improvement {
  title: string;
  description: string;
  priority: 'high' | 'medium' | 'low';
}

export interface ExtractedCriteria {
  jobTitles: string[];
  skills: string[];
  yearsOfExperience: number;
  preferredLocations: string[];
  isRemotePreferred: boolean;
  salaryRange: {
    min: number | null;
    max: number | null;
    currency: string;
  };
  industries: string[];
}

export interface CVAnalysis {
  extractedCriteria: ExtractedCriteria;
  improvements: Improvement[];
  summary: string;
}

export interface SearchState {
  isSearching: boolean;
  apiCallsUsed: number;
  maxApiCalls: number;
  jobs: Job[];
  error: string | null;
}

// New Types for Detailed Review
export interface SectionFeedback {
  sectionName: string;
  status: 'success' | 'warning' | 'error';
  feedback: string;
  recommendations: string[];
}

export interface AtsEvaluation {
  score: number;
  breakdown: {
    parseability: number;
    keywordAlignment: number;
    formattingSimplicity: number;
    sectionCompleteness: number;
    roleSignalStrength: number;
  };
  explanation: string;
  topFixes: string[];
  warnings: string[];
}

export interface DetailedReview {
  sectionFeedback: SectionFeedback[];
  atsEvaluation: AtsEvaluation;
}
