import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showLoginSheet = false
    @State private var showResetConfirm = false
    @State private var showResumeDetail = false

    var body: some View {
        NavigationStack {
            List {
                // Resume section
                if let resume = vm.resume {
                    Section("Your Resume") {
                        Button {
                            showResumeDetail = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.indigo)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resume.fileName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    if let score = resume.analysis?.atsScore {
                                        Text("ATS Score: \(score)/100")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Button {
                            vm.phase = .resumeUpload
                        } label: {
                            Label("Replace Resume", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.indigo)
                        }
                    }
                }

                // Stats
                Section("Activity") {
                    LabeledContent("Jobs Discovered", value: "\(vm.discoveryJobs.count)")
                    LabeledContent("Jobs Saved", value: "\(vm.savedJobs.count)")
                    LabeledContent("Jobs Applied", value: "\(vm.savedJobs.filter { $0.isApplied }.count)")
                    LabeledContent("Jobs Passed", value: "\(vm.dismissedJobIds.count)")
                }

                // Preferences
                Section("Search Preferences") {
                    Button {
                        vm.phase = .preferences
                    } label: {
                        Label("Edit Preferences", systemImage: "slider.horizontal.3")
                            .foregroundStyle(.indigo)
                    }
                }

                // Agnic Account
                Section("Account") {
                    Button { showLoginSheet = true } label: {
                        HStack {
                            Label("Agnic Account", systemImage: "person.crop.circle")
                                .foregroundStyle(.primary)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(vm.auth.isLoggedIn ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(vm.auth.isLoggedIn ? "Connected" : "Not signed in")
                                    .font(.caption)
                                    .foregroundStyle(vm.auth.isLoggedIn ? .green : .red)
                            }
                        }
                    }
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                } footer: {
                    Text("This will clear your resume, saved jobs, and preferences.")
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showLoginSheet) {
                AgnicLoginSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showResumeDetail) {
                if vm.resume?.analysis != nil {
                    ResumeAnalysisView()
                        .presentationDetents([.large])
                }
            }
            .confirmationDialog("Reset All Data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset Everything", role: .destructive) {
                    vm.resetToOnboarding()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}

