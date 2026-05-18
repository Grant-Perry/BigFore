import SwiftUI

struct ScorecardLandscapeScorecardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let round: GolfRound
    @Binding var showsAllPlayers: Bool
    @Binding var showsMetrics: Bool

    var body: some View {
        VStack(spacing: BigForeDesign.Spacing.small) {
            HStack(alignment: .center, spacing: BigForeDesign.Spacing.medium) {
                Picker("Scorecard Players", selection: $showsAllPlayers) {
                    Text("Just Me").tag(false)
                    Text("All Players").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                HStack(spacing: 6) {
                    Text("Metrics")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button {
                        showsMetrics.toggle()
                    } label: {
                        Text(showsMetrics ? "On" : "Off")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeToggle(isSelected: showsMetrics))
                    .controlSize(.mini)
                    .accessibilityLabel("Metrics")
                    .accessibilityValue(showsMetrics ? "On" : "Off")
                    .accessibilityHint("Toggles distance, handicap, putts, tee result, and GIR rows on the shared scorecard.")
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal)

            ScrollView(.vertical) {
                ScrollView(.horizontal) {
                    FullScorecardShareView(round: round, showsAllPlayers: showsAllPlayers, showsMetrics: showsMetrics)
                        .frame(minWidth: 1_120, alignment: .topLeading)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .scrollContentBackground(.hidden)
        }
        .scorecardScreenBackground(colorScheme: colorScheme)
    }
}
