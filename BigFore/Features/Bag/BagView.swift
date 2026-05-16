import SwiftData
import SwiftUI

struct BagView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfClub.displayOrder) private var clubs: [GolfClub]
    @State private var viewModel = BagViewModel()
    @State private var isPresentingSpecialClubSheet = false

    private var activeClubs: [GolfClub] {
        clubs.filter(\.isActive)
    }

    private var addableTemplates: [GolfClubTemplate] {
        GolfClubTemplate.templatesAvailableToAdd(to: clubs)
    }

    private var coverageSummary: BagDistanceCoverage.Summary {
        BagDistanceCoverage.summary(for: clubs)
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
                        .onDelete(perform: deleteClubs)
                    }

                    Section {
                        BagDistanceCoverageCard(summary: coverageSummary)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(addableTemplates) { template in
                            Button(template.name) {
                                viewModel.addClub(from: template, existingClubs: clubs, modelContext: modelContext)
                            }
                        }
                        if addableTemplates.isEmpty == false {
                            Divider()
                        }
                        Button("Special…") {
                            isPresentingSpecialClubSheet = true
                        }
                    } label: {
                        Label("Add Club", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add club")
                }
            }
            .sheet(isPresented: $isPresentingSpecialClubSheet) {
                AddSpecialClubSheet { name, carry in
                    viewModel.addSpecialClub(name: name, carryYards: carry, existingClubs: clubs, modelContext: modelContext)
                }
            }
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

    private func deleteClubs(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteClub(clubs[index], modelContext: modelContext)
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
            Text("Set your default carries now. As shot tracking grows, Woody will replace these guesses with your real numbers.")
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

private struct BagDistanceCoverageCard: View {
    let summary: BagDistanceCoverage.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Label(summary.title, systemImage: summary.level == .ok ? "checkmark.circle" : "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(summary.level == .ok ? Color.primary : Color.orange)
            Text(summary.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(BigForeDesign.Gradients.cardFill, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
    }
}

private struct AddSpecialClubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var carryYards = 120
    /// Returns whether the club was inserted successfully.
    let onCommit: (String, Int) -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Club name", text: $name)
                        .textInputAutocapitalization(.words)
                    Stepper("Carry \(carryYards) yds", value: $carryYards, in: 0...350, step: 5)
                    LabeledContent("Est. total") {
                        Text("\(carryYards + GolfClub.rolloutBeyondCarry(for: .other)) yds")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Special clubs save as “Other” and use carry plus \(GolfClub.rolloutBeyondCarryYards) yds for an estimated total.")
                }
            }
            .navigationTitle("Special Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if onCommit(name, carryYards) {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
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
                    club.syncTotalYardsFromCarry()
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
                    club.syncTotalYardsFromCarry()
                    touchAndSave()
                }

            LabeledContent("Est. total") {
                Text("\(club.estimatedTotalYards) yds")
                    .foregroundStyle(.secondary)
            }

            TextField("Notes", text: $club.notes, axis: .vertical)
                .font(.callout)
                .lineLimit(1...3)
                .onSubmit(save)
        }
        .onAppear {
            if club.totalYards != club.estimatedTotalYards {
                club.syncTotalYardsFromCarry()
                club.updatedAt = .now
                save()
            }
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
