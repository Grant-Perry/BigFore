import SwiftUI

/// Tee marker for the scorecard header: gradient by tee name + glass highlight + gender caption.
struct TeeGlassBadge: View {
    let teeName: String
    let teeGender: String
    /// Diameter of the colored circle (points).
    var circleDiameter: CGFloat = 26
    /// Smaller gender caption for tight header rows.
    var compactCaption: Bool = false

    private var genderCaption: String {
        Self.displayGender(teeGender)
    }

    private var normalized: String {
        teeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var gradientColors: [Color] {
        let n = normalized

        if (n.contains("blue") && n.contains("white"))
            || n.contains("combo")
            || n.contains("hybrid") {
            return [Color.blue.opacity(0.95), Color.white.opacity(0.92)]
        }

        if n.contains("black") {
            return [Color.black.opacity(0.92), Color.gray.opacity(0.55)]
        }

        if n.contains("white") {
            return [Color.white.opacity(0.95), Color.gray.opacity(0.45)]
        }

        if n.contains("red") {
            return [Color.red.opacity(0.88), Color.orange.opacity(0.75)]
        }

        if n.contains("gold") || n.contains("yellow") {
            return [Color.yellow.opacity(0.9), Color.orange.opacity(0.72)]
        }

        if n.contains("green") {
            return [Color.green.opacity(0.82), Color.mint.opacity(0.65)]
        }

        if n.contains("silver") || n.contains("gray") || n.contains("grey") {
            return [Color.gray.opacity(0.55), Color.gray.opacity(0.28)]
        }

        if n.contains("blue") {
            return [Color.blue.opacity(0.9), Color.cyan.opacity(0.55)]
        }

        return [Color.secondary.opacity(0.55), Color.secondary.opacity(0.28)]
    }

    private var glowColor: Color {
        gradientColors.first ?? .blue
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: circleDiameter, height: circleDiameter)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.08),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: circleDiameter, height: circleDiameter)

                Circle()
                    .fill(.ultraThinMaterial.opacity(0.42))
                    .frame(width: circleDiameter, height: circleDiameter)
                    .blendMode(.plusLighter)

                Circle()
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    .frame(width: circleDiameter, height: circleDiameter)
            }
            .compositingGroup()
            // Glow + depth
            .shadow(color: glowColor.opacity(0.55), radius: 10, x: 0, y: 0)
            .shadow(color: glowColor.opacity(0.28), radius: 4, x: 0, y: 0)
            .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)

            Text(genderCaption)
                .font(compactCaption ? .system(size: 9, weight: .medium, design: .default) : .caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tee color")
        .accessibilityValue("\(teeName), \(genderCaption)")
    }

    private static func displayGender(_ raw: String) -> String {
        let g = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch g {
        case "m", "male", "men", "mens":
            return "Male"
        case "f", "female", "women", "womens":
            return "Female"
        default:
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "—" : trimmed.capitalized
        }
    }
}
