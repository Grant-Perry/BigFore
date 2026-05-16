import SwiftData
import SwiftUI

struct PlayHomeView: View {
    let openCourseSearch: () -> Void
    let openSavedCourses: () -> Void
    let openRounds: () -> Void
    let openBag: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @Query(sort: \GolfCourse.courseName) private var savedCourses: [GolfCourse]
    @Query(filter: #Predicate<PlayerProfile> { $0.isPrimaryUser }) private var primaryProfiles: [PlayerProfile]
    @AppStorage("playHome.prefersDarkMode") private var prefersDarkMode = false
    @State private var viewModel = PlayHomeViewModel()

    private var primaryProfile: PlayerProfile? {
        primaryProfiles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BigForeDesign.Spacing.large) {
                    PlayProfileHero(profile: primaryProfile, roundsPlayed: rounds.filter(\.isComplete).count)

                    Button(action: openCourseSearch) {
                        Label("Start Round", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(BigForeDesign.Palette.primaryAction)

                    if rounds.isEmpty {
                        PlayEmptyStateCard(
                            hasSavedCourses: !savedCourses.isEmpty,
                            openCourseSearch: openCourseSearch,
                            openSavedCourses: openSavedCourses
                        )
                    }

                    PlayOptionsSection(
                        roundCount: rounds.count,
                        completedRoundCount: rounds.filter(\.isComplete).count,
                        savedCourseCount: savedCourses.count,
                        openRounds: openRounds,
                        openBag: openBag,
                        openSavedCourses: openSavedCourses
                    )
                }
                .padding(BigForeDesign.Spacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                Text(currentAppVersion)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BigForeDesign.Spacing.xSmall)
                    .background(.clear)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    prefersDarkMode.toggle()
                } label: {
                    Label(prefersDarkMode ? "Use light mode" : "Use dark mode", systemImage: prefersDarkMode ? "sun.max.fill" : "moon.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Circle())
                .padding(.top, BigForeDesign.Spacing.small)
                .padding(.trailing, BigForeDesign.Spacing.large)
            }
            .onAppear {
                viewModel.requestLocationAccess()
                viewModel.ensurePrimaryProfile(existingProfiles: primaryProfiles, modelContext: modelContext)
            }
        }
    }
}

private struct PlayProfileHero: View {
    let profile: PlayerProfile?
    let roundsPlayed: Int

    var body: some View {
        NavigationLink {
            if let profile {
                YourProfileView(profile: profile)
            } else {
                ContentUnavailableView("Profile Loading", systemImage: "person.crop.circle", description: Text("BigFore is setting up your player profile."))
            }
        } label: {
            VStack(spacing: BigForeDesign.Spacing.medium) {
                PlayerProfileAvatar(profile: profile, size: 88)

                VStack(spacing: BigForeDesign.Spacing.xSmall) {
                    Text(profile?.displayName ?? "Player")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(profile?.homeCourseName ?? "Set up your home course")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("\(roundsPlayed) \(roundsPlayed == 1 ? "Round" : "Rounds") Played")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, BigForeDesign.Spacing.large)
            .padding(.bottom, BigForeDesign.Spacing.large)
            .background(BigForeDesign.Gradients.cardFill, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Your Profile.")
    }
}

private struct PlayOptionsSection: View {
    let roundCount: Int
    let completedRoundCount: Int
    let savedCourseCount: Int
    let openRounds: () -> Void
    let openBag: () -> Void
    let openSavedCourses: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlayOptionRow(
                title: "Rounds",
                subtitle: "\(roundCount) total",
                systemImage: "scorecard",
                tint: .green,
                action: openRounds
            )

            Divider().padding(.leading, 58)

            NavigationLink {
                StatisticsView()
            } label: {
                PlayOptionRowContent(
                    title: "Statistics",
                    subtitle: "\(completedRoundCount) completed",
                    systemImage: "chart.bar.fill",
                    tint: .blue
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 58)

            PlayOptionRow(
                title: "Equipment",
                subtitle: "Bag and club distances",
                systemImage: "bag.fill",
                tint: .primary,
                action: openBag
            )

            Divider().padding(.leading, 58)

            PlayOptionRow(
                title: "Course Preview",
                subtitle: "\(savedCourseCount) saved",
                systemImage: "eye.fill",
                tint: .purple,
                action: openSavedCourses
            )
        }
        .background(.background, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct PlayOptionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PlayOptionRowContent(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct PlayOptionRowContent: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(BigForeDesign.Spacing.medium)
        .contentShape(Rectangle())
    }
}

#Preview {
    PlayHomeView(openCourseSearch: {}, openSavedCourses: {}, openRounds: {}, openBag: {})
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
