import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Key, Eye, EyeOff, Check, AlertCircle, ExternalLink } from 'lucide-react';

const STORAGE_KEY = 'jobflow_api_key';

interface ApiKeyInputProps {
  onApiKeyChange: (apiKey: string | null) => void;
}

export function ApiKeyInput({ onApiKeyChange }: ApiKeyInputProps) {
  const [apiKey, setApiKey] = useState('');
  const [showKey, setShowKey] = useState(false);
  const [isSaved, setIsSaved] = useState(false);
  const [isExpanded, setIsExpanded] = useState(true);
  const hasInitialized = useRef(false);

  // Initialize from localStorage on mount only
  useEffect(() => {
    if (hasInitialized.current) return;
    hasInitialized.current = true;

    const savedKey = localStorage.getItem(STORAGE_KEY);
    if (savedKey) {
      setApiKey(savedKey);
      setIsSaved(true);
      setIsExpanded(false);
      onApiKeyChange(savedKey);
    }
  }, []); // Empty dependency array - run once on mount

  const handleSave = () => {
    const trimmedKey = apiKey.trim();
    if (trimmedKey) {
      localStorage.setItem(STORAGE_KEY, trimmedKey);
      setIsSaved(true);
      setIsExpanded(false);
      onApiKeyChange(trimmedKey);
    }
  };

  const handleClear = () => {
    localStorage.removeItem(STORAGE_KEY);
    setApiKey('');
    setIsSaved(false);
    setIsExpanded(true);
    onApiKeyChange(null);
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setApiKey(e.target.value);
    if (isSaved) {
      setIsSaved(false);
    }
  };

  const maskedKey = apiKey ? `${apiKey.slice(0, 15)}...${apiKey.slice(-8)}` : '';

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.1 }}
      className="glass rounded-3xl p-6 mb-6"
    >
      <div
        className="flex items-center justify-between cursor-pointer"
        onClick={() => !isSaved && setIsExpanded(!isExpanded)}
      >
        <div className="flex items-center gap-3">
          <div className={`p-2.5 rounded-xl ${isSaved ? 'bg-success/20' : 'bg-warning/20'}`}>
            <Key className={`w-5 h-5 ${isSaved ? 'text-success' : 'text-warning'}`} />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-text flex items-center gap-2">
              API Key
              {isSaved && <Check className="w-4 h-4 text-success" />}
            </h3>
            <p className="text-text-dim text-sm">
              {isSaved ? 'Connected to AgnicPay' : 'Required to search jobs'}
            </p>
          </div>
        </div>

        {isSaved && (
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); setIsExpanded(!isExpanded); }}
            className="text-text-dim hover:text-text text-sm transition-colors"
          >
            {isExpanded ? 'Hide' : 'Edit'}
          </button>
        )}
      </div>

      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-hidden"
          >
            <div className="pt-5 space-y-4">
              {!isSaved && (
                <div className="bg-surface-light rounded-xl p-4 flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-warning shrink-0 mt-0.5" />
                  <div className="text-sm">
                    <p className="text-text-muted mb-2">
                      You need an API key from AgnicPay to search for jobs and analyze your CV.
                    </p>
                    <div className="space-y-1">
                      <p className="text-text-dim text-xs">1. Register at AgnicPay.xyz</p>
                      <p className="text-text-dim text-xs">2. Create a new connection in your Agnic Wallet</p>
                      <p className="text-text-dim text-xs">3. Get your API key from your Agnic Wallet</p>
                    </div>
                    <a
                      href="https://agnicpay.xyz"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-accent hover:text-accent-light inline-flex items-center gap-1 transition-colors mt-2"
                    >
                      Go to AgnicPay.xyz
                      <ExternalLink className="w-3.5 h-3.5" />
                    </a>
                  </div>
                </div>
              )}

              <div className="relative">
                <input
                  type={showKey ? 'text' : 'password'}
                  value={apiKey}
                  onChange={handleInputChange}
                  placeholder="agnic_tok_eyJhbGciOiJI..."
                  className="w-full bg-surface-light border border-border rounded-xl px-4 py-3 pr-12 text-text placeholder:text-text-dim focus:border-accent transition-colors font-mono text-sm"
                />
                <button
                  type="button"
                  onClick={() => setShowKey(!showKey)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-dim hover:text-text transition-colors"
                >
                  {showKey ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={handleSave}
                  disabled={!apiKey.trim()}
                  className="flex-1 bg-accent hover:bg-accent-light text-white font-medium py-2.5 px-4 rounded-xl disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                >
                  Save Key
                </button>
                {isSaved && (
                  <button
                    type="button"
                    onClick={handleClear}
                    className="bg-coral/20 hover:bg-coral/30 text-coral font-medium py-2.5 px-4 rounded-xl transition-colors"
                  >
                    Remove
                  </button>
                )}
              </div>

              {isSaved && (
                <p className="text-text-dim text-xs">
                  Stored locally in your browser • {maskedKey}
                </p>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
