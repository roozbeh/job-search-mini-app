import SwiftUI

// MARK: - SwipeableJobCardView

/// A single job card that can be dragged left (dismiss) or right (save).
/// Shows company, title, location, salary, employment type, match score,
/// and a snippet of the job description.
struct SwipeableJobCardView: View {
    let job: Job
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var rotation: Double = 0

    // Thresholds
    private let swipeThreshold: CGFloat = 100
    private let rotationFactor: Double  = 0.04

    // Computed drag state
    private var dragProgress: CGFloat { dragOffset.width / swipeThreshold }
    private var isSaving:    Bool { dragOffset.width > 50 }
    private var isDismissing: Bool { dragOffset.width < -50 }

    var body: some View {
        ZStack {
            // Card
            cardBody
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width) * rotationFactor))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            handleSwipeEnd(translation: value.translation)
                        }
                )
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: dragOffset)

            // Left action indicator (Dismiss)
            HStack {
                actionLabel(text: "Pass", icon: "xmark", color: .red)
                    .opacity(isDismissing ? min(abs(dragProgress), 1.0) : 0)
                Spacer()
            }
            .padding(.leading, 24)
            .allowsHitTesting(false)

            // Right action indicator (Save)
            HStack {
                Spacer()
                actionLabel(text: "Save", icon: "bookmark.fill", color: .green)
                    .opacity(isSaving ? min(dragProgress, 1.0) : 0)
            }
            .padding(.trailing, 24)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Card Body

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: company logo + name
            cardHeader

            Divider().padding(.horizontal)

            // Core info
            cardDetails
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Description snippet
            if let description = job.description, !description.isEmpty {
                Text(description)
                    .lineLimit(4)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            Spacer()

            // Action buttons
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
    }

    private var cardHeader: some View {
        HStack(spacing: 14) {
            // Company logo placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 56, height: 56)
                if let logo = job.companyLogo, let url = URL(string: logo) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Text(job.company.prefix(1))
                            .font(.title2).bold()
                            .foregroundStyle(.indigo)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(job.company.prefix(1))
                        .font(.title2).bold()
                        .foregroundStyle(.indigo)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(job.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(job.company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Match score
            matchScoreView
        }
        .padding(20)
    }

    @ViewBuilder
    private var matchScoreView: some View {
        if let score = job.matchScore {
            MatchScoreBadge(score: score, size: .medium)
        } else {
            MatchScoreLoadingBadge(size: .medium)
        }
    }

    private var cardDetails: some View {
        HStack(spacing: 0) {
            JobPill(icon: "location.fill",
                    text: job.isRemote ? "Remote" : job.location,
                    color: job.isRemote ? .green : .secondary)
            if let salary = job.salary, !salary.isEmpty {
                JobPill(icon: "dollarsign.circle.fill", text: salary, color: .mint)
            }
            if let type = job.employmentType, !type.isEmpty {
                JobPill(icon: "clock.fill", text: type, color: .blue)
            }
        }
        .padding(.horizontal, -4)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Dismiss
            Button(action: animatedDismiss) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                    .frame(width: 60, height: 60)
                    .background(Color.red.opacity(0.1), in: Circle())
            }

            Spacer()

            // More info (navigates to detail — handled by parent)
            Button {} label: {
                Text("View Details")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.indigo.opacity(0.1), in: Capsule())
            }

            Spacer()

            // Save
            Button(action: animatedSave) {
                Image(systemName: "bookmark.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.indigo, in: Circle())
            }
        }
    }

    // MARK: - Action Label

    private func actionLabel(text: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title)
            Text(text)
                .font(.headline)
        }
        .foregroundStyle(color)
        .padding(16)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Swipe Logic

    private func handleSwipeEnd(translation: CGSize) {
        if translation.width > swipeThreshold {
            animatedSave()
        } else if translation.width < -swipeThreshold {
            animatedDismiss()
        } else {
            // Snap back
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
        }
    }

    private func animatedSave() {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: 600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onSave()
            dragOffset = .zero
        }
    }

    private func animatedDismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
            dragOffset = .zero
        }
    }
}

// MARK: - JobPill

struct JobPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption).lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: Capsule())
        .padding(4)
    }
}
