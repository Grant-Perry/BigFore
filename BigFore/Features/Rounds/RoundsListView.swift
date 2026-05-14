import SwiftData
import SwiftUI

struct RoundsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @State private var viewModel = RoundsListViewModel()
    @State private var weatherViewModel = WeatherViewModel()
    @State private var roundPendingDeletion: GolfRound?

    var body: some View {
        let activeRounds = viewModel.activeRounds(from: rounds)
        let completedRounds = viewModel.completedRounds(from: rounds)

        NavigationStack {
            List {
                Section("Active") {
                    if activeRounds.isEmpty {
                        Text("Start a round from the Courses tab.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(activeRounds) { round in
                        NavigationLink {
                            ScorecardView(round: round)
                        } label: {
                            RoundRow(
                                round: round,
                                viewModel: viewModel,
                                weatherSummary: weatherViewModel.summary(for: round),
                                weatherErrorText: weatherViewModel.errorText(for: round)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .task(id: round.id) {
                            await weatherViewModel.loadWeather(for: round)
                        }
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
                        NavigationLink {
                            ScorecardView(round: round)
                        } label: {
                            RoundRow(
                                round: round,
                                viewModel: viewModel,
                                weatherSummary: weatherViewModel.summary(for: round),
                                weatherErrorText: weatherViewModel.errorText(for: round)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .task(id: round.id) {
                            await weatherViewModel.loadWeather(for: round)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                roundPendingDeletion = round
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rounds")
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
                        viewModel.delete(roundPendingDeletion, modelContext: modelContext)
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
        }
        .listStyle(.insetGrouped)
    }
}

struct RoundRow: View {
    let round: GolfRound
    let viewModel: RoundsListViewModel
    let weatherSummary: WeatherSummary?
    let weatherErrorText: String?

    var body: some View {
        CourseDiscoveryCard(
            title: round.courseName,
            subtitle: "\(viewModel.dateText(for: round)) · \(round.teeName) · \(round.scoringMode.title)",
            detail: detailText,
            badges: badges,
            systemImage: round.isComplete ? "checkmark.circle.fill" : "location.viewfinder",
            accentColor: round.isComplete ? .secondary : BigForeDesign.Palette.primaryAction,
            showsChevron: true
        )
        .help(weatherErrorText ?? "")
    }

    private var badges: [String] {
        var badges = [round.isComplete ? "Completed" : viewModel.resumeText(for: round)]
        if let weatherSummary {
            badges.append(weatherSummary.temperatureText)
        } else if weatherErrorText != nil {
            badges.append("Weather unavailable")
        }
        badges.append(viewModel.gpsStatusText(for: round))
        return badges
    }

    private var detailText: String {
        guard let leader = viewModel.leader(for: round) else {
            return "\(viewModel.playerCount(for: round)) players"
        }

        return "\(viewModel.playerCount(for: round)) players · Leader: \(leader.name) \(viewModel.summary(for: leader, in: round))"
    }
}

#Preview {
    RoundsListView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
