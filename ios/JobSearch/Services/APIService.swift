import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

// MARK: - Agnic OAuth (PKCE)

@MainActor
final class AgnicAuthService: NSObject, ObservableObject {

    static let shared = AgnicAuthService()

    @Published var isLoggedIn = false
    @Published var accessToken: String? = nil
    @Published var isLoggingIn = false
    @Published var loginError: String? = nil

    private let clientId    = "app_8e1104734685043d152d6184"
    private let authURL     = URL(string: "https://api.agnic.ai/oauth/authorize")!
    private let tokenURL    = URL(string: "https://api.agnic.ai/oauth/token")!
    private let balanceURL  = URL(string: "https://api.agnic.ai/api/balance?network=base")!
    private let redirectURI = "https://jobsearch.ipronto.net/api/oauth/callback"
    private let scheme      = "jobsearch"
    private let scopes      = "payments:sign balance:read"
    private let tokenKey    = "agnic_access_token"
    private var authSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        if let t = UserDefaults.standard.string(forKey: tokenKey), !t.isEmpty {
            accessToken = t
            isLoggedIn  = true
        }
    }

    /// Validate stored token against Agnic; logout if expired. Call on app startup.
    func validateStoredToken() async {
        guard let token = accessToken else { return }
        var req = URLRequest(url: balanceURL, timeoutInterval: 10)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode != 401 else {
            logout()
            return
        }
    }

    func login() async {
        isLoggingIn = true
        loginError  = nil
        defer { isLoggingIn = false }
        do {
            let verifier   = randomString(64)
            let challenge  = pkceChallenge(verifier)
            let state      = randomString(32)

            var comps = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                .init(name: "response_type",          value: "code"),
                .init(name: "client_id",              value: clientId),
                .init(name: "redirect_uri",           value: redirectURI),
                .init(name: "state",                  value: state),
                .init(name: "scope",                  value: scopes),
                .init(name: "code_challenge",         value: challenge),
                .init(name: "code_challenge_method",  value: "S256"),
            ]

            let code = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                let session = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: scheme) { url, error in
                    if let error { cont.resume(throwing: error); return }
                    guard let url,
                          let c    = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let code = c.queryItems?.first(where: { $0.name == "code" })?.value
                    else { cont.resume(throwing: AuthError.noCode); return }
                    cont.resume(returning: code)
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.authSession = session
                session.start()
            }
            authSession = nil

            let token = try await exchangeCode(code, verifier: verifier)
            accessToken = token
            isLoggedIn  = true
            loginError  = nil
            UserDefaults.standard.set(token, forKey: tokenKey)
        } catch let err as ASWebAuthenticationSessionError where err.code == .canceledLogin {
            // User tapped Cancel — no error message needed
        } catch {
            loginError = error.localizedDescription
        }
    }

    func logout() {
        accessToken = nil
        isLoggedIn  = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    // MARK: - Private helpers

    private func exchangeCode(_ code: String, verifier: String) async throws -> String {
        var req = URLRequest(url: tokenURL, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  redirectURI,
            "client_id":     clientId,
            "code_verifier": verifier,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String
        else { throw AuthError.tokenExchangeFailed }
        return token
    }

    private func randomString(_ length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private func pkceChallenge(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    enum AuthError: LocalizedError {
        case noCode, tokenExchangeFailed
        var errorDescription: String? {
            switch self {
            case .noCode:              return "Login cancelled or no code received."
            case .tokenExchangeFailed: return "Failed to complete login. Please try again."
            }
        }
    }
}

extension AgnicAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(String)
    case serverError(String)
    case networkError(String)
    case rateLimitExceeded
    case missingAPIKey
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL:         return "Invalid URL configuration."
        case .noData:             return "No data received from server."
        case .decodingFailed(let msg): return "Failed to parse response: \(msg)"
        case .serverError(let msg):    return "Server error: \(msg)"
        case .networkError(let msg):   return "Network error: \(msg)"
        case .rateLimitExceeded:  return "Rate limit reached. Please try again later."
        case .missingAPIKey:      return "API key is required. Please add it in Settings."
        case .tokenExpired:       return "Your Agnic session expired. Please sign in again."
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
    func analyzeCV(text: String, apiKey: String) async throws -> CVAnalysisData {
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
    func detailedReview(text: String, apiKey: String) async throws -> DetailedReviewData {
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
            "jobTypes": preferences.jobTypes.map { $0.rawValue },
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

    // MARK: - Session Sync

    func loadSession(apiKey: String) async throws -> UserSession? {
        let url = try makeURL("/api/session/load")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["apiKey": apiKey])

        struct SessionResponse: Codable {
            let status: String
            let data: UserSession?
        }
        let response: SessionResponse = try await perform(request)
        return response.data
    }

    func saveSession(_ session: UserSession, apiKey: String) async throws {
        let url = try makeURL("/api/session/save")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        let sessionData = try encoder.encode(session)
        let sessionJSON = try JSONSerialization.jsonObject(with: sessionData)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["apiKey": apiKey, "session": sessionJSON])

        struct SaveResponse: Codable { let status: String }
        let _: SaveResponse = try await perform(request)
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
                if http.statusCode == 401 { throw APIError.tokenExpired }
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
