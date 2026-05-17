import SwiftUI

struct ScorecardNinePageControl: View {
    let nines: [ScorecardNine]
    @Binding var selectedNine: ScorecardNine

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            ForEach(nines) { nine in
                Button {
                    selectedNine = nine
                } label: {
                    Text(nine.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .padding(.horizontal, BigForeDesign.Spacing.small)
                        .background(fill(for: nine), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(stroke(for: nine), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Show \(nine.title)")
                .accessibilityAddTraits(selectedNine == nine ? .isSelected : [])
            }
        }
    }

    private func fill(for nine: ScorecardNine) -> LinearGradient {
        selectedNine == nine
            ? LinearGradient(
                colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : BigForeDesign.Gradients.softFill(for: .secondary)
    }

    private func stroke(for nine: ScorecardNine) -> Color {
        selectedNine == nine ? Color.white.opacity(0.5) : .secondary.opacity(0.16)
    }
}
