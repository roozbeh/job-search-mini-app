import SwiftUI

/// Circular badge showing the match percentage between resume and a job.
/// Used on job cards and in the detail view.
struct MatchScoreBadge: View {
    let score: Int
    var size: BadgeSize = .medium
    var showLabel: Bool = true

    enum BadgeSize {
        case small, medium, large
        var diameter: CGFloat  { switch self { case .small: 44; case .medium: 64; case .large: 88 } }
        var lineWidth: CGFloat { switch self { case .small: 4;  case .medium: 6;  case .large: 8  } }
        var fontSize: CGFloat  { switch self { case .small: 13; case .medium: 18; case .large: 26 } }
    }

    private var color: Color {
        switch score {
        case 80...: return .green
        case 60...: return .orange
        case 40...: return .yellow
        default:    return .red
        }
    }

    private var label: String {
        switch score {
        case 80...: return "Great fit"
        case 60...: return "Good fit"
        case 40...: return "Partial fit"
        default:    return "Stretch"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: size.lineWidth)
                    .frame(width: size.diameter, height: size.diameter)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round))
                    .frame(width: size.diameter, height: size.diameter)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: score)

                Text("\(score)%")
                    .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            if showLabel && size != .small {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(color)
                    .fontWeight(.medium)
            }
        }
    }
}

/// Shown while match score is being computed.
struct MatchScoreLoadingBadge: View {
    var size: MatchScoreBadge.BadgeSize = .medium
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15),
                        lineWidth: size.lineWidth)
                .frame(width: size.diameter, height: size.diameter)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Color.secondary.opacity(0.5),
                        style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round))
                .frame(width: size.diameter, height: size.diameter)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }

    private var lineWidth: CGFloat { size.lineWidth }
    private var diameter: CGFloat  { size.diameter  }
}

#Preview {
    HStack(spacing: 24) {
        MatchScoreBadge(score: 87, size: .small, showLabel: false)
        MatchScoreBadge(score: 72, size: .medium)
        MatchScoreBadge(score: 45, size: .large)
        MatchScoreLoadingBadge(size: .medium)
    }
    .padding()
}
