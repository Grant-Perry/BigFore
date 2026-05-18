import SwiftData
import SwiftUI

struct CourseMapTargetSavePanel: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    let featurePoints: [CourseMapFeaturePoint]
    @Binding var isExpanded: Bool

    var body: some View {
        @Bindable var viewModel = viewModel

        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                Text("Hazard, layup, dogleg, and target stay saved for Hole \(viewModel.targetHoleNumber).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Picker("Target type", selection: $viewModel.selectedFeatureKind) {
                    ForEach(CourseMapFeatureKind.saveableTargetKinds) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                TextField(viewModel.defaultFeatureLabel, text: $viewModel.featureLabel)
                    .textInputAutocapitalization(.words)
                Button("Save Target") {
                    viewModel.saveMeasuredPointAsFeature(modelContext: modelContext)
                }
                .buttonStyle(BigForePillButtonStyle.bigForePrimary)
                .controlSize(.large)
                .disabled(viewModel.measuredCoordinate == nil)
                savedFeaturePointList
            }
            .padding(.top, BigForeDesign.Spacing.small)
        } label: {
            Text("Save Target")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var savedFeaturePointList: some View {
        if featurePoints.isEmpty == false {
            Divider()
            Text("Saved on Hole \(viewModel.targetHoleNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(featurePoints) { featurePoint in
                HStack(spacing: BigForeDesign.Spacing.medium) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(featurePoint.label)
                            .font(.callout)
                            .lineLimit(1)
                        Text(featurePoint.kind.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: BigForeDesign.Spacing.medium)

                    Button("Delete \(featurePoint.label)", systemImage: "trash", role: .destructive) {
                        viewModel.deleteUserMappedFeaturePoint(featurePoint, modelContext: modelContext)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(BigForePillButtonStyle.bigForeDestructive)
                    .controlSize(.small)
                }
            }
        }
    }
}
