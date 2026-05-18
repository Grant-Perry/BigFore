import SwiftData
import SwiftUI

struct CourseMapSelectedInfoCard: View {
    let courseMapViewModel: CourseMapViewModel
    let modelContext: ModelContext

    var body: some View {
        if let summary = courseMapViewModel.selectedMapInfoSummary {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: BigForeDesign.Spacing.medium)

                    Button("Close distance popup", systemImage: "xmark.circle.fill") {
                        courseMapViewModel.clearSelectedMapInfo()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                }

                LabeledContent(summary.referenceDistanceLabel, value: summary.referenceDistanceText ?? "Reference unavailable")
                LabeledContent("To pin", value: summary.pinDistanceText ?? "Pin unavailable")

                if courseMapViewModel.selectedShotMarker != nil {
                    Button("Delete Ball", role: .destructive) {
                        courseMapViewModel.deleteSelectedShotMarker(modelContext: modelContext)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeDestructive)
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
