import SwiftUI

struct ScorecardGridRowLabelColumn: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ScorecardGridMetrics.rowSpacing) {
            ScorecardGridRowLabelText(text: "Hole", height: ScorecardGridMetrics.holeHeaderHeight)
            ScorecardGridRowLabelText(text: "Score", height: ScorecardGridMetrics.scoreSquareSide)
            ScorecardGridRowLabelText(text: "Par", height: ScorecardGridMetrics.metricRowHeight)
            ScorecardGridRowLabelText(text: "Yds", height: ScorecardGridMetrics.metricRowHeight)
            ScorecardGridRowLabelText(text: "HCP", height: ScorecardGridMetrics.metricRowHeight)
        }
        .frame(width: ScorecardGridMetrics.labelColumnWidth, alignment: .leading)
        .accessibilityHidden(true)
    }
}
