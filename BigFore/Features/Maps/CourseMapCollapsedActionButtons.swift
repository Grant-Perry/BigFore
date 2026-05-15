import SwiftData
import SwiftUI

struct CourseMapCollapsedActionButtons: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
