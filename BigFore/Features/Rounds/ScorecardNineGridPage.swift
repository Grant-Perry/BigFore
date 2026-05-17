import SwiftUI

struct ScorecardNineGridPage: View {
    let nine: ScorecardNine
    let viewModel: ScorecardViewModel
    @Binding var gridShowsStrokes: Bool
    let stackedHoleNumbers: Set<Int>
    let selectHole: (Int) -> Void
    let showQuickScore: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ScorecardGridMetrics.columnSpacing) {
            ScorecardGridRowLabelColumn()

            ForEach(nine.holeNumbers, id: \.self) { holeNumber in
                let display = viewModel.primaryHoleSquareDisplay(forHoleNumber: holeNumber, showStrokes: gridShowsStrokes)
                ScorecardHoleScoreColumn(
                    holeNumber: holeNumber,
                    score: viewModel.primaryScore(forHoleNumber: holeNumber),
                    squareText: display.text,
                    result: display.result,
                    relativeText: viewModel.relativeScoreText(forHoleNumber: holeNumber),
                    isSelected: viewModel.round.currentHole == holeNumber,
                    isStackSelected: stackedHoleNumbers.contains(holeNumber),
                    accessibilityText: viewModel.scoreStatusAccessibilityText(forHoleNumber: holeNumber),
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
                accessibilityRelativeSummary: summary.relativeToPar.map { viewModel.relativeText($0) }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BigForeDesign.Spacing.xSmall)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(nine.title) scorecard")
    }

    private var summary: ScorecardNineSummary {
        viewModel.nineSummary(for: nine)
    }

    private var totalDisplay: (text: String, result: ScorecardScoreResult?) {
        viewModel.nineTotalSquareDisplay(for: nine, showStrokes: gridShowsStrokes)
    }
}
