import Foundation

// MARK: - Resume

struct Resume: Codable, Equatable {
    let rawText: String
    let fileName: String
    var analysis: ResumeAnalysis?

    static func == (lhs: Resume, rhs: Resume) -> Bool {
        lhs.fileName == rhs.fileName && lhs.rawText == rhs.rawText
    }
}

struct ResumeAnalysis: Codable {
    let atsScore: Int
    let summary: String
    let improvements: [Improvement]
    let extractedCriteria: ExtractedCriteria
    let sectionFeedback: [SectionFeedback]
}

struct Improvement: Codable, Identifiable {
    var id: String { title }
    let title: String
    let description: String
    let priority: Priority

    enum Priority: String, Codable {
        case high, medium, low
    }
}

struct ExtractedCriteria: Codable {
    let jobTitles: [String]
    let skills: [String]
    let yearsOfExperience: Int
    let preferredLocations: [String]
    let isRemotePreferred: Bool
    let salaryRange: SalaryRange
    let industries: [String]
}

struct SalaryRange: Codable {
    let min: Int?
    let max: Int?
    let currency: String

    var displayString: String {
        guard let min = min, let max = max else { return "Not specified" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.isEmpty ? "USD" : currency
        formatter.maximumFractionDigits = 0
        let lo = formatter.string(from: NSNumber(value: min)) ?? "\(min)"
        let hi = formatter.string(from: NSNumber(value: max)) ?? "\(max)"
        return "\(lo) – \(hi)"
    }
}

struct SectionFeedback: Codable, Identifiable {
    var id: String { section }
    let section: String
    let status: FeedbackStatus
    let message: String
    let suggestions: [String]

    enum FeedbackStatus: String, Codable {
        case success, warning, error
    }
}

// MARK: - Job Preferences

struct JobPreferences: Codable {
    var jobTitles: [String] = []
    var locations: [String] = []
    var isRemote: Bool = false
    var salaryMin: Int? = nil
    var jobTypes: Set<JobType> = []

    enum JobType: String, Codable, CaseIterable, Identifiable {
        case fullTime   = "Full-time"
        case partTime   = "Part-time"
        case contract   = "Contract"
        case internship = "Internship"

        var id: String { rawValue }
    }
}

// MARK: - Job

struct Job: Codable, Identifiable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let title: String
    let company: String
    let location: String
    let salary: String?
    let description: String?
    let postedDate: String?
    let applicationUrl: String?
    let companyLogo: String?
    let isRemote: Bool
    let employmentType: String?
    var matchScore: Int?
    var matchGuidance: MatchGuidance?

    static func == (lhs: Job, rhs: Job) -> Bool { lhs.id == rhs.id }
}

struct MatchGuidance: Codable {
    let matchScore: Int              // 0-100
    let matchingSkills: [String]
    let missingSkills: [String]
    let resumeUpdates: [ResumeUpdate]
    let overallSummary: String
    let recommendation: String       // "Strong match" | "Good match" | "Stretch role"
}

struct ResumeUpdate: Codable, Identifiable {
    var id: String { section + suggestedAddition.prefix(20) }
    let section: String              // e.g. "Skills", "Work Experience"
    let suggestedAddition: String    // Text to add/change
    let reason: String               // Why this helps match the job
}

// MARK: - Saved Job

struct SavedJob: Codable, Identifiable {
    var job: Job
    let savedAt: Date
    var isApplied: Bool = false
    var applicationNotes: String = ""

    var id: String { job.id }
}

// MARK: - API Wrappers (matching existing backend format)

struct APIResponse<T: Codable>: Codable {
    let status: String
    let data: T?

    struct APIError: Codable {
        let message: String
    }
    let error: APIError?
}

struct CVAnalysisData: Codable {
    let extractedCriteria: ExtractedCriteria
    let improvements: [Improvement]
    let summary: String
}

struct DetailedReviewData: Codable {
    let sectionFeedback: [SectionFeedback]
    let atsEvaluation: ATSEvaluation
}

struct ATSEvaluation: Codable {
    let score: Int
    let breakdown: ATSBreakdown
    let explanation: String
    let topFixes: [String]
    let warnings: [String]
}

struct ATSBreakdown: Codable {
    let parseability: Int
    let keywordAlignment: Int
    let formattingSimplicity: Int
    let sectionCompleteness: Int
    let roleSignalStrength: Int
}

struct ParsedCVData: Codable {
    let text: String
}

struct JobSearchData: Codable {
    let jobs: [Job]
}

// MARK: - App State

enum AppPhase: String, Codable {
    case onboarding
    case resumeUpload
    case resumeAnalysis
    case preferences
    case discovery
}

// MARK: - OpenAI Structures (for direct match scoring calls)

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let responseFormat: ResponseFormat
    let temperature: Double

    struct ResponseFormat: Codable {
        let type: String
        enum CodingKeys: String, CodingKey { case type }
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: OpenAIMessage
    }
}
