import SwiftUI

struct ScorecardHoleMetricGrid: View {
    let score: HoleScore

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            ScorecardHoleMetricCard(title: "Par", value: "\(score.par)")
            ScorecardHoleMetricCard(title: "Yards", value: score.yardage.map { "\($0)" } ?? "—")
            ScorecardHoleMetricCard(title: "Handicap", value: score.handicap.map { "\($0)" } ?? "—")
        }
        .accessibilityElement(children: .contain)
    }
}
