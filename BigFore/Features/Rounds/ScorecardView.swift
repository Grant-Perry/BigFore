import SwiftData
import SwiftUI

struct ScorecardView: View {
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
                ScorecardLandscapeView(
                    round: scorecardViewModel.round,
                    showsAllPlayers: $landscapeShowsAllPlayers,
                    showsMetrics: $landscapeShowsMetrics
                ) {
                    scorecardViewModel.save(modelContext: modelContext)
                    isShareSheetPresented = true
                }
            } else {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                        ScorecardRoundHeaderCard(round: scorecardViewModel.round)

                        if let mapPoint = CourseMapPoint(round: scorecardViewModel.round) {
                            ScorecardGPSMapActionCard(
                                mapPoint: mapPoint,
                                round: scorecardViewModel.round,
                                focusedPlayerID: scorecardViewModel.focusedPlayerID
                            )
                        }

                        ScorecardHoleSectionCard(
                            viewModel: scorecardViewModel,
                            selectHole: { holeNumber in
                                scorecardViewModel.selectHole(holeNumber, modelContext: modelContext)
                            },
                            setQuickScore: { holeNumbers, relativeToPar in
                                scorecardViewModel.setPrimaryScoreRelativeToPar(relativeToPar, forHoleNumbers: holeNumbers, modelContext: modelContext)
                            }
                        )
                    }
                    .padding(.horizontal, BigForeDesign.Spacing.large)
                    .padding(.top, BigForeDesign.Spacing.large)
                    .padding(.bottom, BigForeDesign.Spacing.medium)

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
                        .padding(.bottom, BigForeDesign.Spacing.large)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
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

private struct ScorecardLandscapeView: View {
    let round: GolfRound
    @Binding var showsAllPlayers: Bool
    @Binding var showsMetrics: Bool
    let share: () -> Void

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
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        Text("Scorecard")
    }
    .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
