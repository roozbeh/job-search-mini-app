import { Briefcase, Sparkles } from 'lucide-react';
import { motion } from 'motion/react';

export function Header() {
  return (
    <motion.header
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6 }}
      className="relative z-10 pt-8 pb-12 px-6 text-center"
    >
      <div className="flex items-center justify-center gap-3 mb-4">
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 0.2, type: 'spring', stiffness: 200 }}
          className="relative"
        >
          <div className="absolute inset-0 bg-accent/30 blur-xl rounded-full" />
          <div className="relative bg-gradient-to-br from-accent to-lavender p-3 rounded-2xl">
            <Briefcase className="w-8 h-8 text-white" />
          </div>
        </motion.div>
        <motion.h1
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.3 }}
          className="text-4xl md:text-5xl font-display font-semibold tracking-tight"
        >
          <span className="gradient-text">JobFlow</span>
        </motion.h1>
      </div>
      
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5 }}
        className="text-text-muted text-lg max-w-xl mx-auto flex items-center justify-center gap-2"
      >
        <Sparkles className="w-4 h-4 text-accent" />
        AI-powered job search that understands your career goals
        <Sparkles className="w-4 h-4 text-accent" />
      </motion.p>
    </motion.header>
  );
}


