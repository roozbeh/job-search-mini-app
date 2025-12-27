import { Briefcase, Sparkles } from 'lucide-react';
import { motion } from 'motion/react';

export function Header() {
  return (
    <motion.header
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6 }}
      className="relative z-10 py-6"
    >
      <div className="flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.2, type: 'spring', stiffness: 200 }}
            className="relative"
          >
            <div className="absolute inset-0 bg-accent/30 blur-xl rounded-full" />
            <div className="relative bg-gradient-to-br from-accent to-lavender p-2.5 rounded-xl">
              <Briefcase className="w-6 h-6 text-white" />
            </div>
          </motion.div>
          <motion.h1
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.3 }}
            className="text-3xl font-display font-semibold tracking-tight"
          >
            <span className="gradient-text">JobFlow</span>
          </motion.h1>
        </div>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
          className="text-text-muted text-sm md:text-base flex items-center gap-2"
        >
          <Sparkles className="w-4 h-4 text-accent" />
          AI-powered job search that understands your career goals
          <Sparkles className="w-4 h-4 text-accent" />
        </motion.p>
      </div>
    </motion.header>
  );
}


