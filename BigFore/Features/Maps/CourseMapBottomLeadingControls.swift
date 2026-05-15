import SwiftData
import SwiftUI

struct CourseMapBottomLeadingControls: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    let courseGeometries: [CourseGeometry]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BigForeDesign.Spacing.medium) {
                compactZoomControls
                compactHoleActionControls
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing)
        }
        .scrollIndicators(.hidden)
    }

    private var compactZoomControls: some View {
        HStack(spacing: BigForeDesign.Spacing.medium) {
            Button {
                viewModel.zoomIn()
            } label: {
                Label("Zoom in", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }

            Button {
                viewModel.zoomOut()
            } label: {
                Label("Zoom out", systemImage: "minus")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }
        }
        .font(.callout.weight(.semibold))
        .buttonStyle(.plain)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.capsulePanel)
    }

    private var compactHoleAnchorControls: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            compactTapModeButton(
                "T\(viewModel.targetHoleNumber)",
                systemImage: "figure.golf",
                accessibilityLabel: "Mark tee location",
                mode: .teeBox
            ) {
                viewModel.setTeeBoxTapMode(geometries: courseGeometries, focusesHoleLine: false)
            }

            compactTapModeButton(
                "P\(viewModel.targetHoleNumber)",
                systemImage: "flag.fill",
                accessibilityLabel: "Mark pin location",
                mode: .holePin
            ) {
                viewModel.setHolePinTapMode(geometries: courseGeometries, focusesHoleLine: false)
            }
        }
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .buttonBorderShape(.capsule)
    }

    private var compactHoleActionControls: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Menu {
                Picker("Hole", selection: Binding(
                    get: { viewModel.targetHoleNumber },
                    set: { viewModel.selectHole($0, geometries: courseGeometries, modelContext: modelContext) }
                )) {
                    ForEach(viewModel.availableHoles, id: \.self) { holeNumber in
                        Text("Hole \(holeNumber)").tag(holeNumber)
                    }
                }
            } label: {
                compactControlLabel("H\(viewModel.targetHoleNumber)", systemImage: "chevron.up.chevron.down")
            }
            .accessibilityLabel("Current hole")
            .accessibilityValue("Hole \(viewModel.targetHoleNumber)")
            .accessibilityHint("Focuses the selected hole on the map.")

            compactHoleAnchorControls

            compactTapModeButton(
                "Start",
                systemImage: "flag.checkered",
                accessibilityLabel: "Set shot start",
                mode: .shotStart
            ) {
                viewModel.setShotStartTapMode()
            }

            compactTapModeButton(
                "Ball",
                systemImage: "smallcircle.filled.circle",
                accessibilityLabel: "Set ball location",
                mode: .shotBall
            ) {
                viewModel.setShotBallTapMode()
            }

            Button {
                viewModel.startNextShotFromBall()
            } label: {
                compactControlLabel("Next", systemImage: "chevron.right")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canStartNextShotFromBall)
            .accessibilityHint("Starts the next shot from the last marked ball.")

            compactTapModeButton(
                "Measure",
                systemImage: "ruler",
                accessibilityLabel: "Drop measurement pin",
                mode: .measurementPin
            ) {
                viewModel.setMeasurementPinTapMode()
            }

            Button {
                viewModel.undoLastPin(modelContext: modelContext)
            } label: {
                compactIconLabel("Undo last pin", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canUndoLastPin)
            .accessibilityHint("Removes the most recent map pin for this hole.")
        }
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.small)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.capsulePanel)
    }

    @ViewBuilder
    private func compactTapModeButton(
        _ title: String,
        systemImage: String? = nil,
        accessibilityLabel: String? = nil,
        mode: CourseMapSelectionMode,
        action: @escaping () -> Void
    ) -> some View {
        if viewModel.selectionMode == mode {
            Button(action: action) {
                compactTapModeLabel(title, systemImage: systemImage)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(Text(accessibilityLabel ?? title))
        } else {
            Button(action: action) {
                compactTapModeLabel(title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
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
