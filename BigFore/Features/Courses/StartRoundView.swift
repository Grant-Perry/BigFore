import SwiftData
import SwiftUI

struct StartRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<PlayerProfile> { $0.isPrimaryUser }) private var primaryProfiles: [PlayerProfile]
    @State private var startRoundViewModel: StartRoundViewModel

    init(course: GolfCourseAPICourse, tee: GolfCourseAPITeeBox) {
        _startRoundViewModel = State(initialValue: StartRoundViewModel(course: course, tee: tee))
    }

    init(savedCourse: GolfCourse, tee: GolfCourseTee) {
        _startRoundViewModel = State(initialValue: StartRoundViewModel(savedCourse: savedCourse, tee: tee))
    }

    var body: some View {
        @Bindable var startRoundViewModel = startRoundViewModel

        Form {
            Section("Course") {
                Text(startRoundViewModel.course.displayName)
                LabeledContent("Tee", value: "\(startRoundViewModel.tee.name) · \(startRoundViewModel.tee.gender.capitalized)")
                LabeledContent("Total", value: "\(startRoundViewModel.tee.totalYards ?? 0) yds · Par \(startRoundViewModel.tee.parTotal ?? 0)")
                if let mapPoint = CourseMapPoint(roundSetupCourse: startRoundViewModel.course) {
                    NavigationLink("Open Course Map") {
                        CourseMapView(course: mapPoint)
                    }
                }
            }

            Section("Scoring") {
                Picker("Mode", selection: $startRoundViewModel.scoringMode) {
                    ForEach(ScoringMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Players") {
                ForEach(startRoundViewModel.playerNames.indices, id: \.self) { index in
                    StartRoundPlayerNameRow(name: $startRoundViewModel.playerNames[index])
                }
                .onDelete { offsets in
                    startRoundViewModel.removePlayers(at: offsets)
                }

                HStack {
                    TextField("Add player", text: $startRoundViewModel.newPlayerName)
                        .submitLabel(.done)
                        .onSubmit(startRoundViewModel.addPlayer)
                    Button("Add", action: startRoundViewModel.addPlayer)
                        .disabled(!startRoundViewModel.canAddPlayer)
                }

                Text("Up to 8 players per round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = startRoundViewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Start Round") {
                    startRoundViewModel.startRound(modelContext: modelContext)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(BigForePillButtonStyle.bigForePrimary)
                .tint(.green)
                .disabled(!startRoundViewModel.canStartRound)
            }
        }
        .navigationTitle("Start Round")
        .navigationDestination(item: $startRoundViewModel.createdRound) { round in
            ScorecardView(round: round)
        }
        .onAppear {
            startRoundViewModel.configurePrimaryPlayer(primaryProfiles.first)
        }
        .onChange(of: primaryProfiles.first?.id) { _, _ in
            startRoundViewModel.configurePrimaryPlayer(primaryProfiles.first)
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
    .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
