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
            Button(previousTitle, systemImage: "chevron.left", action: moveToPreviousHole)
                .buttonStyle(.bordered)
                .disabled(!canMoveToPreviousHole)
                .frame(maxWidth: .infinity, minHeight: 44)

            Button(nextTitle, systemImage: nextTitle == "Finish" ? "checkmark" : "chevron.right", action: advanceOrFinish)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .disabled(!canAdvanceHole)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(BigForeDesign.Spacing.medium)
        .scorecardCardBackground()
    }
}
