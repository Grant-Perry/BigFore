import SwiftUI

struct PlayEmptyStateCard: View {
    let hasSavedCourses: Bool
    let openCourseSearch: () -> Void
    let openSavedCourses: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.large) {
            Image(systemName: "figure.golf.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(BigForeDesign.Palette.primaryAction)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                Text("Ready for your next round?")
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("Find a course, pick a tee, and start scoring from one place.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: BigForeDesign.Spacing.medium) {
                Button {
                    openCourseSearch()
                } label: {
                    Label("Find a Course", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(BigForeDesign.Palette.primaryAction)

                if hasSavedCourses {
                    Button {
                        openSavedCourses()
                    } label: {
                        Label("Open Saved Courses", systemImage: "tray.full")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(BigForeDesign.Palette.primaryAction)
                }
            }
        }
        .padding(BigForeDesign.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        }
    }
}
