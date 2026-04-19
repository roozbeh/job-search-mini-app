import SwiftUI
import UniformTypeIdentifiers

struct ResumeUploadView: View {
    @EnvironmentObject var vm: AppViewModel

    @State private var showFilePicker = false
    @State private var showTextEditor = false
    @State private var pastedText = ""
    @State private var isDragging = false
    @State private var showLoginSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.indigo)
                        Text("Upload Your Resume")
                            .font(.largeTitle).bold()
                        Text("PDF or plain text · We never store your resume on our servers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Login prompt if not signed in
                    if !vm.auth.isLoggedIn {
                        Button { showLoginSheet = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.crop.circle")
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sign in required")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text("Connect your Agnic account to analyze your resume")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    }

                    // Drop zone / tap to pick
                    Button {
                        guard vm.auth.isLoggedIn else { showLoginSheet = true; return }
                        showFilePicker = true
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: isDragging ? "arrow.down.doc.fill" : "icloud.and.arrow.up")
                                .font(.system(size: 44))
                                .foregroundStyle(isDragging ? .indigo : .secondary)
                            Text(isDragging ? "Drop it!" : "Tap to choose PDF or .txt")
                                .font(.headline)
                                .foregroundStyle(isDragging ? .indigo : .primary)
                            Text("Supports PDF, TXT, and plain text paste")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    isDragging ? Color.indigo : Color.secondary.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 2, dash: [8])
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isDragging ? Color.indigo.opacity(0.05) : Color(.secondarySystemBackground))
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .fileImporter(
                        isPresented: $showFilePicker,
                        allowedContentTypes: [.pdf, .plainText],
                        allowsMultipleSelection: false
                    ) { result in
                        handleFilePick(result)
                    }

                    // Divider
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                        Text("or").font(.subheadline).foregroundStyle(.secondary)
                        Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                    }.padding(.horizontal, 24)

                    // Paste option
                    Button {
                        guard vm.auth.isLoggedIn else { showLoginSheet = true; return }
                        showTextEditor = true
                    } label: {
                        Label("Paste Resume Text", systemImage: "doc.on.clipboard")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    // Privacy note
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                        Text("Your resume text is sent to OpenAI for analysis and is not stored by us. Review our privacy policy for details.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { vm.phase = .onboarding }
                        .foregroundStyle(.indigo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    UserIconButton(showLogin: $showLoginSheet)
                }
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            AgnicLoginSheet()
        }
        .sheet(isPresented: $showTextEditor) {
            PasteResumeSheet(text: $pastedText) {
                showTextEditor = false
                if !pastedText.isEmpty {
                    Task { await vm.processResumeText(pastedText) }
                }
            }
        }
    }

    // MARK: - File Handling

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let name = url.lastPathComponent
                Task { await vm.processResume(data: data, fileName: name) }
            } catch {
                vm.errorMessage = "Could not read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            vm.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Paste Sheet

struct PasteResumeSheet: View {
    @Binding var text: String
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Paste your resume here…")
                                .foregroundStyle(.tertiary)
                                .padding(28)
                                .allowsHitTesting(false)
                        }
                    }

                Text("\(text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
            }
            .navigationTitle("Paste Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onConfirm() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Analyze") {
                        onConfirm()
                    }
                    .disabled(text.count < 100)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
