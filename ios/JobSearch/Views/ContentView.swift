import SwiftUI

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
            JobDiscoveryView()
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
