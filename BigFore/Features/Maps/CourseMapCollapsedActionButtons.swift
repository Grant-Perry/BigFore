import SwiftData
import SwiftUI

struct CourseMapCollapsedActionButtons: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.saveCurrentHole(modelContext: modelContext)
            } label: {
                Label(viewModel.saveHoleButtonTitle, systemImage: "checkmark")
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        BigForeDesign.Palette.primaryAction.opacity(viewModel.canSaveHole ? 0.92 : 0.28),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSaveHole)
            .opacity(viewModel.canSaveHole ? 1 : 0.55)
            .accessibilityLabel(Text(viewModel.saveHoleActionAccessibilityLabel))
            .accessibilityHint("Syncs the current hole score before advancing.")

            Button(action: onExpand) {
                Label("Show map controls", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .frame(width: 52, height: 52)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
