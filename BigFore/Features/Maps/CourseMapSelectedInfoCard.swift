import SwiftData
import SwiftUI

struct CourseMapSelectedInfoCard: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext

    var body: some View {
        if let summary = viewModel.selectedMapInfoSummary {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: BigForeDesign.Spacing.medium)

                    Button("Close distance popup", systemImage: "xmark.circle.fill") {
                        viewModel.clearSelectedMapInfo()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                }

                LabeledContent(summary.referenceDistanceLabel, value: summary.referenceDistanceText ?? "Reference unavailable")
                LabeledContent("Selected to pin", value: summary.pinDistanceText ?? "Pin unavailable")

                if viewModel.selectedShotMarker != nil {
                    Button("Delete Ball", role: .destructive) {
                        viewModel.deleteSelectedShotMarker(modelContext: modelContext)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .font(.callout)
            .padding(BigForeDesign.Spacing.medium)
            .frame(maxWidth: 280)
            .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.card)
            .shadow(radius: 4)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
