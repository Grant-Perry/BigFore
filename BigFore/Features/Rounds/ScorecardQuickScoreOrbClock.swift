import SwiftUI

/// Shared quick-score UI: gradient circular orbs on a clock ring (used from hole grid and player row).
struct ScorecardQuickScoreOrbClockPicker: View {
    let title: String
    let score: HoleScore
    let onPick: (ScorecardQuickScoreOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            Text(title)
                .font(.headline)

            GeometryReader { proxy in
                let rect = CGRect(origin: .zero, size: proxy.size)
                let orbRadius = QuickScoreOrbMetrics.diameter / 2
                let fit = min(rect.width, rect.height)
                let orbitRadius = max(fit / 2 - orbRadius - QuickScoreOrbMetrics.clockRingPadding, orbRadius * 1.15)
                let n = CGFloat(ScorecardQuickScoreOption.clockwiseClockOrder.count)
                let innerVoidRadius = max(orbitRadius * cos(.pi / n) - orbRadius, 12)
                let hubSide = min(innerVoidRadius * CGFloat(2).squareRoot() * 0.94, fit * 0.5)
                ZStack {
                    centerScoreHub(side: hubSide)
                        .position(x: rect.midX, y: rect.midY)

                    ForEach(Array(ScorecardQuickScoreOption.clockwiseClockOrder.enumerated()), id: \.element.id) { index, option in
                        quickScoreOrbButton(option: option)
                            .position(
                                quickScoreClockPosition(
                                    index: index,
                                    count: ScorecardQuickScoreOption.clockwiseClockOrder.count,
                                    orbitRadius: orbitRadius,
                                    in: rect
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: QuickScoreOrbMetrics.clockBoardSize, height: QuickScoreOrbMetrics.clockBoardSize)
        }
        .padding(BigForeDesign.Spacing.medium)
        .frame(width: QuickScoreOrbMetrics.popoverWidth)
    }

    private func quickScoreClockPosition(index: Int, count: Int, orbitRadius: CGFloat, in rect: CGRect) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let step = 2 * CGFloat.pi / CGFloat(count)
        let angle = -CGFloat.pi / 2 + CGFloat(index) * step
        return CGPoint(
            x: center.x + cos(angle) * orbitRadius,
            y: center.y + sin(angle) * orbitRadius
        )
    }

    /// Matches the player-row **Score** drag square: rounded rect, stroke, soft fill, “Score” caption.
    private func centerScoreHub(side: CGFloat) -> some View {
        let corner = max(8, side * (10 / 44))
        let digitSize = max(18, min(side * 0.34, 44))
        return ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.38), lineWidth: 1)
                .background {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }

            VStack(spacing: max(2, side * 0.04)) {
                Text(score.strokes == 0 ? "—" : "\(score.strokes)")
                    .font(.system(size: digitSize, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)

                Text("Score")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, side * 0.1)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current score")
        .accessibilityValue(score.strokes == 0 ? "Not scored" : "\(score.strokes)")
    }

    private func quickScoreOrbButton(option: ScorecardQuickScoreOption) -> some View {
        let strokes = max(score.par + option.relativeToPar, 1)
        return Button {
            onPick(option)
        } label: {
            ZStack {
                Circle()
                    .fill(option.fillGradient)
                VStack(spacing: 2) {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 11, weight: .bold))
                    Text(option.title)
                        .font(.system(size: 8, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text("\(strokes)")
                        .font(.system(size: 18, weight: .black))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 1)
            }
            .frame(width: QuickScoreOrbMetrics.diameter, height: QuickScoreOrbMetrics.diameter)
            .contentShape(Circle())
        }
        .buttonStyle(QuickScoreOrbButtonStyle(glowTint: option.color))
        .accessibilityLabel("\(option.title), \(strokes) strokes")
    }
}

// MARK: - Metrics & press chrome

private enum QuickScoreOrbMetrics {
    static let diameter: CGFloat = 72
    static let clockRingPadding: CGFloat = 10
    static let clockBoardSize: CGFloat = 300
    static var popoverWidth: CGFloat { BigForeDesign.Spacing.medium * 2 + clockBoardSize }
}

private struct QuickScoreOrbButtonStyle: ButtonStyle {
    let glowTint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .compositingGroup()
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
            .shadow(color: .black.opacity(0.42), radius: configuration.isPressed ? 4 : 9, x: 0, y: configuration.isPressed ? 2 : 5)
            .shadow(color: glowTint.opacity(configuration.isPressed ? 0.92 : 0.42), radius: configuration.isPressed ? 22 : 10, x: 0, y: 0)
            .overlay {
                Circle()
                    .strokeBorder(
                        Color.white.opacity(configuration.isPressed ? 0.75 : 0.22),
                        lineWidth: configuration.isPressed ? 2.5 : 1
                    )
                    .padding(1)
            }
    }
}
