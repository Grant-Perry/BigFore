import SwiftData
import SwiftUI

struct ScorecardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ScorecardViewModel

    init(round: GolfRound) {
        _viewModel = State(initialValue: ScorecardViewModel(round: round))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.round.courseName)
                        .font(.headline)
                    Text("\(viewModel.round.clubName) · \(viewModel.round.teeName) \(viewModel.round.teeGender.capitalized)")
                        .foregroundStyle(.secondary)
                    Text(viewModel.round.scoringMode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let mapPoint = CourseMapPoint(round: viewModel.round) {
                Section("On-Course GPS") {
                    LabeledContent("Current hole", value: viewModel.currentHoleSummary)
                    Text(viewModel.currentHoleScoreStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        CourseMapView(course: mapPoint, currentHoleNumber: viewModel.round.currentHole, round: viewModel.round)
                    } label: {
                        Label("Open GPS Map", systemImage: "location.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    Text(viewModel.courseGeometryNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hole") {
                Picker("Hole", selection: $viewModel.round.currentHole) {
                    ForEach(viewModel.availableHoles, id: \.self) { hole in
                        Text("\(hole)").tag(hole)
                    }
                }
                .pickerStyle(.segmented)

                if let hole = viewModel.currentHoleScore {
                    HStack {
                        LabeledContent("Par", value: "\(hole.par)")
                        LabeledContent("Yards", value: "\(hole.yardage ?? 0)")
                    }
                    if let handicap = hole.handicap {
                        LabeledContent("Handicap", value: "\(handicap)")
                    }
                }
            }

            Section("Scores") {
                ForEach(viewModel.players) { player in
                    if let score = viewModel.sortedScores(for: player).first(where: { $0.holeNumber == viewModel.round.currentHole }) {
                        PlayerHoleScoreRow(playerName: player.name, score: score, scoringMode: viewModel.round.scoringMode) {
                            viewModel.save(modelContext: modelContext)
                        }
                    }
                }
            }

            Section("Totals") {
                ForEach(viewModel.players) { player in
                    PlayerTotalRow(player: player, scoringMode: viewModel.round.scoringMode)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    Button("Previous Hole") {
                        viewModel.moveToPreviousHole(modelContext: modelContext)
                    }
                    .disabled(!viewModel.canMoveToPreviousHole)

                    Spacer()

                    Button(viewModel.advanceButtonTitle) {
                        viewModel.advanceOrFinish(modelContext: modelContext)
                    }
                    .disabled(!viewModel.canAdvanceHole)
                }
            }
        }
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.round.currentHole) { _, _ in
            viewModel.save(modelContext: modelContext)
        }
    }
}

struct PlayerHoleScoreRow: View {
    let playerName: String
    @Bindable var score: HoleScore
    let scoringMode: ScoringMode
    let saveScore: () -> Void
    private let scoring = RoundScoring()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(playerName)
                if scoringMode == .stableford {
                    Text("\(scoring.stablefordPoints(for: score)) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let relative = scoring.scoreRelativeToPar(for: score) {
                    Text(scoring.relativeText(relative))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Stepper(value: $score.strokes, in: 0...12) {
                Text(score.strokes == 0 ? "-" : "\(score.strokes)")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .frame(maxWidth: 180)
            .onChange(of: score.strokes) { _, _ in
                saveScore()
            }
        }
    }
}

struct PlayerTotalRow: View {
    let player: RoundPlayer
    let scoringMode: ScoringMode
    private let scoring = RoundScoring()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                Text("\(scoring.completedHoles(for: player)) holes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if scoringMode == .stableford {
                Text("\(scoring.stablefordPoints(for: player)) pts")
                    .font(.headline)
                    .monospacedDigit()
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(scoring.totalStrokes(for: player))")
                        .font(.headline)
                        .monospacedDigit()
                    Text(scoring.relativeText(scoring.scoreRelativeToPar(for: player)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Text("Scorecard")
    }
    .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
