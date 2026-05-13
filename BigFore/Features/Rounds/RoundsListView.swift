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
    }
}

struct RoundRow: View {
    let round: GolfRound
    let viewModel: RoundsListViewModel
    let weatherSummary: WeatherSummary?
    let weatherErrorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(round.courseName)
                .font(.headline)
            Text(viewModel.dateText(for: round))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(round.teeName) · \(round.scoringMode.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let weatherSummary {
                Label(weatherSummary.temperatureText, systemImage: weatherSummary.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let weatherErrorText {
                Label("Weather unavailable", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(weatherErrorText)
            }
            Label("\(viewModel.resumeText(for: round)) · \(viewModel.gpsStatusText(for: round))", systemImage: round.isComplete ? "checkmark.circle" : "location.viewfinder")
                .font(.caption)
                .foregroundStyle(round.isComplete ? Color.secondary : Color.green)
            if let leader = viewModel.leader(for: round) {
                Text("\(viewModel.playerCount(for: round)) players · Leader: \(leader.name) \(viewModel.summary(for: leader, in: round))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RoundsListView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
