import SwiftData
import SwiftUI

struct RoundsListView: View {
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @State private var viewModel = RoundsListViewModel()

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
                            RoundRow(round: round, viewModel: viewModel)
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
                            RoundRow(round: round, viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("Rounds")
        }
    }
}

struct RoundRow: View {
    let round: GolfRound
    let viewModel: RoundsListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(round.courseName)
                .font(.headline)
            Text("\(round.teeName) · \(round.scoringMode.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
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
