import Foundation

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(String)
    case serverError(String)
    case networkError(String)
    case rateLimitExceeded
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:         return "Invalid URL configuration."
        case .noData:             return "No data received from server."
        case .decodingFailed(let msg): return "Failed to parse response: \(msg)"
        case .serverError(let msg):    return "Server error: \(msg)"
        case .networkError(let msg):   return "Network error: \(msg)"
        case .rateLimitExceeded:  return "Rate limit reached. Please try again later."
        case .missingAPIKey:      return "API key is required. Please add it in Settings."
        }
    }
}

// MARK: - APIService

/// Bridges the iOS app to the existing JobFlow backend and the AgnicPay/OpenAI proxy.
///
/// Backend base URL is configurable so you can point at local dev, staging, or production.
/// All job-search and CV calls go through the backend (which holds the AgnicPay proxy logic).
/// Match-score computation calls OpenAI directly via the AgnicPay proxy to avoid
/// round-tripping large payloads through your own backend.
actor APIService {
    static let shared = APIService()

    // MARK: - Configuration
    private(set) var backendBaseURL: String = "https://jobsearch.ipronto.net"
    private(set) var apiKey: String = ""

    /// Update the backend URL at runtime (e.g. from Settings screen)
    func configure(backendURL: String, apiKey: String) {
        self.backendBaseURL = backendURL
        self.apiKey = apiKey
    }

    // MARK: - Resume Parsing

    /// Upload a PDF or plain-text file and get back extracted text.
    func parseResume(data: Data, fileName: String) async throws -> String {
        let url = try makeURL("/api/cv/parse")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"cv\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        let mime = fileName.hasSuffix(".pdf") ? "application/pdf" : "text/plain"
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let response: APIResponse<ParsedCVData> = try await perform(request)
        guard let text = response.data?.text, !text.isEmpty else {
            throw APIError.serverError(response.error?.message ?? "Empty resume text returned")
        }
        return text
    }

    // MARK: - CV Analysis

    /// Run AI analysis on resume text. Returns extracted criteria + improvement suggestions.
    func analyzeCV(text: String) async throws -> CVAnalysisData {
        let url = try makeURL("/api/cv/analyze")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["cvText": text, "apiKey": apiKey])

        let response: APIResponse<CVAnalysisData> = try await perform(request)
        guard let data = response.data else {
            throw APIError.serverError(response.error?.message ?? "CV analysis failed")
        }
        return data
    }

    /// Run detailed ATS scoring analysis on resume text.
    func detailedReview(text: String) async throws -> DetailedReviewData {
        let url = try makeURL("/api/cv/detailed-review")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["cvText": text, "apiKey": apiKey])

        let response: APIResponse<DetailedReviewData> = try await perform(request)
        guard let data = response.data else {
            throw APIError.serverError(response.error?.message ?? "Detailed review failed")
        }
        return data
    }

    // MARK: - Job Search

    /// Search for jobs matching the given preferences. The backend fans out to multiple
    /// job boards (LinkedIn, Indeed, Glassdoor) via AgnicHub and deduplicates results.
    func searchJobs(preferences: JobPreferences, resumeText: String) async throws -> [Job] {
        let url = try makeURL("/api/jobs/search")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jobTitles": preferences.jobTitles,
            "locations": preferences.locations,
            "isRemote": preferences.isRemote,
            "salaryMin": preferences.salaryMin as Any,
            "salaryMax": preferences.salaryMax as Any,
            "jobType": preferences.jobType.rawValue,
            "resumeText": resumeText,
            "apiKey": apiKey
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response: APIResponse<JobSearchData> = try await perform(request)
        guard let data = response.data else {
            throw APIError.serverError(response.error?.message ?? "Job search failed")
        }
        return data.jobs
    }

    // MARK: - Match Score (OpenAI direct via AgnicPay proxy)

    /// For a given job, compute how well the candidate's resume matches the job description.
    /// Returns a MatchGuidance object with score (0-100), matching/missing skills,
    /// and concrete resume update suggestions.
    ///
    /// This is called on-demand (when user swipes to a card or opens job detail) to avoid
    /// burning API quota on jobs the candidate never sees.
    func computeMatchScore(resumeText: String, job: Job) async throws -> MatchGuidance {
        guard !apiKey.isEmpty else { throw APIError.missingAPIKey }
        guard let description = job.description, !description.isEmpty else {
            // No job description — return a placeholder
            return MatchGuidance(
                matchScore: 0,
                matchingSkills: [],
                missingSkills: [],
                resumeUpdates: [],
                overallSummary: "No job description available to compute match score.",
                recommendation: "Unknown"
            )
        }

        let systemPrompt = """
        You are an expert recruiter and ATS specialist. Analyze how well a candidate's resume matches a job description.

        Return a JSON object with exactly this structure:
        {
          "matchScore": <integer 0-100>,
          "matchingSkills": [<strings>],
          "missingSkills": [<strings>],
          "resumeUpdates": [
            {
              "section": "<Skills|Work Experience|Summary|Education>",
              "suggestedAddition": "<exact text to add or change>",
              "reason": "<why this improves the match>"
            }
          ],
          "overallSummary": "<2 sentence summary of the match>",
          "recommendation": "<one of: Strong match|Good match|Stretch role|Not a good fit>"
        }

        Be honest and specific. Only include real skills from both documents. Provide 2-4 concrete resume updates max.
        """

        let userPrompt = """
        RESUME:
        \(resumeText.prefix(3000))

        JOB TITLE: \(job.title) at \(job.company)

        JOB DESCRIPTION:
        \(description.prefix(2000))
        """

        let requestBody = OpenAIRequest(
            model: "gpt-4o",
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: userPrompt)
            ],
            responseFormat: .init(type: "json_object"),
            temperature: 0.3
        )

        // Route through AgnicPay proxy (same as the web app)
        let url = URL(string: "https://api.agnic.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError("OpenAI returned HTTP \(http.statusCode)")
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw APIError.decodingFailed("Empty content from OpenAI")
        }

        return try JSONDecoder().decode(MatchGuidance.self, from: jsonData)
    }

    // MARK: - Private Helpers

    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: backendBaseURL + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func perform<T: Codable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 429 { throw APIError.rateLimitExceeded }
                if http.statusCode >= 500 {
                    throw APIError.serverError("HTTP \(http.statusCode)")
                }
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed(error.localizedDescription)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
}
