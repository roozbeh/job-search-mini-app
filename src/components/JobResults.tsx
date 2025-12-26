import { motion, AnimatePresence } from 'motion/react';
import { Briefcase, AlertCircle, Loader2, Search } from 'lucide-react';
import { JobCard } from './JobCard';
import type { Job } from '../types';

interface JobResultsProps {
  jobs: Job[];
  isSearching: boolean;
  error: string | null;
  apiCallsUsed: number;
  maxApiCalls: number;
}

export function JobResults({ jobs, isSearching, error, apiCallsUsed, maxApiCalls }: JobResultsProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.4 }}
      className="glass rounded-3xl p-6 md:p-8"
    >
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-display font-semibold flex items-center gap-2">
          <Briefcase className="w-6 h-6 text-mint" />
          Job Results
        </h2>
        <div className="flex items-center gap-2 text-sm text-text-dim">
          <div className="flex gap-1">
            {Array.from({ length: maxApiCalls }).map((_, i) => (
              <div
                key={i}
                className={`w-2 h-2 rounded-full transition-colors ${
                  i < apiCallsUsed ? 'bg-accent' : 'bg-surface-light'
                }`}
              />
            ))}
          </div>
          <span>{apiCallsUsed}/{maxApiCalls} searches</span>
        </div>
      </div>

      <AnimatePresence mode="wait">
        {isSearching && (
          <motion.div
            key="loading"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="py-16 text-center"
          >
            <Loader2 className="w-12 h-12 text-accent mx-auto mb-4 animate-spin" />
            <p className="text-text-muted">Searching across job boards...</p>
            <p className="text-text-dim text-sm mt-1">This may take a moment</p>
          </motion.div>
        )}

        {error && !isSearching && (
          <motion.div
            key="error"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="py-8 text-center"
          >
            <div className="bg-coral/10 border border-coral/30 rounded-2xl p-6 inline-block">
              <AlertCircle className="w-10 h-10 text-coral mx-auto mb-3" />
              <p className="text-coral font-medium">{error}</p>
              <p className="text-text-dim text-sm mt-1">Please try again with different criteria</p>
            </div>
          </motion.div>
        )}

        {!isSearching && !error && jobs.length === 0 && (
          <motion.div
            key="empty"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="py-16 text-center"
          >
            <div className="relative inline-block">
              <div className="absolute inset-0 bg-accent/20 blur-2xl rounded-full" />
              <Search className="relative w-16 h-16 text-text-dim mx-auto mb-4" />
            </div>
            <p className="text-text-muted text-lg">Ready to find your next opportunity</p>
            <p className="text-text-dim text-sm mt-1">
              Add your job preferences and click "Find Jobs" to search
            </p>
          </motion.div>
        )}

        {!isSearching && !error && jobs.length > 0 && (
          <motion.div
            key="results"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="space-y-4"
          >
            <p className="text-text-dim text-sm mb-4">
              Found {jobs.length} matching positions
            </p>
            {jobs.map((job, index) => (
              <JobCard key={job.id} job={job} index={index} />
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}


