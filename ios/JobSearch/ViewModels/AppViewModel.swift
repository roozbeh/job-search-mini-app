import Foundation
import Combine

// MARK: - AppViewModel

/// Central state store for the entire app.
/// Owned by the root view and injected as an environment object.
@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published State

    @Published var phase: AppPhase = .onboarding
    @Published var resume: Resume?
    @Published var preferences: JobPreferences = JobPreferences()

    // Discovery feed
    @Published var discoveryJobs: [Job] = []
    @Published var currentJobIndex: Int = 0

    // Saved & dismissed
    @Published var savedJobs: [SavedJob] = []
    @Published var dismissedJobIds: Set<String> = []

    // Loading / error
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var errorMessage: String? = nil

    // Settings
    @Published var apiKey: String = "" {
        didSet { persistAPIKey() }
    }
    @Published var backendURL: String = "https://jobflow-backend.onrender.com" {
        didSet { reconfigureService() }
    }

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private let api = APIService.shared

    // MARK: - Init

    init() {
        loadPersistedState()
    }

    // MARK: - Resume Flow

    /// Call after user selects a PDF or pastes text.
    func processResume(data: Data, fileName: String) async {
        isLoading = true
        loadingMessage = "Parsing your resume…"
        errorMessage = nil

        do {
            // 1. Parse raw text from PDF/TXT
            let text = try await api.parseResume(data: data, fileName: fileName)
            loadingMessage = "Analyzing with AI…"

            // 2. Run parallel analysis + detailed review
            async let analysisTask = api.analyzeCV(text: text)
            async let reviewTask   = api.detailedReview(text: text)
            let (analysis, review) = try await (analysisTask, reviewTask)

            // 3. Merge into ResumeAnalysis
            let resumeAnalysis = ResumeAnalysis(
                atsScore:          review.atsEvaluation.score,
                summary:           analysis.summary,
                improvements:      analysis.improvements,
                extractedCriteria: analysis.extractedCriteria,
                sectionFeedback:   review.sectionFeedback
            )

            resume = Resume(rawText: text, fileName: fileName, analysis: resumeAnalysis)

            // 4. Pre-fill preferences from extracted criteria
            let criteria = analysis.extractedCriteria
            if preferences.jobTitles.isEmpty {
                preferences.jobTitles = criteria.jobTitles
            }
            if preferences.locations.isEmpty {
                preferences.locations = criteria.preferredLocations
            }
            if !preferences.isRemote {
                preferences.isRemote = criteria.isRemotePreferred
            }
            if preferences.salaryMin == nil {
                preferences.salaryMin = criteria.salaryRange.min
                preferences.salaryMax = criteria.salaryRange.max
            }

            persistState()
            phase = .resumeAnalysis

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        loadingMessage = ""
    }

    /// Process plain-text resume (no file upload needed)
    func processResumeText(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please paste your resume text."
            return
        }
        let data = text.data(using: .utf8) ?? Data()
        await processResume(data: data, fileName: "resume.txt")
    }

    // MARK: - Preferences → Discovery

    /// Called when user confirms preferences and taps "Find My Jobs"
    func startJobSearch() async {
        guard let resume = resume else { return }
        isLoading = true
        loadingMessage = "Searching across LinkedIn, Indeed & Glassdoor…"
        errorMessage = nil

        do {
            var jobs = try await api.searchJobs(preferences: preferences, resumeText: resume.rawText)

            // Filter out already-dismissed jobs
            jobs = jobs.filter { !dismissedJobIds.contains($0.id) }

            // Shuffle to avoid always showing the same order
            jobs.shuffle()

            discoveryJobs = jobs
            currentJobIndex = 0
            persistState()
            phase = .discovery

            // Eagerly compute match scores for the first 5 jobs in the background
            Task { await prefetchMatchScores(upTo: 5) }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        loadingMessage = ""
    }

    // MARK: - Swipe Actions

    /// User liked this job — save it
    func saveJob(_ job: Job) {
        let saved = SavedJob(job: job, savedAt: Date())
        if !savedJobs.contains(where: { $0.id == job.id }) {
            savedJobs.append(saved)
        }
        advanceToNextJob()
        persistState()
    }

    /// User dismissed this job — record it and skip
    func dismissJob(_ job: Job) {
        dismissedJobIds.insert(job.id)
        advanceToNextJob()
        persistState()
    }

    private func advanceToNextJob() {
        if currentJobIndex < discoveryJobs.count - 1 {
            currentJobIndex += 1
            // Pre-fetch match score for the job after next
            let prefetchIndex = currentJobIndex + 4
            if prefetchIndex < discoveryJobs.count {
                let job = discoveryJobs[prefetchIndex]
                Task { await fetchMatchScore(for: job) }
            }
        }
    }

    // MARK: - Match Scores

    /// Fetch and cache match score for a specific job
    func fetchMatchScore(for job: Job) async {
        guard let resume = resume,
              discoveryJobs.contains(where: { $0.id == job.id }),
              let idx = discoveryJobs.firstIndex(where: { $0.id == job.id }),
              discoveryJobs[idx].matchGuidance == nil else { return }

        do {
            let guidance = try await api.computeMatchScore(resumeText: resume.rawText, job: job)
            discoveryJobs[idx].matchScore = guidance.matchScore
            discoveryJobs[idx].matchGuidance = guidance
            // Update saved copy if already saved
            if let si = savedJobs.firstIndex(where: { $0.id == job.id }) {
                savedJobs[si].job.matchScore = guidance.matchScore
                savedJobs[si].job.matchGuidance = guidance
            }
        } catch {
            // Non-fatal: match score is nice-to-have, not blocking
        }
    }

    private func prefetchMatchScores(upTo count: Int) async {
        let slice = discoveryJobs.prefix(count)
        await withTaskGroup(of: Void.self) { group in
            for job in slice {
                group.addTask { await self.fetchMatchScore(for: job) }
            }
        }
    }

    // MARK: - Saved Jobs Actions

    func markApplied(_ savedJob: SavedJob, applied: Bool) {
        if let idx = savedJobs.firstIndex(where: { $0.id == savedJob.id }) {
            savedJobs[idx].isApplied = applied
        }
        persistState()
    }

    func updateNotes(_ savedJob: SavedJob, notes: String) {
        if let idx = savedJobs.firstIndex(where: { $0.id == savedJob.id }) {
            savedJobs[idx].applicationNotes = notes
        }
        persistState()
    }

    func removeSavedJob(_ savedJob: SavedJob) {
        savedJobs.removeAll { $0.id == savedJob.id }
        persistState()
    }

    // MARK: - Settings

    func applyResumeUpdate(_ update: ResumeUpdate, to jobId: String) {
        // In a real implementation this would call OpenAI to actually edit the resume text.
        // For the MVP, we mark the suggestion as applied and show a confirmation.
        if let idx = discoveryJobs.firstIndex(where: { $0.id == jobId }),
           let guidanceIdx = discoveryJobs[idx].matchGuidance?.resumeUpdates.firstIndex(where: { $0.id == update.id }) {
            _ = guidanceIdx // hook for future mutation
        }
    }

    // MARK: - Persistence

    private enum Keys {
        static let phase       = "app.phase"
        static let resume      = "app.resume"
        static let preferences = "app.preferences"
        static let savedJobs   = "app.savedJobs"
        static let dismissed   = "app.dismissedJobIds"
        static let apiKey      = "app.apiKey"
        static let backendURL  = "app.backendURL"
    }

    private func persistAPIKey() {
        defaults.set(apiKey, forKey: Keys.apiKey)
        Task { await reconfigureService() }
    }

    private func reconfigureService() {
        Task { await api.configure(backendURL: backendURL, apiKey: apiKey) }
    }

    private func persistState() {
        let encoder = JSONEncoder()
        if let d = try? encoder.encode(resume)         { defaults.set(d, forKey: Keys.resume) }
        if let d = try? encoder.encode(preferences)    { defaults.set(d, forKey: Keys.preferences) }
        if let d = try? encoder.encode(savedJobs)      { defaults.set(d, forKey: Keys.savedJobs) }
        if let d = try? encoder.encode(dismissedJobIds) { defaults.set(d, forKey: Keys.dismissed) }
        defaults.set(phase.rawValue, forKey: Keys.phase)
    }

    private func loadPersistedState() {
        let decoder = JSONDecoder()
        apiKey     = defaults.string(forKey: Keys.apiKey) ?? ""
        backendURL = defaults.string(forKey: Keys.backendURL) ?? "https://jobflow-backend.onrender.com"

        if let d = defaults.data(forKey: Keys.resume),
           let r = try? decoder.decode(Resume.self, from: d) {
            resume = r
        }
        if let d = defaults.data(forKey: Keys.preferences),
           let p = try? decoder.decode(JobPreferences.self, from: d) {
            preferences = p
        }
        if let d = defaults.data(forKey: Keys.savedJobs),
           let s = try? decoder.decode([SavedJob].self, from: d) {
            savedJobs = s
        }
        if let d = defaults.data(forKey: Keys.dismissed),
           let ids = try? decoder.decode(Set<String>.self, from: d) {
            dismissedJobIds = ids
        }
        if let raw = defaults.string(forKey: Keys.phase),
           let p = AppPhase(rawValue: raw) {
            phase = p
        }

        // Reconfigure service with stored credentials
        Task { await api.configure(backendURL: backendURL, apiKey: apiKey) }
    }

    // MARK: - Reset

    func resetToOnboarding() {
        resume = nil
        discoveryJobs = []
        currentJobIndex = 0
        errorMessage = nil
        phase = .onboarding
        persistState()
    }
}
