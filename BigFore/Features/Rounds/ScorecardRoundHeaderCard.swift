import SwiftUI

struct ScorecardRoundHeaderCard: View {
    let round: GolfRound

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text(round.courseName)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("\(round.clubName) · \(round.teeName) \(round.teeGender.capitalized)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(round.scoringMode.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
        .accessibilityElement(children: .combine)
    }
}
