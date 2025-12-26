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
  salary?: string;
  description?: string;
  postedDate?: string;
  applicationUrl?: string;
  companyLogo?: string;
  isRemote?: boolean;
  employmentType?: string;
}

export interface CVAnalysis {
  extractedCriteria: {
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
  };
  improvements: {
    title: string;
    description: string;
    priority: 'high' | 'medium' | 'low';
  }[];
  summary: string;
}

export interface SearchState {
  isSearching: boolean;
  apiCallsUsed: number;
  maxApiCalls: number;
  jobs: Job[];
  error: string | null;
}


