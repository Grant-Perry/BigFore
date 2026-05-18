import SwiftUI

struct ScorecardRoundHeaderCard: View {
    let round: GolfRound
    var showsCompleteRoundButton: Bool
    let onCompleteRoundTapped: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: BigForeDesign.Spacing.medium) {
            Text(round.courseName)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsCompleteRoundButton {
                Button(action: onCompleteRoundTapped) {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.gpGreen)
                            .shadow(color: .gpGreen.opacity(0.35), radius: 6, y: 0)
                        Text("Complete")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 48, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete round")
                .accessibilityHint("Asks you to confirm after checking the scorecard is ready to finish.")
            }
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
    }
}
