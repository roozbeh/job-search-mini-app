import { useState } from 'react';
import { motion } from 'motion/react';
import { MapPin, DollarSign, Briefcase, Globe, Plus, X, Search } from 'lucide-react';
import type { JobPreferences } from '../types';

interface PreferencesFormProps {
  preferences: JobPreferences;
  onUpdate: (preferences: JobPreferences) => void;
  onSearch: () => void;
  isSearching: boolean;
  apiCallsRemaining: number;
  hasApiKey: boolean;
}

export function PreferencesForm({
  preferences,
  onUpdate,
  onSearch,
  isSearching,
  apiCallsRemaining,
  hasApiKey
}: PreferencesFormProps) {
  const [newTitle, setNewTitle] = useState('');
  const [newLocation, setNewLocation] = useState('');

  const addJobTitle = () => {
    if (newTitle.trim() && !preferences.jobTitles.includes(newTitle.trim())) {
      onUpdate({ ...preferences, jobTitles: [...preferences.jobTitles, newTitle.trim()] });
      setNewTitle('');
    }
  };

  const removeJobTitle = (title: string) => {
    onUpdate({ ...preferences, jobTitles: preferences.jobTitles.filter(t => t !== title) });
  };

  const addLocation = () => {
    if (newLocation.trim() && !preferences.locations.includes(newLocation.trim())) {
      onUpdate({ ...preferences, locations: [...preferences.locations, newLocation.trim()] });
      setNewLocation('');
    }
  };

  const removeLocation = (location: string) => {
    onUpdate({ ...preferences, locations: preferences.locations.filter(l => l !== location) });
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.2 }}
      className="glass rounded-3xl p-6 md:p-8"
    >
      <h2 className="text-2xl font-display font-semibold mb-6 flex items-center gap-2">
        <Briefcase className="w-6 h-6 text-accent" />
        Job Preferences
      </h2>

      {/* Job Titles */}
      <div className="mb-6">
        <label className="block text-text-muted text-sm mb-2 font-medium">
          Job Titles
        </label>
        <div className="flex gap-2 mb-3">
          <input
            type="text"
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && addJobTitle()}
            placeholder="e.g., Frontend Developer"
            className="flex-1 bg-surface-light border border-border rounded-xl px-4 py-3 text-text placeholder:text-text-dim focus:border-accent transition-colors"
          />
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={addJobTitle}
            className="bg-accent hover:bg-accent-light text-white p-3 rounded-xl transition-colors"
          >
            <Plus className="w-5 h-5" />
          </motion.button>
        </div>
        <div className="flex flex-wrap gap-2">
          {preferences.jobTitles.map((title) => (
            <motion.span
              key={title}
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0 }}
              className="bg-surface-light text-text px-3 py-1.5 rounded-full text-sm flex items-center gap-2"
            >
              {title}
              <button onClick={() => removeJobTitle(title)} className="text-text-dim hover:text-coral transition-colors">
                <X className="w-4 h-4" />
              </button>
            </motion.span>
          ))}
        </div>
      </div>

      {/* Locations */}
      <div className="mb-6">
        <label className="block text-text-muted text-sm mb-2 font-medium flex items-center gap-2">
          <MapPin className="w-4 h-4" />
          Preferred Locations
        </label>
        <div className="flex gap-2 mb-3">
          <input
            type="text"
            value={newLocation}
            onChange={(e) => setNewLocation(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && addLocation()}
            placeholder="e.g., San Francisco, CA"
            className="flex-1 bg-surface-light border border-border rounded-xl px-4 py-3 text-text placeholder:text-text-dim focus:border-accent transition-colors"
          />
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={addLocation}
            className="bg-mint/20 hover:bg-mint/30 text-mint p-3 rounded-xl transition-colors"
          >
            <Plus className="w-5 h-5" />
          </motion.button>
        </div>
        <div className="flex flex-wrap gap-2">
          {preferences.locations.map((location) => (
            <motion.span
              key={location}
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              className="bg-mint/10 text-mint px-3 py-1.5 rounded-full text-sm flex items-center gap-2"
            >
              <MapPin className="w-3 h-3" />
              {location}
              <button onClick={() => removeLocation(location)} className="hover:text-coral transition-colors">
                <X className="w-4 h-4" />
              </button>
            </motion.span>
          ))}
        </div>
      </div>

      {/* Remote Toggle */}
      <div className="mb-6">
        <label className="flex items-center gap-3 cursor-pointer">
          <div className="relative">
            <input
              type="checkbox"
              checked={preferences.isRemote}
              onChange={(e) => onUpdate({ ...preferences, isRemote: e.target.checked })}
              className="sr-only peer"
            />
            <div className="w-12 h-6 bg-surface-light rounded-full peer-checked:bg-accent transition-colors" />
            <div className="absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full transition-transform peer-checked:translate-x-6" />
          </div>
          <span className="text-text flex items-center gap-2">
            <Globe className="w-4 h-4 text-lavender" />
            Include Remote Jobs
          </span>
        </label>
      </div>

      {/* Salary Range */}
      <div className="mb-8">
        <label className="block text-text-muted text-sm mb-2 font-medium flex items-center gap-2">
          <DollarSign className="w-4 h-4" />
          Salary Range (USD/year)
        </label>
        <div className="flex gap-4">
          <div className="flex-1">
            <input
              type="number"
              value={preferences.salaryMin || ''}
              onChange={(e) => onUpdate({ ...preferences, salaryMin: e.target.value ? parseInt(e.target.value) : null })}
              placeholder="Min"
              className="w-full bg-surface-light border border-border rounded-xl px-4 py-3 text-text placeholder:text-text-dim focus:border-accent transition-colors"
            />
          </div>
          <span className="text-text-dim self-center">—</span>
          <div className="flex-1">
            <input
              type="number"
              value={preferences.salaryMax || ''}
              onChange={(e) => onUpdate({ ...preferences, salaryMax: e.target.value ? parseInt(e.target.value) : null })}
              placeholder="Max"
              className="w-full bg-surface-light border border-border rounded-xl px-4 py-3 text-text placeholder:text-text-dim focus:border-accent transition-colors"
            />
          </div>
        </div>
      </div>

      {/* Search Button */}
      <motion.button
        whileHover={{ scale: 1.02 }}
        whileTap={{ scale: 0.98 }}
        onClick={onSearch}
        disabled={isSearching || preferences.jobTitles.length === 0 || apiCallsRemaining <= 0 || !hasApiKey}
        className="w-full bg-gradient-to-r from-accent to-lavender text-white font-semibold py-4 px-6 rounded-2xl flex items-center justify-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed glow-accent transition-all"
      >
        {isSearching ? (
          <>
            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            Searching...
          </>
        ) : !hasApiKey ? (
          <>
            <Search className="w-5 h-5" />
            Login or enter API key to search
          </>
        ) : (
          <>
            <Search className="w-5 h-5" />
            Find Jobs
            <span className="text-white/70 text-sm">({apiCallsRemaining} searches left)</span>
          </>
        )}
      </motion.button>
    </motion.div>
  );
}
