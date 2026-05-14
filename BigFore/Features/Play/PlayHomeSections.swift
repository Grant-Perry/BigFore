import SwiftUI

struct PlaySavedCoursesSection: View {
    let courses: [GolfCourse]
    let viewModel: PlayHomeViewModel
    let openSavedCourses: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            PlaySectionHeader(title: "Saved Courses", actionTitle: "See All", action: openSavedCourses)

            ForEach(courses) { course in
                NavigationLink {
                    SavedCourseDetailView(course: course)
                } label: {
                    CourseDiscoveryCard(
                        title: course.courseName,
                        subtitle: viewModel.savedCourseSubtitle(for: course),
                        detail: "Pick a tee and start a round.",
                        badges: viewModel.savedCourseBadges(for: course),
                        systemImage: "flag.checkered",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PlayRecentRoundSection: View {
    let round: GolfRound
    let viewModel: PlayHomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            PlaySectionHeader(title: "Recent Round")

            NavigationLink {
                ScorecardView(round: round)
            } label: {
                CourseDiscoveryCard(
                    title: round.courseName,
                    subtitle: "\(viewModel.roundDateText(for: round)) · \(viewModel.roundSetupText(for: round))",
                    detail: viewModel.leaderSummary(for: round),
                    badges: ["Completed"],
                    systemImage: "checkmark.circle.fill",
                    accentColor: .secondary,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct PlaySectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(BigForeDesign.Palette.primaryAction)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
