import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { MapPin, Building2, DollarSign, Clock, ExternalLink, Globe, ChevronDown, Briefcase, Users, Calendar } from 'lucide-react';
import type { Job } from '../types';

interface JobCardProps {
  job: Job;
  index: number;
}

export function JobCard({ job, index }: JobCardProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.05 }}
      layout
      className={`glass rounded-2xl p-5 transition-all ${isExpanded ? 'border-accent/30' : 'hover:border-accent/20'}`}
    >
      <div className="flex items-start gap-4">
        {/* Company Logo */}
        <div className="w-12 h-12 rounded-xl bg-surface-light flex items-center justify-center shrink-0 overflow-hidden">
          {job.companyLogo ? (
            <img src={job.companyLogo} alt={job.company} className="w-full h-full object-cover" />
          ) : (
            <Building2 className="w-6 h-6 text-text-dim" />
          )}
        </div>

        <div className="flex-1 min-w-0">
          {/* Title & Company */}
          <h3 className={`text-lg font-semibold transition-colors ${isExpanded ? 'text-accent' : 'text-text'}`}>
            {job.title}
          </h3>
          <p className="text-text-muted text-sm mb-3">{job.company}</p>

          {/* Meta Info */}
          <div className="flex flex-wrap gap-3 text-sm">
            {job.location && (
              <span className="flex items-center gap-1 text-text-dim">
                <MapPin className="w-3.5 h-3.5" />
                {job.location}
              </span>
            )}
            {job.isRemote && (
              <span className="flex items-center gap-1 text-mint">
                <Globe className="w-3.5 h-3.5" />
                Remote
              </span>
            )}
            {job.salary && (
              <span className="flex items-center gap-1 text-success">
                <DollarSign className="w-3.5 h-3.5" />
                {job.salary}
              </span>
            )}
            {job.postedDate && (
              <span className="flex items-center gap-1 text-text-dim">
                <Clock className="w-3.5 h-3.5" />
                {job.postedDate}
              </span>
            )}
          </div>

          {/* Description Preview (only when collapsed) */}
          {!isExpanded && job.description && (
            <p className="mt-3 text-text-muted text-sm line-clamp-2">
              {job.description}
            </p>
          )}
        </div>

        {/* Apply Button */}
        {job.applicationUrl && (
          <motion.a
            href={job.applicationUrl}
            target="_blank"
            rel="noopener noreferrer"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={(e) => e.stopPropagation()}
            className="shrink-0 bg-accent hover:bg-accent-light text-white p-2.5 rounded-xl transition-colors"
          >
            <ExternalLink className="w-4 h-4" />
          </motion.a>
        )}
      </div>

      {/* Expanded Content */}
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            className="overflow-hidden"
          >
            <div className="mt-5 pt-5 border-t border-border">
              {/* Full Description */}
              {job.description && (
                <div className="mb-5">
                  <h4 className="text-sm font-semibold text-text mb-2 flex items-center gap-2">
                    <Briefcase className="w-4 h-4 text-accent" />
                    Job Description
                  </h4>
                  <p className="text-text-muted text-sm leading-relaxed whitespace-pre-wrap">
                    {job.description}
                  </p>
                </div>
              )}

              {/* Job Details Grid */}
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-5">
                {job.employmentType && (
                  <div className="bg-surface-light rounded-xl p-3">
                    <div className="flex items-center gap-2 text-text-dim text-xs mb-1">
                      <Briefcase className="w-3.5 h-3.5" />
                      Employment Type
                    </div>
                    <p className="text-text font-medium text-sm">{job.employmentType}</p>
                  </div>
                )}
                {job.location && (
                  <div className="bg-surface-light rounded-xl p-3">
                    <div className="flex items-center gap-2 text-text-dim text-xs mb-1">
                      <MapPin className="w-3.5 h-3.5" />
                      Location
                    </div>
                    <p className="text-text font-medium text-sm">{job.location}</p>
                  </div>
                )}
                {job.salary && (
                  <div className="bg-surface-light rounded-xl p-3">
                    <div className="flex items-center gap-2 text-text-dim text-xs mb-1">
                      <DollarSign className="w-3.5 h-3.5" />
                      Salary
                    </div>
                    <p className="text-success font-medium text-sm">{job.salary}</p>
                  </div>
                )}
                {job.postedDate && (
                  <div className="bg-surface-light rounded-xl p-3">
                    <div className="flex items-center gap-2 text-text-dim text-xs mb-1">
                      <Calendar className="w-3.5 h-3.5" />
                      Posted
                    </div>
                    <p className="text-text font-medium text-sm">{job.postedDate}</p>
                  </div>
                )}
                {job.isRemote && (
                  <div className="bg-surface-light rounded-xl p-3">
                    <div className="flex items-center gap-2 text-text-dim text-xs mb-1">
                      <Globe className="w-3.5 h-3.5" />
                      Work Style
                    </div>
                    <p className="text-mint font-medium text-sm">Remote Available</p>
                  </div>
                )}
                <div className="bg-surface-light rounded-xl p-3">
                  <div className="flex items-center gap-2 text-text-dim text-xs mb-1">
                    <Users className="w-3.5 h-3.5" />
                    Company
                  </div>
                  <p className="text-text font-medium text-sm">{job.company}</p>
                </div>
              </div>

              {/* Apply Button (Full Width when expanded) */}
              {job.applicationUrl && (
                <motion.a
                  href={job.applicationUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={(e) => e.stopPropagation()}
                  className="w-full bg-gradient-to-r from-accent to-lavender text-white font-semibold py-3 px-6 rounded-xl flex items-center justify-center gap-2 transition-all"
                >
                  <ExternalLink className="w-4 h-4" />
                  Apply Now
                </motion.a>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Read More / Read Less Button */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="mt-4 w-full flex items-center justify-center gap-2 text-text-dim hover:text-accent text-sm transition-colors py-2"
      >
        <span>{isExpanded ? 'Show less' : 'Read more'}</span>
        <motion.div
          animate={{ rotate: isExpanded ? 180 : 0 }}
          transition={{ duration: 0.3 }}
        >
          <ChevronDown className="w-4 h-4" />
        </motion.div>
      </button>
    </motion.div>
  );
}
