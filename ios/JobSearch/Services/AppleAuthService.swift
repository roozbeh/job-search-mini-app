import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class AppleAuthService: NSObject, ObservableObject {

    static let shared = AppleAuthService()

    @Published var isLoggedIn = false
    @Published var userId: String? = nil
    @Published var isLoggingIn = false
    @Published var loginError: String? = nil

    private let userIdKey = "apple_user_id"

    override init() {
        super.init()
        if let id = UserDefaults.standard.string(forKey: userIdKey), !id.isEmpty {
            userId = id
            isLoggedIn = true
        }
    }

    /// Stable session key for this Apple user — used as apiKey in session endpoints.
    var sessionKey: String { userId.map { "apple_\($0)" } ?? "" }

    func signIn() async {
        isLoggingIn = true
        loginError = nil
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate()
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        do {
            let credential = try await delegate.authorize(controller: controller)
            userId = credential.user
            UserDefaults.standard.set(credential.user, forKey: userIdKey)
            isLoggedIn = true
        } catch {
            loginError = "Sign in failed. Please try again."
        }
        isLoggingIn = false
    }

    func logout() {
        userId = nil
        UserDefaults.standard.removeObject(forKey: userIdKey)
        isLoggedIn = false
    }

    /// Check Apple credential state; auto-logout if revoked.
    func validateCredential() async {
        guard let id = userId else { return }
        guard let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: id) else { return }
        if state == .revoked || state == .notFound { logout() }
    }
}

// MARK: - Delegate using async continuation

private final class AppleSignInDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func authorize(controller: ASAuthorizationController) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: NSError(domain: "AppleAuth", code: -1))
            return
        }
        continuation?.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}
