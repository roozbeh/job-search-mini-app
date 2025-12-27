import { useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { X, CheckCircle, AlertTriangle, AlertCircle, FileText, Activity } from 'lucide-react';
import type { DetailedReview } from '../types';

interface DetailedReviewModalProps {
    isOpen: boolean;
    onClose: () => void;
    review: DetailedReview | null;
    isLoading: boolean;
}

export function DetailedReviewModal({ isOpen, onClose, review, isLoading }: DetailedReviewModalProps) {
    // Close on click outside
    const backdropRef = useRef<HTMLDivElement>(null);
    const handleBackdropClick = (e: React.MouseEvent) => {
        if (e.target === backdropRef.current) {
            onClose();
        }
    };

    const getScoreColor = (score: number) => {
        if (score >= 80) return 'text-success';
        if (score >= 60) return 'text-warning';
        return 'text-coral';
    };

    const getScoreBg = (score: number) => {
        if (score >= 80) return 'bg-success/10 border-success/20';
        if (score >= 60) return 'bg-warning/10 border-warning/20';
        return 'bg-coral/10 border-coral/20';
    };

    const getStatusIcon = (status: string) => {
        switch (status) {
            case 'success': return <CheckCircle className="w-5 h-5 text-success" />;
            case 'warning': return <AlertTriangle className="w-5 h-5 text-warning" />;
            case 'error': return <AlertCircle className="w-5 h-5 text-coral" />;
            default: return null;
        }
    };

    return (
        <AnimatePresence>
            {isOpen && (
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 overflow-y-auto"
                    ref={backdropRef}
                    onClick={handleBackdropClick}
                >
                    <motion.div
                        initial={{ scale: 0.95, opacity: 0, y: 20 }}
                        animate={{ scale: 1, opacity: 1, y: 0 }}
                        exit={{ scale: 0.95, opacity: 0, y: 20 }}
                        className="bg-surface w-full max-w-4xl max-h-[90vh] rounded-3xl shadow-2xl flex flex-col overflow-hidden"
                    >
                        {/* Header */}
                        <div className="p-6 border-b border-border flex items-center justify-between bg-surface-light/50 sticky top-0 z-10 backdrop-blur-md">
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-accent/10 rounded-xl">
                                    <FileText className="w-6 h-6 text-accent" />
                                </div>
                                <div>
                                    <h2 className="text-xl font-display font-semibold text-text">Detailed CV Review</h2>
                                    <p className="text-sm text-text-muted">In-depth analysis & ATS compatibility</p>
                                </div>
                            </div>
                            <button
                                onClick={onClose}
                                className="p-2 hover:bg-surface-light rounded-full text-text-dim hover:text-text transition-colors"
                            >
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        {/* Content */}
                        <div className="flex-1 overflow-y-auto p-6 md:p-8 space-y-8">
                            {isLoading ? (
                                <div className="flex flex-col items-center justify-center py-20 text-center">
                                    <div className="w-16 h-16 border-4 border-accent/20 border-t-accent rounded-full animate-spin mb-6" />
                                    <h3 className="text-lg font-semibold text-text mb-2">Analyzing your CV...</h3>
                                    <p className="text-text-muted max-w-md">
                                        Our AI is reviewing every section and calculating your ATS score. This may take a moment.
                                    </p>
                                </div>
                            ) : review ? (
                                <>
                                    {/* ATS Score Section */}
                                    <section>
                                        <div className="flex items-center gap-3 mb-6">
                                            <Activity className="w-6 h-6 text-accent" />
                                            <h3 className="text-xl font-semibold text-text">ATS Compatibility</h3>
                                        </div>

                                        <div className="grid md:grid-cols-3 gap-6">
                                            {/* Main Score */}
                                            <div className={`col-span-1 rounded-2xl p-6 flex flex-col items-center justify-center text-center border ${getScoreBg(review.atsEvaluation.score)}`}>
                                                <span className="text-text-muted text-sm font-medium uppercase tracking-wider mb-2">Overall Score</span>
                                                <div className={`text-6xl font-bold font-display mb-2 ${getScoreColor(review.atsEvaluation.score)}`}>
                                                    {review.atsEvaluation.score}
                                                </div>
                                                <span className="text-sm text-text-dim">out of 100</span>
                                            </div>

                                            {/* Breakdown */}
                                            <div className="md:col-span-2 bg-surface-light rounded-2xl p-6">
                                                <div className="space-y-4">
                                                    {Object.entries(review.atsEvaluation.breakdown).map(([key, value]) => {
                                                        // Max points for each category based on prompt
                                                        let max = 15;
                                                        if (key === 'parseability') max = 25;
                                                        if (key === 'keywordAlignment') max = 30;

                                                        // Calculate percentage for width
                                                        const percentage = (value / max) * 100;

                                                        return (
                                                            <div key={key}>
                                                                <div className="flex justify-between text-sm mb-1.5">
                                                                    <span className="capitalize text-text font-medium">
                                                                        {key.replace(/([A-Z])/g, ' $1').trim()}
                                                                    </span>
                                                                    <span className="text-text-muted">{value}/{max}</span>
                                                                </div>
                                                                <div className="h-2 bg-surface rounded-full overflow-hidden">
                                                                    <div
                                                                        className="h-full bg-accent rounded-full transition-all duration-1000"
                                                                        style={{ width: `${percentage}%` }}
                                                                    />
                                                                </div>
                                                            </div>
                                                        );
                                                    })}
                                                </div>
                                            </div>
                                        </div>

                                        <div className="mt-6 bg-surface-light rounded-2xl p-6">
                                            <h4 className="font-semibold text-text mb-2">Why this score?</h4>
                                            <p className="text-text-muted mb-4">{review.atsEvaluation.explanation}</p>

                                            {review.atsEvaluation.warnings.length > 0 && (
                                                <div className="mt-4 p-4 bg-coral/5 border border-coral/20 rounded-xl">
                                                    <h5 className="text-coral text-sm font-bold flex items-center gap-2 mb-2">
                                                        <AlertCircle className="w-4 h-4" />
                                                        Parsing Warnings
                                                    </h5>
                                                    <ul className="list-disc list-inside text-sm text-text-muted space-y-1">
                                                        {review.atsEvaluation.warnings.map((warn, i) => (
                                                            <li key={i}>{warn}</li>
                                                        ))}
                                                    </ul>
                                                </div>
                                            )}
                                        </div>
                                    </section>

                                    <div className="w-full h-px bg-border" />

                                    {/* Top ATS Fixes */}
                                    <section>
                                        <h3 className="text-xl font-semibold text-text mb-4">Top ATS Optimizations</h3>
                                        <div className="grid gap-4">
                                            {review.atsEvaluation.topFixes.map((fix, i) => (
                                                <div key={i} className="flex items-start gap-4 p-4 bg-surface-light rounded-xl">
                                                    <div className="bg-accent/10 text-accent font-bold rounded-lg w-8 h-8 flex items-center justify-center shrink-0">
                                                        {i + 1}
                                                    </div>
                                                    <p className="text-text">{fix}</p>
                                                </div>
                                            ))}
                                        </div>
                                    </section>

                                    <div className="w-full h-px bg-border" />

                                    {/* Section-by-Section Feedback */}
                                    <section>
                                        <h3 className="text-xl font-semibold text-text mb-6">Detailed Section Analysis</h3>
                                        <div className="space-y-6">
                                            {review.sectionFeedback.map((section, idx) => (
                                                <div key={idx} className="bg-surface-light rounded-2xl p-6">
                                                    <div className="flex items-center gap-3 mb-3">
                                                        {getStatusIcon(section.status)}
                                                        <h4 className="text-lg font-bold text-text">{section.sectionName}</h4>
                                                    </div>
                                                    <p className="text-text-muted mb-4">{section.feedback}</p>

                                                    {section.recommendations.length > 0 && (
                                                        <div className="bg-surface rounded-xl p-4">
                                                            <p className="text-sm font-medium text-text-dim mb-2 uppercase tracking-wide">Recommendations</p>
                                                            <ul className="space-y-2">
                                                                {section.recommendations.map((rec, i) => (
                                                                    <li key={i} className="flex items-start gap-2 text-sm text-text">
                                                                        <span className="text-accent mt-0.5">•</span>
                                                                        <span>{rec}</span>
                                                                    </li>
                                                                ))}
                                                            </ul>
                                                        </div>
                                                    )}
                                                </div>
                                            ))}
                                        </div>
                                    </section>
                                </>
                            ) : null}
                        </div>
                    </motion.div>
                </motion.div>
            )}
        </AnimatePresence>
    );
}
