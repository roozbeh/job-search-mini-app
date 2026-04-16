import SwiftUI

struct ResumeAnalysisView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedTab: AnalysisTab = .overview

    enum AnalysisTab: String, CaseIterable {
        case overview = "Overview"
        case improvements = "Improve"
        case sections = "Sections"
    }

    var analysis: ResumeAnalysis? { vm.resume?.analysis }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ATS Score Card
                    if let analysis = analysis {
                        ATSScoreCard(score: analysis.atsScore, summary: analysis.summary)
                    }

                    // Tab picker
                    Picker("", selection: $selectedTab) {
                        ForEach(AnalysisTab.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Tab content
                    if let analysis = analysis {
                        switch selectedTab {
                        case .overview:
                            OverviewTab(criteria: analysis.extractedCriteria)
                        case .improvements:
                            ImprovementsTab(improvements: analysis.improvements)
                        case .sections:
                            SectionsTab(feedback: analysis.sectionFeedback)
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.vertical)
            }
            .navigationTitle("Resume Analysis")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Re-upload") {
                        vm.phase = .resumeUpload
                    }
                    .foregroundStyle(.indigo)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    withAnimation { vm.phase = .preferences }
                } label: {
                    Label("Set Job Preferences", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - ATS Score Card

struct ATSScoreCard: View {
    let score: Int
    let summary: String

    private var scoreColor: Color {
        switch score {
        case 80...: return .green
        case 60...: return .orange
        default:    return .red
        }
    }

    private var scoreLabel: String {
        switch score {
        case 80...: return "Strong"
        case 60...: return "Needs Work"
        default:    return "At Risk"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Circular score gauge
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                    .frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1, dampingFraction: 0.7), value: score)

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text("ATS Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                Text(scoreLabel)
                    .font(.title3).bold()
                    .foregroundStyle(scoreColor)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let criteria: ExtractedCriteria

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CriteriaRow(label: "Target Roles", values: criteria.jobTitles)
            CriteriaRow(label: "Top Skills", values: criteria.skills.prefix(8).map(String.init))
            CriteriaRow(label: "Industries", values: criteria.industries)
            CriteriaRow(label: "Preferred Locations", values: criteria.preferredLocations)

            HStack {
                InfoPill(label: "Experience", value: "\(criteria.yearsOfExperience) yrs",
                         icon: "briefcase.fill", color: .blue)
                InfoPill(label: "Remote", value: criteria.isRemotePreferred ? "Preferred" : "Open",
                         icon: "house.fill", color: criteria.isRemotePreferred ? .green : .secondary)
            }

            if let min = criteria.salaryRange.min, let max = criteria.salaryRange.max {
                InfoPill(label: "Target Salary", value: criteria.salaryRange.displayString,
                         icon: "dollarsign.circle.fill", color: .mint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}

struct CriteriaRow: View {
    let label: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            FlowLayout(spacing: 8) {
                ForEach(values, id: \.self) { v in
                    Text(v)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.indigo.opacity(0.1), in: Capsule())
                        .foregroundStyle(.indigo)
                }
            }
        }
    }
}

struct InfoPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption).fontWeight(.semibold)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Improvements Tab

struct ImprovementsTab: View {
    let improvements: [Improvement]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(improvements) { item in
                ImprovementCard(item: item)
            }
        }
        .padding(.horizontal)
    }
}

struct ImprovementCard: View {
    let item: Improvement

    private var priorityColor: Color {
        switch item.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.priority.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(priorityColor)
                Spacer()
            }
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Sections Tab

struct SectionsTab: View {
    let feedback: [SectionFeedback]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(feedback) { item in
                SectionFeedbackCard(item: item)
            }
        }
        .padding(.horizontal)
    }
}

struct SectionFeedbackCard: View {
    let item: SectionFeedback
    @State private var expanded = false

    private var statusColor: Color {
        switch item.status {
        case .success: return .green
        case .warning: return .orange
        case .error:   return .red
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon).foregroundStyle(statusColor)
                Text(item.section).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Text(item.message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if expanded && !item.suggestions.isEmpty {
                Divider()
                ForEach(item.suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.indigo)
                        Text(suggestion).font(.caption).foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .onTapGesture { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }
    }
}

// MARK: - FlowLayout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for view in row.views {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var views: [LayoutSubview] = []
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !current.views.isEmpty {
                rows.append(current)
                current = Row()
                x = 0
            }
            current.views.append(view)
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.views.isEmpty { rows.append(current) }
        return rows
    }
}
