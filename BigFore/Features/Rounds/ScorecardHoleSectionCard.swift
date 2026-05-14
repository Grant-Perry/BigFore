import SwiftUI

struct ScorecardHoleSectionCard: View {
    let viewModel: ScorecardViewModel
    let selectHole: (Int) -> Void
    @State private var selectedNine: ScorecardNine = .front

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scorecard")
                    .font(.headline)

                Spacer()

                Text("Showing \(viewModel.primaryPlayerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ScorecardNinePageControl(
                nines: viewModel.scorecardNines,
                selectedNine: $selectedNine
            )

            TabView(selection: $selectedNine) {
                ForEach(viewModel.scorecardNines) { nine in
                    ScorecardNineGridPage(
                        nine: nine,
                        viewModel: viewModel,
                        selectHole: selectHole
                    )
                    .tag(nine)
                }
            }
            .frame(height: 126)
            .tabViewStyle(.page(indexDisplayMode: .never))

            Text("Swipe between nines. Tap a hole column to edit that hole.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
        .onAppear(perform: syncSelectedNine)
        .onChange(of: viewModel.round.currentHole) { _, _ in
            syncSelectedNine()
        }
    }

    private func syncSelectedNine() {
        selectedNine = ScorecardNine.containing(viewModel.round.currentHole)
    }
}
