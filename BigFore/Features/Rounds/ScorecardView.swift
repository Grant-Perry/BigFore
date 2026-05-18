import SwiftData
import SwiftUI

struct ScorecardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var scorecardViewModel: ScorecardViewModel
    @State private var isShareSheetPresented = false
    @State private var landscapeShowsAllPlayers = false
    @State private var landscapeShowsMetrics = true
    @State private var isCompleteRoundDialogPresented = false
    @State private var completeRoundAssessmentSnapshot: ScorecardViewModel.RoundCompletionAssessment?

    init(round: GolfRound, focusedPlayerID: UUID? = nil) {
        _scorecardViewModel = State(initialValue: ScorecardViewModel(round: round, focusedPlayerID: focusedPlayerID))
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                ScorecardLandscapeScorecardView(
                    round: scorecardViewModel.round,
                    showsAllPlayers: $landscapeShowsAllPlayers,
                    showsMetrics: $landscapeShowsMetrics
                )
            } else {
                @Bindable var scorecardViewModel = scorecardViewModel
                VStack(spacing: BigForeDesign.Spacing.medium) {
                    ScorecardRoundHeaderCard(
                        round: scorecardViewModel.round,
                        showsCompleteRoundButton: !scorecardViewModel.round.isComplete,
                        onCompleteRoundTapped: {
                            completeRoundAssessmentSnapshot = scorecardViewModel.roundCompletionAssessment()
                            isCompleteRoundDialogPresented = true
                        }
                    )
                    .padding(.horizontal, BigForeDesign.Spacing.large)
                    .padding(.top, BigForeDesign.Spacing.medium)

                    ScorecardHoleSectionCard(
                        viewModel: scorecardViewModel,
                        selectHole: { holeNumber in
                            scorecardViewModel.selectHole(holeNumber, modelContext: modelContext)
                        },
                        setQuickScore: { holeNumbers, relativeToPar in
                            scorecardViewModel.setPrimaryScoreRelativeToPar(relativeToPar, forHoleNumbers: holeNumbers, modelContext: modelContext)
                        },
                        onTeeSelected: { tee in
                            scorecardViewModel.applySavedTee(tee, modelContext: modelContext)
                        }
                    )
                    .padding(.horizontal, BigForeDesign.Spacing.large)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                            ScorecardScoresSectionCard(viewModel: scorecardViewModel, modelContext: modelContext) {
                                scorecardViewModel.save(modelContext: modelContext)
                            }

                            ScorecardTotalsSectionCard(viewModel: scorecardViewModel)

                            if let errorMessage = scorecardViewModel.errorMessage {
                                ScorecardErrorCard(message: errorMessage)
                            }

                            ScorecardNavigationControlsCard(
                                previousTitle: scorecardViewModel.previousTeeBoxButtonTitle,
                                nextTitle: scorecardViewModel.advanceButtonTitle,
                                canMoveToPreviousHole: scorecardViewModel.canMoveToPreviousHole,
                                canAdvanceHole: scorecardViewModel.canAdvanceHole,
                                moveToPreviousHole: {
                                    scorecardViewModel.moveToPreviousHole(modelContext: modelContext)
                                },
                                advanceOrFinish: {
                                    scorecardViewModel.advanceOrFinish(modelContext: modelContext)
                                }
                            )
                        }
                        .padding(.horizontal, BigForeDesign.Spacing.large)
                        .padding(.top, BigForeDesign.Spacing.small)
                        .padding(.bottom, BigForeDesign.Spacing.large + 52)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .scorecardScreenBackground(colorScheme: colorScheme)
        .confirmationDialog(
            "Complete this round?",
            isPresented: $isCompleteRoundDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) {
                completeRoundAssessmentSnapshot = nil
            }
            if let assessment = completeRoundAssessmentSnapshot {
                if assessment.isReadyToComplete {
                    Button("Complete round") {
                        scorecardViewModel.markRoundComplete(modelContext: modelContext)
                        completeRoundAssessmentSnapshot = nil
                    }
                } else {
                    Button("Complete anyway", role: .destructive) {
                        scorecardViewModel.markRoundComplete(modelContext: modelContext)
                        completeRoundAssessmentSnapshot = nil
                    }
                }
            }
        } message: {
            if let assessment = completeRoundAssessmentSnapshot {
                Text(scorecardViewModel.completeRoundConfirmationMessage(assessment: assessment))
            }
        }
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            if scorecardViewModel.round.isComplete {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        RoundRecapView(round: scorecardViewModel.round)
                    } label: {
                        Label("Round recap", systemImage: "map")
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        scorecardViewModel.save(modelContext: modelContext)
                        isShareSheetPresented = true
                    } label: {
                        Label("Share Scorecard", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Share scorecard")

                    if let mapPoint = CourseMapPoint(round: scorecardViewModel.round) {
                        NavigationLink {
                            CourseMapView(
                                course: mapPoint,
                                currentHoleNumber: scorecardViewModel.round.currentHole,
                                round: scorecardViewModel.round,
                                focusedPlayerID: scorecardViewModel.focusedPlayerID
                            )
                        } label: {
                            Label("GPS Map", systemImage: "location.viewfinder")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityLabel("Open GPS map")
                        .accessibilityValue("Hole \(scorecardViewModel.round.currentHole)")
                        .accessibilityHint("Opens the GPS map for the current round.")
                    }
                }
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ScorecardShareSheet(
                round: scorecardViewModel.round,
                showsAllPlayers: landscapeShowsAllPlayers,
                showsMetrics: landscapeShowsMetrics
            )
        }
        .onChange(of: scorecardViewModel.round.currentHole) { _, _ in
            scorecardViewModel.save(modelContext: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        Text("Scorecard")
    }
    .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
