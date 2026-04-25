import SwiftUI

struct JobDiscoveryView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedJob: Job? = nil
    @State private var showNewSearch = false

    private var remainingJobs: [Job] {
        Array(vm.discoveryJobs.dropFirst(vm.currentJobIndex))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.discoveryJobs.isEmpty {
                    emptyState
                } else if vm.currentJobIndex >= vm.discoveryJobs.count {
                    allDoneState
                } else {
                    cardStack
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .top, spacing: 0) {
                JourneyStepBar(currentStep: 4)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        BalancePill()
                        Button {
                            withAnimation { vm.phase = .preferences }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .foregroundStyle(.indigo)
                    }
                }
            }
            .navigationDestination(item: $selectedJob) { job in
                JobDetailView(job: job)
            }
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressHeader

            // Stack of cards (top 3 visible for depth effect)
            ZStack {
                ForEach(cardIndices, id: \.self) { offset in
                    let index = vm.currentJobIndex + offset
                    if index < vm.discoveryJobs.count {
                        let job = vm.discoveryJobs[index]
                        if offset == 0 {
                            // Top card — fully interactive
                            SwipeableJobCardView(
                                job: job,
                                onSave: { vm.saveJob(job) },
                                onDismiss: { vm.dismissJob(job) }
                            )
                            .onTapGesture { selectedJob = job }
                            .zIndex(Double(3 - offset))
                            .task { await vm.fetchMatchScore(for: job) }
                        } else {
                            // Background cards — visual depth only
                            backgroundCard(offset: offset, job: job)
                                .zIndex(Double(3 - offset))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)

            // Hint text
            Text("Swipe right to save · Swipe left to pass · Tap for details")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
    }

    private var cardIndices: [Int] { [0, 1, 2] }

    private func backgroundCard(offset: Int, job: Job) -> some View {
        let scale = 1.0 - (Double(offset) * 0.04)
        let yOffset = CGFloat(offset) * 12
        return RoundedRectangle(cornerRadius: 24)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title).font(.headline).lineLimit(1)
                    Text(job.company).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .frame(height: 480)
            .scaleEffect(scale)
            .offset(y: yOffset)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(vm.currentJobIndex) reviewed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(vm.discoveryJobs.count - vm.currentJobIndex) remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            ProgressView(value: Double(vm.currentJobIndex), total: Double(vm.discoveryJobs.count))
                .tint(.indigo)
                .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Empty / Done States

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No jobs found")
                .font(.title2).bold()
            Text("Try adjusting your preferences or adding more job titles.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Update Preferences") {
                vm.phase = .preferences
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
    }

    private var allDoneState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.green.opacity(0.1)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }
            Text("You've seen all \(vm.discoveryJobs.count) jobs!")
                .font(.title2).bold()
            Text("You saved \(vm.savedJobs.count) job\(vm.savedJobs.count == 1 ? "" : "s"). Search again with updated preferences?")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button("Search Again") {
                    Task { await vm.startJobSearch() }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)

                Button("Update Preferences First") {
                    vm.phase = .preferences
                }
                .foregroundStyle(.indigo)
            }
            .padding(.horizontal, 32)
        }
    }
}
