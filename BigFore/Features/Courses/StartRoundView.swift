import SwiftData
import SwiftUI

struct StartRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: StartRoundViewModel

    init(course: GolfCourseAPICourse, tee: GolfCourseAPITeeBox) {
        _viewModel = State(initialValue: StartRoundViewModel(course: course, tee: tee))
    }

    init(savedCourse: GolfCourse, tee: GolfCourseTee) {
        _viewModel = State(initialValue: StartRoundViewModel(savedCourse: savedCourse, tee: tee))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section("Course") {
                Text(viewModel.course.displayName)
                LabeledContent("Tee", value: "\(viewModel.tee.name) · \(viewModel.tee.gender.capitalized)")
                LabeledContent("Total", value: "\(viewModel.tee.totalYards ?? 0) yds · Par \(viewModel.tee.parTotal ?? 0)")
                if let mapPoint = CourseMapPoint(roundSetupCourse: viewModel.course) {
                    NavigationLink("Open Course Map") {
                        CourseMapView(course: mapPoint)
                    }
                }
            }

            Section("Scoring") {
                Picker("Mode", selection: $viewModel.scoringMode) {
                    ForEach(ScoringMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Players") {
                ForEach(viewModel.playerNames.indices, id: \.self) { index in
                    StartRoundPlayerNameRow(name: $viewModel.playerNames[index])
                }
                .onDelete { offsets in
                    viewModel.removePlayers(at: offsets)
                }

                HStack {
                    TextField("Add player", text: $viewModel.newPlayerName)
                        .submitLabel(.done)
                        .onSubmit(viewModel.addPlayer)
                    Button("Add", action: viewModel.addPlayer)
                        .disabled(!viewModel.canAddPlayer)
                }

                Text("Up to 8 players per round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Start Round") {
                    viewModel.startRound(modelContext: modelContext)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!viewModel.canStartRound)
            }
        }
        .navigationTitle("Start Round")
        .navigationDestination(item: $viewModel.createdRound) { round in
            ScorecardView(round: round)
        }
    }
}

private struct StartRoundPlayerNameRow: View {
    @Binding var name: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("Player name", text: $name)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(finishEditing)
                    .onAppear {
                        isFocused = true
                    }
                    .onChange(of: isFocused) { _, isFocused in
                        if !isFocused {
                            finishEditing()
                        }
                    }
            } else {
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        isEditing = true
                    }
                    .accessibilityHint("Double tap to edit player name.")
            }
        }
    }

    private func finishEditing() {
        isEditing = false
    }
}

#Preview {
    NavigationStack {
        Text("Start Round")
    }
    .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
