import SwiftUI

struct ScorecardErrorCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BigForeDesign.Spacing.large)
            .scorecardCardBackground()
            .accessibilityLabel("Scorecard error: \(message)")
    }
}
