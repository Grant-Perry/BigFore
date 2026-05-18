import SwiftUI

/// **cbadge** — small hollow circle with a lowercase **i**; tap opens a popover (“thought bubble”) with full help text.
///
/// Treat as a **superscript**: tuck it against the top-trailing edge of the control or label it annotates (`ZStack(alignment: .topTrailing)` + small `offset`), not as a third column with loose `HStack` spacing.
struct CBadge: View {
    let title: String
    let message: String
    /// Stroke color for the ring and the “i”.
    var tint: Color = .secondary
    /// Outer diameter of the drawn ring (points), excluding the expanded tap target.
    var ringDiameter: CGFloat = 14
    /// VoiceOver hint when the default is too generic for the topic.
    var accessibilityHint: String = "Shows more instructions."
    /// Nudge after layout (e.g. superscript on caption). Use `.zero` when the parent `ZStack` handles placement.
    var layoutOffset: CGSize = CGSize(width: 0, height: -5)
    /// `.centered` keeps the ring in the middle of the 34×34 tap target (default). `.cornerPinned` puts the ring in the **top-trailing** corner of that target so overlays can sit flush on a control edge; pair with an outer `offset` to pull the glyph **outside** the control.
    var placement: Placement = .centered

    enum Placement: Sendable {
        case centered
        case cornerPinned
    }

    private let minimumTapSide: CGFloat = 34

    @State private var isHelpPresented = false

    /// Circle + “i” centered on each other (never align the glyph to the corner separately).
    private var glyphInRing: some View {
        ZStack {
            Circle()
                .strokeBorder(tint.opacity(0.9), lineWidth: 1)
                .frame(width: ringDiameter, height: ringDiameter)

            Text("i")
                .font(.system(size: ringDiameter * 0.58, weight: .bold, design: .serif))
                .foregroundStyle(tint)
                .offset(y: -0.5)
        }
    }

    var body: some View {
        Button {
            isHelpPresented = true
        } label: {
            switch placement {
            case .centered:
                glyphInRing
                    .frame(minWidth: minimumTapSide, minHeight: minimumTapSide)
                    .contentShape(Rectangle())
            case .cornerPinned:
                ZStack(alignment: .topTrailing) {
                    glyphInRing
                        .frame(width: ringDiameter, height: ringDiameter)
                }
                .frame(width: minimumTapSide, height: minimumTapSide, alignment: .topTrailing)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .offset(x: layoutOffset.width, y: layoutOffset.height)
        .popover(isPresented: $isHelpPresented, attachmentAnchor: .point(.top)) {
            ScrollView {
                VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                    Text(title)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(BigForeDesign.Spacing.large)
            }
            .frame(width: 320, alignment: .leading)
            .frame(maxHeight: 360)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }
}
