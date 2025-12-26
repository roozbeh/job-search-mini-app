import { useState, useCallback } from 'react';
import { Header } from './components/Header';
import { ApiKeyInput } from './components/ApiKeyInput';
import { PreferencesForm } from './components/PreferencesForm';
import { CVUpload } from './components/CVUpload';
import { JobResults } from './components/JobResults';
import { Background } from './components/Background';
import type { JobPreferences, Job, CVAnalysis, SearchState } from './types';

const MAX_API_CALLS = 5;

function App() {
  const [apiKey, setApiKey] = useState<string | null>(null);
  
  const handleApiKeyChange = useCallback((key: string | null) => {
    setApiKey(key);
  }, []);
  
  const [preferences, setPreferences] = useState<JobPreferences>({
    jobTitles: [],
    locations: [],
    isRemote: false,
    salaryMin: null,
    salaryMax: null,
  });

  const [searchState, setSearchState] = useState<SearchState>({
    isSearching: false,
    apiCallsUsed: 0,
    maxApiCalls: MAX_API_CALLS,
    jobs: [],
    error: null,
  });

  const [, setCvAnalysis] = useState<CVAnalysis | null>(null);

  const handleSearch = useCallback(async () => {
    if (!apiKey) {
      setSearchState(prev => ({
        ...prev,
        error: 'Please enter your API key first.',
      }));
      return;
    }

    if (searchState.apiCallsUsed >= MAX_API_CALLS) {
      setSearchState(prev => ({
        ...prev,
        error: 'You have used all your search credits. Please refresh to reset.',
      }));
      return;
    }

    if (preferences.jobTitles.length === 0) {
      setSearchState(prev => ({
        ...prev,
        error: 'Please add at least one job title to search.',
      }));
      return;
    }

    setSearchState(prev => ({
      ...prev,
      isSearching: true,
      error: null,
    }));

    const allJobs: Job[] = [];
    let callsMade = 0;

    try {
      // Build search queries based on preferences
      const queries: string[] = [];
      
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

      // Limit to remaining API calls
      const remainingCalls = MAX_API_CALLS - searchState.apiCallsUsed;
      const queriesToExecute = queries.slice(0, remainingCalls);

      for (const query of queriesToExecute) {
        try {
          const response = await fetch('/api/jobs/search', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query, apiKey }),
          });
          const data = await response.json();
          callsMade++;

          if (data.status === 'OK' && Array.isArray(data.data)) {
            const jobs = data.data.map((job: Record<string, unknown>) => ({
              id: job.job_id || job.id || Math.random().toString(36),
              title: job.job_title || job.title || 'Unknown Title',
              company: job.employer_name || job.company || 'Unknown Company',
              location: job.job_city 
                ? `${job.job_city}${job.job_state ? `, ${job.job_state}` : ''}${job.job_country ? `, ${job.job_country}` : ''}`
                : job.location || 'Location not specified',
              salary: job.job_salary || job.salary_range || null,
              description: job.job_description || job.description || null,
              postedDate: job.job_posted_at_datetime_utc 
                ? new Date(String(job.job_posted_at_datetime_utc)).toLocaleDateString()
                : job.posted_date ? String(job.posted_date) : null,
              applicationUrl: job.job_apply_link || job.apply_link || job.url || null,
              companyLogo: job.employer_logo || job.company_logo || null,
              isRemote: job.job_is_remote || job.is_remote || false,
              employmentType: job.job_employment_type || job.employment_type || null,
            }));
            allJobs.push(...jobs);
          }
        } catch (err) {
          console.error('Search query failed:', err);
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

      setSearchState(prev => ({
        ...prev,
        isSearching: false,
        apiCallsUsed: prev.apiCallsUsed + callsMade,
        jobs: uniqueJobs,
        error: uniqueJobs.length === 0 ? 'No jobs found matching your criteria. Try different search terms.' : null,
      }));
    } catch (error) {
      console.error('Search failed:', error);
      setSearchState(prev => ({
        ...prev,
        isSearching: false,
        apiCallsUsed: prev.apiCallsUsed + callsMade,
        error: 'Failed to search for jobs. Please try again.',
      }));
    }
  }, [preferences, searchState.apiCallsUsed, apiKey]);

  const handleCVAnalysis = (analysis: CVAnalysis) => {
    setCvAnalysis(analysis);
  };

  const handleApplyCriteria = (criteria: Partial<JobPreferences>) => {
    setPreferences(prev => ({
      ...prev,
      ...criteria,
      jobTitles: criteria.jobTitles || prev.jobTitles,
      locations: criteria.locations || prev.locations,
    }));
  };

  return (
    <div className="min-h-screen relative noise-overlay">
      <Background />
      
      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16">
        <Header />
        
        <ApiKeyInput onApiKeyChange={handleApiKeyChange} />
        
        <div className="grid lg:grid-cols-2 gap-6 mb-8">
          <PreferencesForm
            preferences={preferences}
            onUpdate={setPreferences}
            onSearch={handleSearch}
            isSearching={searchState.isSearching}
            apiCallsRemaining={MAX_API_CALLS - searchState.apiCallsUsed}
            hasApiKey={!!apiKey}
          />
          <CVUpload
            onAnalysisComplete={handleCVAnalysis}
            onApplyCriteria={handleApplyCriteria}
            apiKey={apiKey}
          />
        </div>

        <JobResults
          jobs={searchState.jobs}
          isSearching={searchState.isSearching}
          error={searchState.error}
          apiCallsUsed={searchState.apiCallsUsed}
          maxApiCalls={MAX_API_CALLS}
        />
      </div>
    </div>
  );
}

export default App;
