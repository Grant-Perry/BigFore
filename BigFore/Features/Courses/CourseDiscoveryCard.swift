import SwiftUI

struct CourseDiscoveryCard: View {
    let title: String
    let subtitle: String?
    let detail: String?
    let badges: [String]
    let systemImage: String
    let accentColor: Color
    let showsChevron: Bool

    init(
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        badges: [String] = [],
        systemImage: String = "flag.fill",
        accentColor: Color = BigForeDesign.Palette.primaryAction,
        showsChevron: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.badges = badges
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(alignment: .center, spacing: BigForeDesign.Spacing.large) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(accentColor.gradient, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !badges.isEmpty {
                    CourseDiscoveryBadgeRow(badges: badges, accentColor: accentColor)
                }

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: BigForeDesign.Spacing.medium)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(BigForeDesign.Spacing.large)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct CourseDiscoveryBadgeRow: View {
    let badges: [String]
    let accentColor: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BigForeDesign.Spacing.small) {
                badgeViews
            }

            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                badgeViews
            }
        }
    }

    @ViewBuilder
    private var badgeViews: some View {
        ForEach(badges, id: \.self) { badge in
            Text(badge)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accentColor)
                .padding(.horizontal, BigForeDesign.Spacing.medium)
                .padding(.vertical, BigForeDesign.Spacing.xSmall)
                .background(accentColor.opacity(0.12), in: Capsule())
        }
    }
}
