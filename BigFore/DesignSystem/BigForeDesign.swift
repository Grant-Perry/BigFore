import SwiftUI

enum BigForeDesign {
    enum Palette {
        static let primaryAction: Color = .green
        static let secondaryAction: Color = .blue
        static let mapPin: Color = .orange
        static let tee: Color = .blue
        static let holePin: Color = .green
        static let shot: Color = .blue
        static let ball: Color = .green
        static let target: Color = .cyan
        static let hazard: Color = .yellow
        static let dogleg: Color = .purple
        static let destructive: Color = .red
        static let distanceLine: Color = .orange
        static let setupLine: Color = .red
        static let transitionLine: Color = .green
        static let shotLine: Color = .blue
    }

    enum Radius {
        static let card: CGFloat = 14
        static let panel: CGFloat = 22
        static let capsulePanel: CGFloat = 17
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
    }

    enum Gradients {
        static let cardFill = LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemGroupedBackground).opacity(0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static func softFill(for color: Color) -> LinearGradient {
            LinearGradient(
                colors: [
                    color.opacity(0.22),
                    color.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func strongFill(for color: Color) -> LinearGradient {
            LinearGradient(
                colors: [
                    color,
                    color.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

extension View {
    func bigForePanelBackground(
        cornerRadius: CGFloat = BigForeDesign.Radius.panel,
        materialOpacity: Double = 0.76
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial.opacity(materialOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.background.opacity(0.30))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
