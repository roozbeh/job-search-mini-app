import SwiftUI

struct JobDetailView: View {
    let job: Job
    @EnvironmentObject var vm: AppViewModel
    @State private var showResumeGuidance = false
    @State private var isFetchingGuidance = false
    @State private var localJob: Job

    init(job: Job) {
        self.job = job
        self._localJob = State(initialValue: job)
    }

    private var savedJob: SavedJob? { vm.savedJobs.first { $0.id == job.id } }
    private var isSaved: Bool { savedJob != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Header
                heroHeader

                Divider().padding(.horizontal)

                // Core details
                detailsSection

                Divider().padding(.horizontal)

                // Description
                if let description = localJob.description, !description.isEmpty {
                    descriptionSection(description)
                }

                // Match Analysis Card
                matchAnalysisSection

                Spacer(minLength: 100)
            }
        }
        .navigationTitle(localJob.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .task {
            // Fetch match score if not already available
            if localJob.matchGuidance == nil {
                isFetchingGuidance = true
                await vm.fetchMatchScore(for: localJob)
                // Refresh from vm
                if let updated = vm.discoveryJobs.first(where: { $0.id == localJob.id }) {
                    localJob = updated
                } else if let updated = vm.savedJobs.first(where: { $0.id == localJob.id })?.job {
                    localJob = updated
                }
                isFetchingGuidance = false
            }
        }
        .sheet(isPresented: $showResumeGuidance) {
            if let guidance = localJob.matchGuidance {
                ResumeGuidanceSheet(
                    job: localJob,
                    guidance: guidance,
                    isPresented: $showResumeGuidance
                ) { update in
                    vm.applyResumeUpdate(update, to: localJob.id)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(spacing: 16) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 72, height: 72)
                if let logo = localJob.companyLogo, let url = URL(string: logo) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Text(localJob.company.prefix(1))
                            .font(.largeTitle).bold().foregroundStyle(.indigo)
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(localJob.company.prefix(1))
                        .font(.largeTitle).bold().foregroundStyle(.indigo)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localJob.title)
                    .font(.title3).bold()
                    .lineLimit(2)
                Text(localJob.company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "location.fill").font(.caption2).foregroundStyle(.secondary)
                    Text(localJob.isRemote ? "Remote" : localJob.location)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Match badge
            if isFetchingGuidance {
                MatchScoreLoadingBadge(size: .medium)
            } else if let score = localJob.matchScore {
                MatchScoreBadge(score: score, size: .medium)
            }
        }
        .padding(20)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let salary = localJob.salary, !salary.isEmpty {
                DetailChip(icon: "dollarsign.circle.fill", label: "Salary", value: salary, color: .mint)
            }
            if let type = localJob.employmentType, !type.isEmpty {
                DetailChip(icon: "clock.fill", label: "Type", value: type, color: .blue)
            }
            if let date = localJob.postedDate, !date.isEmpty {
                DetailChip(icon: "calendar", label: "Posted", value: date, color: .purple)
            }
            DetailChip(
                icon: localJob.isRemote ? "house.fill" : "building.2.fill",
                label: "Work Style",
                value: localJob.isRemote ? "Remote" : "On-site",
                color: localJob.isRemote ? .green : .orange
            )
        }
        .padding(20)
    }

    // MARK: - Description

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Job Description")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Match Analysis Section

    @ViewBuilder
    private var matchAnalysisSection: some View {
        Divider().padding(.horizontal)
        VStack(alignment: .leading, spacing: 14) {
            Text("Resume Match Analysis")
                .font(.headline)

            if isFetchingGuidance {
                HStack {
                    ProgressView().tint(.indigo)
                    Text("Analyzing your resume against this job…")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            } else if let guidance = localJob.matchGuidance {
                // Quick skills summary
                if !guidance.matchingSkills.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("\(guidance.matchingSkills.count) matching skills")
                            .font(.subheadline)
                        Spacer()
                        Text(guidance.matchingSkills.prefix(3).joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if !guidance.missingSkills.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("\(guidance.missingSkills.count) missing skills")
                            .font(.subheadline)
                        Spacer()
                        Text(guidance.missingSkills.prefix(3).joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }

                Button {
                    showResumeGuidance = true
                } label: {
                    Label("See Full Analysis & Update Resume", systemImage: "sparkles")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.indigo)
                }
            } else {
                Text("Match analysis unavailable — no job description provided.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Save / Unsave toggle
            Button {
                if isSaved {
                    vm.removeSavedJob(savedJob!)
                } else {
                    vm.saveJob(localJob)
                }
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundStyle(isSaved ? .indigo : .secondary)
                    .frame(width: 52, height: 52)
                    .background(
                        isSaved ? Color.indigo.opacity(0.1) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }

            // Apply button
            if let urlString = localJob.applicationUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    Label("Apply Now", systemImage: "arrow.up.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    if let sj = savedJob { vm.markApplied(sj, applied: true) }
                })
            } else {
                Button {} label: {
                    Label("Apply Now", systemImage: "arrow.up.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.secondary)
                }
                .disabled(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Detail Chip

struct DetailChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption).fontWeight(.semibold).lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
