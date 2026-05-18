import SwiftUI

struct PlaySavedCoursesSection: View {
    let courses: [GolfCourse]
    let playHomeViewModel: PlayHomeViewModel
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
                        subtitle: playHomeViewModel.savedCourseSubtitle(for: course),
                        detail: "Pick a tee and start a round.",
                        badges: playHomeViewModel.savedCourseBadges(for: course),
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
    let playHomeViewModel: PlayHomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            PlaySectionHeader(title: "Recent Rounds")

            NavigationLink {
                ScorecardView(round: round)
            } label: {
                CourseDiscoveryCard(
                    title: round.courseName,
                    subtitle: "\(playHomeViewModel.roundDateText(for: round)) · \(playHomeViewModel.roundSetupText(for: round))",
                    detail: playHomeViewModel.leaderSummary(for: round),
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
