import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "doc.text.magnifyingglass",
            color: .indigo,
            title: "Your Resume, Supercharged",
            body: "Upload your resume once. We'll analyze it with AI and tell you exactly how to make it better — before you apply anywhere."
        ),
        OnboardingPage(
            icon: "sparkles",
            color: .purple,
            title: "Jobs That Actually Fit You",
            body: "We score every job against your resume so you only see roles you can realistically land — not just keyword matches."
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            color: .teal,
            title: "Apply Smarter",
            body: "See exactly what's missing from your resume for each job and fix it with one tap — before you hit Apply."
        ),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.indigo.opacity(0.08)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // Swipeable feature pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        OnboardingPageView(page: pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.indigo : Color.secondary.opacity(0.3))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Agnic explainer card
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "wallet.bifold.fill")
                            .foregroundStyle(.indigo)
                        Text("Powered by Agnic")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    Text("Agnic is an AI agent wallet — you're only charged for the tokens you actually use. Every new account starts with **$5 in free credits**.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Sign in CTA
                Button {
                    Task { await vm.auth.login() }
                } label: {
                    HStack(spacing: 10) {
                        if vm.auth.isLoggingIn {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                        }
                        Text(vm.auth.isLoggingIn ? "Signing in…" : "Sign in with Agnic")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
                }
                .disabled(vm.auth.isLoggingIn)
                .padding(.horizontal, 24)

                if let err = vm.auth.loginError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                }

                Text("New to Agnic? Visit pay.agnic.ai to create a free account.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Supporting Types

struct OnboardingPage {
    let icon: String
    let color: Color
    let title: String
    let body: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(page.color)
            }
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }
}
