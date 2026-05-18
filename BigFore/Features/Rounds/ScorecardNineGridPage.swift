import SwiftUI

struct ScorecardNineGridPage: View {
    let nine: ScorecardNine
    let scorecardViewModel: ScorecardViewModel
    @Binding var gridShowsStrokes: Bool
    let stackedHoleNumbers: Set<Int>
    let selectHole: (Int) -> Void
    let showQuickScore: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ScorecardGridMetrics.columnSpacing) {
            ScorecardGridRowLabelColumn()

            ForEach(nine.holeNumbers, id: \.self) { holeNumber in
                let display = scorecardViewModel.primaryHoleSquareDisplay(forHoleNumber: holeNumber, showStrokes: gridShowsStrokes)
                ScorecardHoleScoreColumn(
                    holeNumber: holeNumber,
                    score: scorecardViewModel.primaryScore(forHoleNumber: holeNumber),
                    squareText: display.text,
                    result: display.result,
                    relativeText: scorecardViewModel.relativeScoreText(forHoleNumber: holeNumber),
                    isSelected: scorecardViewModel.round.currentHole == holeNumber,
                    isStackSelected: stackedHoleNumbers.contains(holeNumber),
                    accessibilityText: scorecardViewModel.scoreStatusAccessibilityText(forHoleNumber: holeNumber),
                    showQuickScore: {
                        showQuickScore(holeNumber)
                    }
                ) {
                    selectHole(holeNumber)
                }
            }

            ScorecardNineTotalColumn(
                title: nine.totalTitle,
                summary: summary,
                squareText: totalDisplay.text,
                squareResult: totalDisplay.result,
                accessibilityRelativeSummary: summary.relativeToPar.map { scorecardViewModel.relativeText($0) }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BigForeDesign.Spacing.xSmall)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(nine.title) scorecard")
    }

    private var summary: ScorecardNineSummary {
        scorecardViewModel.nineSummary(for: nine)
    }

    private var totalDisplay: (text: String, result: ScorecardScoreResult?) {
        scorecardViewModel.nineTotalSquareDisplay(for: nine, showStrokes: gridShowsStrokes)
    }
}
