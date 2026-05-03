import SwiftUI

// MARK: - Agnic Login Sheet

struct AgnicLoginSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Icon + title
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 64))
                        .foregroundStyle(.indigo)
                    Text(vm.auth.isLoggedIn ? "Signed In" : "Sign In with Agnic")
                        .font(.title2).bold()
                    Text(vm.auth.isLoggedIn
                         ? "Your Agnic wallet is connected. AI analysis runs on your account."
                         : "Connect your Agnic wallet to run AI-powered resume analysis and job search.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if vm.auth.isLoggedIn {
                    // Logged-in state
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Connected to Agnic")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .padding(.horizontal, 24).padding(.vertical, 14)
                        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

                        Button(role: .destructive) {
                            vm.auth.logout()
                            dismiss()
                        } label: {
                            Text("Sign Out")
                                .font(.subheadline).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                    }
                } else {
                    // Sign-in button
                    Button {
                        Task { await vm.auth.login() }
                    } label: {
                        HStack(spacing: 10) {
                            if vm.auth.isLoggingIn {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "person.crop.circle")
                            }
                            Text(vm.auth.isLoggingIn ? "Signing in…" : "Sign in with Agnic")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                    }
                    .disabled(vm.auth.isLoggingIn)
                    .padding(.horizontal)

                    if let err = vm.auth.loginError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Text("New to Agnic? Visit pay.agnic.ai to create a free account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: vm.auth.isLoggedIn) { _, loggedIn in
                if loggedIn { dismiss() }
            }
        }
    }
}

// MARK: - User Icon Button (reusable toolbar item — passes showLogin binding)

struct UserIconButton: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showLogin: Bool

    var body: some View {
        Button { showLogin = true } label: {
            Image(systemName: vm.auth.isLoggedIn
                  ? "person.crop.circle.fill"
                  : "person.crop.circle")
                .foregroundStyle(vm.auth.isLoggedIn ? .indigo : .secondary)
                .symbolEffect(.bounce, value: vm.auth.isLoggedIn)
        }
    }
}

// MARK: - Balance Pill (compact credit display for toolbar)

struct BalancePill: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 13))
            Text(vm.auth.balance?.displayUSD ?? "—")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemGray6), in: Capsule())
    }
}

// MARK: - Account Menu Button (for screens where user is always logged in)

struct AccountMenuButton: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 8) {
            BalancePill()
            Menu {
                Button(role: .destructive) {
                    vm.auth.logout()
                    vm.phase = .onboarding
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(.indigo)
            }
        }
    }
}

/// Root view: handles the onboarding/setup flow and the main tab bar.
struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        Group {
            switch vm.phase {
            case .onboarding:
                OnboardingView()
            case .resumeUpload:
                ResumeUploadView()
            case .resumeAnalysis:
                ResumeAnalysisView()
            case .preferences:
                PreferencesView()
            case .discovery:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.phase)
        // Global loading overlay
        .overlay {
            if vm.isLoading {
                LoadingOverlay(message: vm.loadingMessage)
            }
        }
        // Global error banner
        .overlay(alignment: .top) {
            if let error = vm.errorMessage {
                ErrorBanner(message: error) { vm.errorMessage = nil }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: vm.errorMessage)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Main Tab Bar (shown after setup is complete)

struct MainTabView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedTab: Tab = .discover

    enum Tab { case discover, saved, profile }

    var body: some View {
        TabView(selection: $selectedTab) {
            JobDiscoveryView(selectedTab: $selectedTab)
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .tag(Tab.discover)

            SavedJobsView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .badge(vm.savedJobs.filter { !$0.isApplied }.count)
                .tag(Tab.saved)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
        .tint(.indigo)
    }
}

// MARK: - Journey Step Bar

struct JourneyStepBar: View {
    let currentStep: Int  // 1 = Resume, 2 = Analysis, 3 = Preferences, 4 = Matches, 5 = Apply

    private let steps: [(icon: String, label: String)] = [
        ("doc.text",        "Resume"),
        ("sparkles",        "Analysis"),
        ("slider.horizontal.3", "Prefs"),
        ("briefcase",       "Matches"),
        ("checkmark.circle","Apply"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { i in
                let step  = i + 1
                let done  = step < currentStep
                let active = step == currentStep

                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(done || active ? Color.indigo : Color(.systemGray5))
                            .frame(width: 28, height: 28)
                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: steps[i].icon)
                                .font(.system(size: 11, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? .white : .secondary)
                        }
                    }
                    Text(steps[i].label)
                        .font(.system(size: 9, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? .indigo : .secondary)
                }

                if i < steps.count - 1 {
                    Rectangle()
                        .fill(done ? Color.indigo : Color(.systemGray4))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 14)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.4)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .shadow(radius: 4)
    }
}
