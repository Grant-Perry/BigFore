import SwiftUI

struct ScorecardGPSMapActionCard: View {
    let mapPoint: CourseMapPoint
    let round: GolfRound
    let focusedPlayerID: UUID?

    var body: some View {
        NavigationLink {
            CourseMapView(
                course: mapPoint,
                currentHoleNumber: round.currentHole,
                round: round,
                focusedPlayerID: focusedPlayerID
            )
        } label: {
            HStack(spacing: BigForeDesign.Spacing.medium) {
                Label("GPS Map", systemImage: "location.viewfinder")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("Hole \(round.currentHole)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, BigForeDesign.Spacing.large)
            .background(
                BigForeDesign.Gradients.softFill(for: BigForeDesign.Palette.primaryAction),
                in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                    .stroke(BigForeDesign.Palette.primaryAction.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open GPS map")
        .accessibilityValue("Hole \(round.currentHole)")
        .accessibilityHint("Opens the GPS map for the current round.")
    }
}
