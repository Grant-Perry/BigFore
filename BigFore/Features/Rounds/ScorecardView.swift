import SwiftData
import SwiftUI

struct ScorecardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ScorecardViewModel

    init(round: GolfRound) {
        _viewModel = State(initialValue: ScorecardViewModel(round: round))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                ScorecardRoundHeaderCard(round: viewModel.round)

                if let mapPoint = CourseMapPoint(round: viewModel.round) {
                    ScorecardGPSMapActionCard(
                        mapPoint: mapPoint,
                        round: viewModel.round
                    )
                }

                ScorecardHoleSectionCard(viewModel: viewModel) { holeNumber in
                    viewModel.selectHole(holeNumber, modelContext: modelContext)
                }

                ScorecardScoresSectionCard(viewModel: viewModel) {
                    viewModel.save(modelContext: modelContext)
                }

                ScorecardTotalsSectionCard(viewModel: viewModel)

                if let errorMessage = viewModel.errorMessage {
                    ScorecardErrorCard(message: errorMessage)
                }

                ScorecardNavigationControlsCard(
                    previousTitle: "Previous",
                    nextTitle: viewModel.advanceButtonTitle,
                    canMoveToPreviousHole: viewModel.canMoveToPreviousHole,
                    canAdvanceHole: viewModel.canAdvanceHole,
                    moveToPreviousHole: {
                        viewModel.moveToPreviousHole(modelContext: modelContext)
                    },
                    advanceOrFinish: {
                        viewModel.advanceOrFinish(modelContext: modelContext)
                    }
                )
            }
            .padding(BigForeDesign.Spacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.round.currentHole) { _, _ in
            viewModel.save(modelContext: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        Text("Scorecard")
    }
    .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
