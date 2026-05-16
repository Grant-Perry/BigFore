import SwiftUI

struct ScorecardLandscapeScorecardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let round: GolfRound
    @Binding var showsAllPlayers: Bool
    @Binding var showsMetrics: Bool

    var body: some View {
        VStack(spacing: BigForeDesign.Spacing.small) {
            HStack(spacing: BigForeDesign.Spacing.medium) {
                Picker("Scorecard Players", selection: $showsAllPlayers) {
                    Text("Me").tag(false)
                    Text("All Players").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                Toggle("Metrics", isOn: $showsMetrics)
                    .font(.subheadline.weight(.semibold))
                    .toggleStyle(.switch)
                    .fixedSize()
            }
            .padding(.horizontal)

            ScrollView([.horizontal, .vertical]) {
                FullScorecardShareView(round: round, showsAllPlayers: showsAllPlayers, showsMetrics: showsMetrics)
                    .frame(minWidth: 1_120)
                    .padding()
            }
        }
        .scorecardScreenBackground(colorScheme: colorScheme)
    }
}
