import SwiftData
import SwiftUI

private enum RoundsNavigation: Hashable {
    /// `(roundID, focusedPlayerID)` — second value is optional focused player when opening the scorecard.
    case scorecard(UUID, UUID?)
    case map(UUID)
    case recap(UUID)
}

struct RoundsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @State private var roundsListViewModel = RoundsListViewModel()
    @State private var playHomeViewModel = PlayHomeViewModel()
    @State private var weatherViewModel = WeatherViewModel()
    @State private var roundPendingDeletion: GolfRound?
    @State private var navigationPath: [RoundsNavigation] = []

    var body: some View {
        let activeRounds = roundsListViewModel.activeRounds(from: rounds)
        let completedRounds = roundsListViewModel.completedRounds(from: rounds)

        NavigationStack(path: $navigationPath) {
            List {
                if let activeRound = activeRounds.first {
                    Section {
                        PlayActiveRoundCard(
                            round: activeRound,
                            playHomeViewModel: playHomeViewModel,
                            weatherSummary: weatherViewModel.summary(for: activeRound),
                            weatherErrorText: weatherViewModel.errorText(for: activeRound),
                            onResume: {
                                navigationPath.append(.scorecard(activeRound.id, nil))
                            },
                            onOpenGPS: {
                                navigationPath.append(.map(activeRound.id))
                            },
                            onSelectPlayerScorecard: { playerID in
                                navigationPath.append(.scorecard(activeRound.id, playerID))
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .task(id: activeRound.id) {
                            await weatherViewModel.loadWeather(for: activeRound, modelContext: modelContext)
                        }
                    }
                }

                Section("Active") {
                    if activeRounds.isEmpty {
                        Text("Start a round from the Courses tab.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(activeRounds) { round in
                        Button {
                            navigationPath.append(.scorecard(round.id, nil))
                        } label: {
                            RoundRow(
                                round: round,
                                roundsListViewModel: roundsListViewModel,
                                weatherSummary: weatherViewModel.summary(for: round),
                                weatherErrorText: weatherViewModel.errorText(for: round)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                roundPendingDeletion = round
                            }
                        }
                    }
                }

                Section("History") {
                    if completedRounds.isEmpty {
                        Text("Completed rounds will appear here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(completedRounds) { round in
                        NavigationLink(value: RoundsNavigation.recap(round.id)) {
                            RoundRow(
                                round: round,
                                roundsListViewModel: roundsListViewModel,
                                weatherSummary: weatherViewModel.summary(for: round),
                                weatherErrorText: weatherViewModel.errorText(for: round)
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                roundPendingDeletion = round
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .bigForeAerialScreenBackground()
            .navigationTitle("Rounds")
            .onAppear {
                playHomeViewModel.requestLocationAccess()
            }
            .confirmationDialog(
                "Delete this round?",
                isPresented: Binding(
                    get: { roundPendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented {
                            roundPendingDeletion = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Round", role: .destructive) {
                    if let roundPendingDeletion {
                        let deletedRoundID = roundPendingDeletion.id
                        roundsListViewModel.delete(roundPendingDeletion, modelContext: modelContext)
                        weatherViewModel.removeWeather(for: deletedRoundID)
                    }
                    roundPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    roundPendingDeletion = nil
                }
            } message: {
                Text("This removes the scorecard and players for this round.")
            }
            .navigationDestination(for: RoundsNavigation.self) { link in
                switch link {
                case .scorecard(let roundID, let focusedPlayerID):
                    if let round = rounds.first(where: { $0.id == roundID }) {
                        ScorecardView(round: round, focusedPlayerID: focusedPlayerID)
                    } else {
                        ContentUnavailableView(
                            "Round unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("That round is no longer in your library.")
                        )
                    }
                case .map(let roundID):
                    if let round = rounds.first(where: { $0.id == roundID }),
                       let mapPoint = CourseMapPoint(round: round) {
                        CourseMapView(course: mapPoint, currentHoleNumber: round.currentHole, round: round)
                    } else {
                        ContentUnavailableView(
                            "GPS unavailable",
                            systemImage: "location.slash",
                            description: Text("Add a course pin from the saved course detail to enable GPS.")
                        )
                    }
                case .recap(let roundID):
                    if let round = rounds.first(where: { $0.id == roundID }) {
                        RoundRecapView(round: round)
                    } else {
                        ContentUnavailableView(
                            "Round unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("That round is no longer in your library.")
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("bigfore.rounds.list")
    }
}

struct RoundRow: View {
    let round: GolfRound
    let roundsListViewModel: RoundsListViewModel
    let weatherSummary: WeatherSummary?
    let weatherErrorText: String?

    var body: some View {
        CourseDiscoveryCard(
            title: round.courseName,
            subtitle: "\(roundsListViewModel.dateText(for: round)) · \(round.teeName) · \(round.scoringMode.title)",
            detail: detailText,
            badges: badges,
            weatherSymbolName: weatherSummary?.symbolName,
            systemImage: round.isComplete ? "checkmark.circle.fill" : "location.viewfinder",
            accentColor: round.isComplete ? .secondary : BigForeDesign.Palette.primaryAction,
            showsChevron: true
        )
        .help(weatherErrorText ?? "")
    }

    private var badges: [String] {
        var badges = [round.isComplete ? "Completed" : roundsListViewModel.resumeText(for: round)]
        if let weatherSummary {
            badges.append(weatherSummary.temperatureText)
            if let windText = weatherSummary.windText {
                badges.append(windText)
            }
        } else if weatherErrorText != nil {
            badges.append("Weather unavailable")
        }
        badges.append(roundsListViewModel.gpsStatusText(for: round))
        return badges
    }

    private var detailText: String {
        guard let leader = roundsListViewModel.leader(for: round) else {
            return "\(roundsListViewModel.playerCount(for: round)) players"
        }

        return "\(roundsListViewModel.playerCount(for: round)) players · Leader: \(leader.name) \(roundsListViewModel.summary(for: leader, in: round))"
    }
}

#Preview {
    RoundsListView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
