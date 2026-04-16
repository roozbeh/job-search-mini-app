import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showAPIKeySetup = false
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

                // API Configuration
                Section("Configuration") {
                    Button {
                        showAPIKeySetup = true
                    } label: {
                        HStack {
                            Label("API Key", systemImage: "key.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(vm.apiKey.isEmpty ? "Not set" : "••••••••")
                                .font(.caption)
                                .foregroundStyle(vm.apiKey.isEmpty ? .red : .green)
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
            .sheet(isPresented: $showAPIKeySetup) {
                APIKeySetupSheet()
                    .presentationDetents([.medium])
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

// MARK: - API Key Setup Sheet

struct APIKeySetupSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var tempKey = ""
    @State private var tempURL = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("AgnicPay API Key", text: $tempKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Get your API key from agnic.ai. This key is stored locally on your device only.")
                }

                Section {
                    TextField("Backend URL", text: $tempURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Backend URL")
                } footer: {
                    Text("Leave as default unless you're running your own backend.")
                }
            }
            .navigationTitle("API Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                tempKey = vm.apiKey
                tempURL = vm.backendURL
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.apiKey = tempKey
                        if !tempURL.isEmpty { vm.backendURL = tempURL }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
