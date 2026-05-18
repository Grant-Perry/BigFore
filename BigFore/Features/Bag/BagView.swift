import SwiftData
import SwiftUI

struct BagView: View {
    /// When set (e.g. root tab), leading chevron returns here—typically Play—so the screen isn’t a dead end with the keyboard up.
    var onDismiss: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: [
            SortDescriptor(\GolfClub.carryYards, order: .reverse),
            SortDescriptor(\GolfClub.name)
        ]
    ) private var clubs: [GolfClub]
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

    private var carryGapHighlightIDs: Set<UUID> {
        BagDistanceCoverage.clubIDsFollowingCarryGap(in: clubs)
    }

    private var carryGapCalloutByShorterID: [UUID: BagDistanceCoverage.CarryGapCallout] {
        Dictionary(uniqueKeysWithValues: BagDistanceCoverage.carryGapCallouts(in: clubs).map { ($0.shorterClubID, $0) })
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
                            if let callout = carryGapCalloutByShorterID[club.id] {
                                BagCarryGapExplainerCard(
                                    callout: callout,
                                    gapFillTemplates: GolfClubTemplate.templatesSuggestedForCarryGap(
                                        longerCarryYards: callout.longerCarryYards,
                                        shorterCarryYards: callout.shorterCarryYards,
                                        existingClubs: clubs
                                    ),
                                    onAddTemplate: { template in
                                        viewModel.addClub(from: template, modelContext: modelContext)
                                    },
                                    onAddSpecial: { isPresentingSpecialClubSheet = true }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }

                            BagClubRow(club: club) {
                                viewModel.save(modelContext: modelContext)
                            }
                            .listRowBackground(
                                BagCarryGapRowBackground(
                                    isHighlighted: carryGapHighlightIDs.contains(club.id)
                                )
                            )
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
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Bag")
            .listStyle(.insetGrouped)
            .toolbar {
                if let onDismiss {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                        }
                        .accessibilityLabel("Back to Play")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(addableTemplates) { template in
                            Button(template.name) {
                                viewModel.addClub(from: template, modelContext: modelContext)
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
                    viewModel.addSpecialClub(name: name, carryYards: carry, modelContext: modelContext)
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

private struct BagCarryGapExplainerCard: View {
    let callout: BagDistanceCoverage.CarryGapCallout
    let gapFillTemplates: [GolfClubTemplate]
    let onAddTemplate: (GolfClubTemplate) -> Void
    let onAddSpecial: () -> Void

    private var midpointCarry: Int {
        let raw = (callout.longerCarryYards + callout.shorterCarryYards) / 2
        return ((raw + 2) / 5) * 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Label("Carry gap before \(callout.shorterClubName)", systemImage: "arrow.down.to.line.compact")
                .font(.subheadline.weight(.semibold))
            Text(
                "After \(callout.longerClubName) (\(callout.longerCarryYards) yd carry), the next club down is \(callout.shorterClubName) (\(callout.shorterCarryYards) yd)—a \(callout.gapYards) yd jump. Add a club near \(midpointCarry) yd carry (or tune these numbers) so Woody has an answer between them."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if gapFillTemplates.isEmpty {
                Text("No preset catalog club sits strictly between those carries—use Special or adjust carries.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Menu {
                ForEach(gapFillTemplates) { template in
                    Button("\(template.name) (~\(template.carryYards) yd)") {
                        onAddTemplate(template)
                    }
                }
                if gapFillTemplates.isEmpty == false {
                    Divider()
                }
                Button("Special club…", action: onAddSpecial)
            } label: {
                Label("Fill gap", systemImage: "plus.circle.fill")
            }
            .buttonStyle(BigForePillButtonStyle.bigForePrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(BigForeDesign.Gradients.cardFill, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.gpRedPink.opacity(0.55), Color.gpPink.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
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

private struct BagCarryGapRowBackground: View {
    let isHighlighted: Bool

    var body: some View {
        if isHighlighted {
            LinearGradient(
                colors: [
                    Color.gpRedPink.opacity(0.4),
                    Color.gpPink.opacity(0.22)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color.clear
        }
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
