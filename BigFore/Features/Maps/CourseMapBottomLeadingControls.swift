import SwiftData
import SwiftUI

struct CourseMapBottomLeadingControls: View {
    let courseMapViewModel: CourseMapViewModel
    let modelContext: ModelContext
    let courseGeometries: [CourseGeometry]
    let activeGolfClubs: [GolfClub]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BigForeDesign.Spacing.medium) {
                compactHoleActionControls
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing)
        }
        .scrollIndicators(.hidden)
    }

    private var compactHoleAnchorControls: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            compactTapModeButton(
                "T\(courseMapViewModel.targetHoleNumber)",
                systemImage: "figure.golf",
                accessibilityLabel: "Mark tee location",
                mode: .teeBox
            ) {
                courseMapViewModel.setTeeBoxTapMode(geometries: courseGeometries, focusesHoleLine: false)
            }

            compactTapModeButton(
                "P\(courseMapViewModel.targetHoleNumber)",
                systemImage: "flag.fill",
                accessibilityLabel: "Mark pin location",
                mode: .holePin
            ) {
                courseMapViewModel.setHolePinTapMode(geometries: courseGeometries, focusesHoleLine: false)
            }
        }
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var compactHoleActionControls: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Menu {
                Picker("Hole", selection: Binding(
                    get: { courseMapViewModel.targetHoleNumber },
                    set: { courseMapViewModel.selectHole($0, geometries: courseGeometries, modelContext: modelContext) }
                )) {
                    ForEach(courseMapViewModel.availableHoles, id: \.self) { holeNumber in
                        Text("Hole \(holeNumber)").tag(holeNumber)
                    }
                }
            } label: {
                compactControlLabel("H\(courseMapViewModel.targetHoleNumber)", systemImage: "chevron.up.chevron.down")
            }
            .accessibilityLabel("Current hole")
            .accessibilityValue("Hole \(courseMapViewModel.targetHoleNumber)")
            .accessibilityHint("Focuses the selected hole on the map.")

            compactClubPicker

            compactTapModeButton(
                "Ball",
                systemImage: "smallcircle.filled.circle",
                accessibilityLabel: "Set ball location",
                mode: .shotBall
            ) {
                courseMapViewModel.setShotBallTapMode()
            }

            Button {
                courseMapViewModel.startNextShotFromBall()
            } label: {
                compactIconLabel("Start next shot", systemImage: "play.circle.fill")
            }
            .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            .disabled(!courseMapViewModel.canStartNextShotFromBall)
            .accessibilityHint("Starts the next shot from the last marked ball.")

            compactHoleAnchorControls

            Button {
                courseMapViewModel.undoLastPin(modelContext: modelContext)
            } label: {
                compactIconLabel("Undo last pin", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            .disabled(!courseMapViewModel.canUndoLastPin)
            .accessibilityHint("Removes the most recent map pin for this hole.")
        }
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.small)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.capsulePanel)
    }

    @ViewBuilder
    private var compactClubPicker: some View {
        if activeGolfClubs.isEmpty == false {
            Menu {
                Picker("Shot club", selection: Binding(
                    get: { courseMapViewModel.selectedClubID },
                    set: { newValue in
                        courseMapViewModel.selectedClubID = newValue
                        courseMapViewModel.applySelectedClubToCurrentShot(from: activeGolfClubs, modelContext: modelContext)
                    }
                )) {
                    ForEach(activeGolfClubs) { club in
                        Text(club.name).tag(Optional(club.id))
                    }
                }
            } label: {
                compactControlLabel(courseMapViewModel.selectedClubShortName(from: activeGolfClubs), systemImage: "figure.golf")
            }
            .accessibilityLabel("Shot club")
            .accessibilityValue(courseMapViewModel.selectedClubName(from: activeGolfClubs))
            .accessibilityHint("Selects the club saved to the next marked shot.")
        }
    }

    @ViewBuilder
    private func compactTapModeButton(
        _ title: String,
        systemImage: String? = nil,
        accessibilityLabel: String? = nil,
        mode: CourseMapSelectionMode,
        action: @escaping () -> Void
    ) -> some View {
        if courseMapViewModel.selectionMode == mode {
            Button(action: action) {
                compactTapModeLabel(title, systemImage: systemImage)
            }
            .buttonStyle(BigForePillButtonStyle.bigForePrimary)
            .accessibilityLabel(Text(accessibilityLabel ?? title))
        } else {
            Button(action: action) {
                compactTapModeLabel(title, systemImage: systemImage)
            }
            .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            .accessibilityLabel(Text(accessibilityLabel ?? title))
        }
    }

    @ViewBuilder
    private func compactTapModeLabel(_ title: String, systemImage: String?) -> some View {
        if let systemImage {
            compactIconLabel(title, systemImage: systemImage)
        } else {
            compactControlLabel(title)
        }
    }

    private func compactControlLabel(_ title: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 3) {
            Text(title)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
            }
        }
        .frame(minWidth: systemImage == nil ? 44 : 52, minHeight: 36)
        .padding(.horizontal, BigForeDesign.Spacing.xSmall)
    }

    private func compactIconLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 36)
    }
}
