import SwiftUI

struct SavedJobsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var filter: SavedFilter = .all
    @State private var searchText = ""

    enum SavedFilter: String, CaseIterable {
        case all = "All"
        case pending = "To Apply"
        case applied = "Applied"
    }

    private var filteredJobs: [SavedJob] {
        let base: [SavedJob]
        switch filter {
        case .all:     base = vm.savedJobs
        case .pending: base = vm.savedJobs.filter { !$0.isApplied }
        case .applied: base = vm.savedJobs.filter { $0.isApplied }
        }
        if searchText.isEmpty { return base }
        return base.filter {
            $0.job.title.localizedCaseInsensitiveContains(searchText) ||
            $0.job.company.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.savedJobs.isEmpty {
                    emptyState
                } else {
                    jobList
                }
            }
            .navigationTitle("Saved Jobs")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search saved jobs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(SavedFilter.allCases, id: \.self) { f in
                            Button(f.rawValue) { filter = f }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .foregroundStyle(.indigo)
                }
            }
        }
    }

    // MARK: - Job List

    private var jobList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SavedFilter.allCases, id: \.self) { f in
                            FilterPill(
                                label: f.rawValue,
                                count: countFor(f),
                                isSelected: filter == f
                            ) { filter = f }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                // Summary stats
                statsBar

                // Job cards
                LazyVStack(spacing: 12) {
                    ForEach(filteredJobs) { savedJob in
                        NavigationLink(destination: JobDetailView(job: savedJob.job)) {
                            SavedJobRow(savedJob: savedJob)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                vm.removeSavedJob(savedJob)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                vm.markApplied(savedJob, applied: !savedJob.isApplied)
                            } label: {
                                Label(
                                    savedJob.isApplied ? "Unapply" : "Mark Applied",
                                    systemImage: savedJob.isApplied ? "arrow.uturn.left" : "checkmark"
                                )
                            }
                            .tint(savedJob.isApplied ? .orange : .green)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            StatCell(value: vm.savedJobs.count, label: "Saved", color: .indigo)
            Divider().frame(height: 32)
            StatCell(value: vm.savedJobs.filter { $0.isApplied }.count, label: "Applied", color: .green)
            Divider().frame(height: 32)
            StatCell(value: vm.savedJobs.filter { !$0.isApplied }.count, label: "Pending", color: .orange)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No saved jobs yet")
                .font(.title2).bold()
            Text("Swipe right on jobs in Discover to save them here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func countFor(_ f: SavedFilter) -> Int {
        switch f {
        case .all:     return vm.savedJobs.count
        case .pending: return vm.savedJobs.filter { !$0.isApplied }.count
        case .applied: return vm.savedJobs.filter { $0.isApplied }.count
        }
    }
}

// MARK: - Saved Job Row

struct SavedJobRow: View {
    let savedJob: SavedJob

    var body: some View {
        HStack(spacing: 14) {
            // Company initial
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 52, height: 52)
                Text(savedJob.job.company.prefix(1))
                    .font(.title3).bold().foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(savedJob.job.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Text(savedJob.job.company)
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(savedJob.job.isRemote ? "Remote" : savedJob.job.location)
                        .font(.caption2).foregroundStyle(.secondary)
                    if savedJob.isApplied {
                        Label("Applied", systemImage: "checkmark.circle.fill")
                            .font(.caption2).foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            // Match score
            if let score = savedJob.job.matchScore {
                MatchScoreBadge(score: score, size: .small, showLabel: false)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label).font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.15), in: Capsule())
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? Color.indigo : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct StatCell: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2).bold()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
