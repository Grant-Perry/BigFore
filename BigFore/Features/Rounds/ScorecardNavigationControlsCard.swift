import SwiftUI

struct ScorecardNavigationControlsCard: View {
    let previousTitle: String
    let nextTitle: String
    let canMoveToPreviousHole: Bool
    let canAdvanceHole: Bool
    let moveToPreviousHole: () -> Void
    let advanceOrFinish: () -> Void

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.medium) {
            Button(action: moveToPreviousHole) {
                Label(previousTitle, systemImage: "chevron.left")
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            .disabled(!canMoveToPreviousHole)

            Button(action: advanceOrFinish) {
                Label(nextTitle, systemImage: nextTitle == "Finish" ? "checkmark" : "chevron.right")
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(BigForePillButtonStyle.bigForePrimary)
            .disabled(!canAdvanceHole)
        }
        .padding(BigForeDesign.Spacing.medium)
        .scorecardCardBackground()
    }
}
