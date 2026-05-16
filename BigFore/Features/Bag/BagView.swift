import SwiftData
import SwiftUI

struct BagView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfClub.displayOrder) private var clubs: [GolfClub]
    @State private var viewModel = BagViewModel()

    private var activeClubs: [GolfClub] {
        clubs.filter(\.isActive)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BagSummaryCard(activeCount: activeClubs.count, totalCount: clubs.count)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                if clubs.isEmpty {
                    ContentUnavailableView(
                        "No Clubs Yet",
                        systemImage: "bag",
                        description: Text("Woody needs a starter bag before he can recommend clubs.")
                    )
                } else {
                    Section("Clubs") {
                        ForEach(clubs) { club in
                            BagClubRow(club: club) {
                                viewModel.save(modelContext: modelContext)
                            }
                        }
                    }
                }

                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Bag")
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BigForeDesign.Spacing.medium)
                        .background(BigForeDesign.Palette.destructive)
                }
            }
            .onAppear {
                viewModel.seedDefaultBagIfNeeded(existingClubs: clubs, modelContext: modelContext)
            }
        }
    }
}

private struct BagSummaryCard: View {
    let activeCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            Label("Woody's Bag", systemImage: "figure.golf")
                .font(.headline)
            Text("Set your default distances now. As shot tracking grows, Woody will replace these guesses with your real numbers.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("\(activeCount) active of \(totalCount) clubs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(BigForeDesign.Gradients.cardFill, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
    }
}

private struct BagClubRow: View {
    @Bindable var club: GolfClub
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Club", text: $club.name)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                    .onSubmit(save)

                Toggle("Active", isOn: $club.isActive)
                    .labelsHidden()
                    .onChange(of: club.isActive) {
                        touchAndSave()
                    }
            }

            Picker("Type", selection: Binding(
                get: { club.kind },
                set: { newValue in
                    club.kind = newValue
                    touchAndSave()
                }
            )) {
                ForEach(GolfClubKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)

            Stepper("Carry \(club.carryYards) yds", value: $club.carryYards, in: 0...350, step: 5)
                .onChange(of: club.carryYards) {
                    if club.totalYards < club.carryYards {
                        club.totalYards = club.carryYards
                    }
                    touchAndSave()
                }

            Stepper("Total \(club.totalYards) yds", value: $club.totalYards, in: 0...375, step: 5)
                .onChange(of: club.totalYards) {
                    touchAndSave()
                }

            TextField("Notes", text: $club.notes, axis: .vertical)
                .font(.callout)
                .lineLimit(1...3)
                .onSubmit(save)
        }
        .onChange(of: club.name) {
            touchAndSave()
        }
        .onChange(of: club.notes) {
            touchAndSave()
        }
    }

    private func touchAndSave() {
        club.updatedAt = .now
        save()
    }
}

#Preview {
    BagView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
