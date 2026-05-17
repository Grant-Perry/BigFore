import SwiftData
import SwiftUI

struct ScorecardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var scorecardViewModel: ScorecardViewModel
    @State private var isShareSheetPresented = false
    @State private var landscapeShowsAllPlayers = false
    @State private var landscapeShowsMetrics = true

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
                VStack(spacing: BigForeDesign.Spacing.medium) {
                    VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                        HStack {
                            Spacer(minLength: 0)
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
                                        .font(.caption2.weight(.semibold))
                                        .labelStyle(.titleAndIcon)
                                        .imageScale(.medium)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .accessibilityLabel("Open GPS map")
                                .accessibilityValue("Hole \(scorecardViewModel.round.currentHole)")
                                .accessibilityHint("Opens the GPS map for the current round.")
                            }
                        }

                        ScorecardRoundHeaderCard(round: scorecardViewModel.round)
                    }
                    .padding(.horizontal, BigForeDesign.Spacing.large)
                    .padding(.top, BigForeDesign.Spacing.medium)

                    ScorecardHoleSectionCard(
                        viewModel: scorecardViewModel,
                        selectHole: { holeNumber in
                            scorecardViewModel.selectHole(holeNumber, modelContext: modelContext)
                        },
                        setQuickScore: { holeNumbers, relativeToPar in
                            scorecardViewModel.setPrimaryScoreRelativeToPar(relativeToPar, forHoleNumbers: holeNumbers, modelContext: modelContext)
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
                                previousTitle: "Previous",
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
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    scorecardViewModel.save(modelContext: modelContext)
                    isShareSheetPresented = true
                } label: {
                    Label("Share Scorecard", systemImage: "square.and.arrow.up")
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
