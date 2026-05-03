export function Support() {
  return (
    <div className="min-h-screen bg-slate-50">
      <header className="bg-white border-b border-slate-200">
        <div className="max-w-2xl mx-auto px-6 py-5 flex items-center gap-3">
          <div className="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center">
            <span className="text-white font-bold text-sm">RM</span>
          </div>
          <div>
            <h1 className="text-lg font-bold text-slate-900">ResuMatch</h1>
            <p className="text-xs text-slate-500">AI Job Search</p>
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-6 py-10 space-y-10">
        <section>
          <h2 className="text-2xl font-bold text-slate-900 mb-2">Support</h2>
          <p className="text-slate-600">
            Need help with ResuMatch? We're here for you. Reach out via email and we'll respond within 1–2 business days.
          </p>
          <a
            href="mailto:support@ipronto.net"
            className="inline-block mt-4 px-5 py-3 bg-blue-600 text-white font-medium rounded-xl hover:bg-blue-700 transition-colors"
          >
            Contact Support
          </a>
        </section>

        <section>
          <h2 className="text-xl font-bold text-slate-900 mb-5">Frequently Asked Questions</h2>
          <div className="space-y-5">
            {faqs.map((faq) => (
              <div key={faq.q} className="bg-white rounded-xl p-5 border border-slate-200">
                <h3 className="font-semibold text-slate-900 mb-2">{faq.q}</h3>
                <p className="text-slate-600 text-sm leading-relaxed">{faq.a}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="bg-white rounded-xl p-5 border border-slate-200">
          <h2 className="text-xl font-bold text-slate-900 mb-3">About ResuMatch</h2>
          <p className="text-slate-600 text-sm leading-relaxed">
            ResuMatch is an AI-powered job search app that analyzes your resume, matches you with relevant job openings,
            and helps you track your applications — all in one place. Built by iPronto Systems LLC.
          </p>
        </section>

        <section>
          <h2 className="text-xl font-bold text-slate-900 mb-3">Privacy & Data</h2>
          <p className="text-slate-600 text-sm leading-relaxed">
            Your resume and personal data are used solely to power your job search experience within the app.
            We do not sell or share your data with third parties. Authentication is handled securely via Agnic OAuth.
            You can request deletion of your data at any time by contacting us at{" "}
            <a href="mailto:support@ipronto.net" className="text-blue-600 underline">
              support@ipronto.net
            </a>
            .
          </p>
        </section>
      </main>

      <footer className="border-t border-slate-200 mt-10">
        <div className="max-w-2xl mx-auto px-6 py-6 text-center text-xs text-slate-400">
          &copy; {new Date().getFullYear()} iPronto Systems LLC · ResuMatch
        </div>
      </footer>
    </div>
  );
}

const faqs = [
  {
    q: "How does resume analysis work?",
    a: "Upload your resume (PDF or text) and our AI evaluates it for ATS compatibility, readability, and content quality. You get a score and specific improvement suggestions for each section.",
  },
  {
    q: "How are jobs matched to my resume?",
    a: "ResuMatch compares your resume's skills, experience, and preferences against job listings and surfaces the ones most likely to result in an interview — not just keyword matches.",
  },
  {
    q: "What job types and locations are supported?",
    a: "Full-time, part-time, contract, and internship roles across locations worldwide. You can filter by remote, hybrid, or on-site and set a minimum salary threshold.",
  },
  {
    q: "Is my resume stored securely?",
    a: "Yes. Your resume data is encrypted in transit and stored securely in our database. It is never shared with employers or third parties without your explicit action.",
  },
  {
    q: "How do I delete my account and data?",
    a: "Email us at support@ipronto.net with the subject 'Delete My Account' and we will remove all your data within 5 business days.",
  },
  {
    q: "The app isn't loading or I'm seeing an error — what should I do?",
    a: "Try force-closing and reopening the app. If the issue persists, check your internet connection, then contact us at support@ipronto.net with a description of the error.",
  },
];
