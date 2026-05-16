import SwiftData
import SwiftUI

struct ScorecardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ScorecardViewModel

    init(round: GolfRound, focusedPlayerID: UUID? = nil) {
        _viewModel = State(initialValue: ScorecardViewModel(round: round, focusedPlayerID: focusedPlayerID))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                ScorecardRoundHeaderCard(round: viewModel.round)

                if let mapPoint = CourseMapPoint(round: viewModel.round) {
                    ScorecardGPSMapActionCard(
                        mapPoint: mapPoint,
                        round: viewModel.round,
                        focusedPlayerID: viewModel.focusedPlayerID
                    )
                }

                ScorecardHoleSectionCard(viewModel: viewModel) { holeNumber in
                    viewModel.selectHole(holeNumber, modelContext: modelContext)
                }
            }
            .padding(.horizontal, BigForeDesign.Spacing.large)
            .padding(.top, BigForeDesign.Spacing.large)
            .padding(.bottom, BigForeDesign.Spacing.medium)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                ScorecardScoresSectionCard(viewModel: viewModel, modelContext: modelContext) {
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
                .padding(.horizontal, BigForeDesign.Spacing.large)
                .padding(.bottom, BigForeDesign.Spacing.large)
            }
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
    .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
