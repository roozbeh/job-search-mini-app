import SwiftUI

/// Bottom sheet showing what's missing from the resume for a specific job,
/// and offering one-tap resume update suggestions.
struct ResumeGuidanceSheet: View {
    let job: Job
    let guidance: MatchGuidance
    @Binding var isPresented: Bool
    var onUpdateApproved: ((ResumeUpdate) -> Void)?

    @State private var approvedUpdates: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Match summary
                    summaryCard

                    // Skills comparison
                    skillsSection

                    // Resume updates
                    if !guidance.resumeUpdates.isEmpty {
                        resumeUpdatesSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Resume vs. Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 20) {
            MatchScoreBadge(score: guidance.matchScore, size: .large)
            VStack(alignment: .leading, spacing: 6) {
                Text(guidance.recommendation)
                    .font(.title3).bold()
                Text(guidance.overallSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !guidance.matchingSkills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("You have these", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.green)
                    FlowLayout(spacing: 8) {
                        ForEach(guidance.matchingSkills, id: \.self) { skill in
                            Text(skill)
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.green.opacity(0.12), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            if !guidance.missingSkills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("You're missing these", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    FlowLayout(spacing: 8) {
                        ForEach(guidance.missingSkills, id: \.self) { skill in
                            Text(skill)
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Resume Updates

    private var resumeUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Resume Updates")
                .font(.headline)
            Text("Approve changes to improve your match score for this role.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(guidance.resumeUpdates) { update in
                ResumeUpdateCard(
                    update: update,
                    isApproved: approvedUpdates.contains(update.id)
                ) {
                    approvedUpdates.insert(update.id)
                    onUpdateApproved?(update)
                }
            }
        }
    }
}

// MARK: - Resume Update Card

struct ResumeUpdateCard: View {
    let update: ResumeUpdate
    let isApproved: Bool
    let onApprove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(update.section, systemImage: "doc.text.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1), in: Capsule())
                Spacer()
                if isApproved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Suggested text
            Text(update.suggestedAddition)
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            // Reason
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                Text(update.reason).font(.caption).foregroundStyle(.secondary)
            }

            // Approve button
            if !isApproved {
                Button(action: onApprove) {
                    Label("Add to Resume", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.indigo, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark").foregroundStyle(.green)
                    Text("Added to resume").font(.subheadline).foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
