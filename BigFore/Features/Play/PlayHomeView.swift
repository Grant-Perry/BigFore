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
                    PlayProfileHero(
                        profile: primaryProfile,
                        roundsPlayed: rounds.filter(\.isComplete).count,
                        onStartRound: openCourseSearch
                    )

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
            .scrollContentBackground(.hidden)
            .bigForeAerialScreenBackground()
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
    let onStartRound: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                .padding(.horizontal, BigForeDesign.Spacing.large)
                .padding(.bottom, 52)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Your Profile.")

            Button(action: onStartRound) {
                PlayStartRoundGolfChip()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tee off, start round")
            .accessibilityHint("Opens course search.")
            .padding(.trailing, BigForeDesign.Spacing.medium)
            .padding(.bottom, BigForeDesign.Spacing.medium)
        }
        .frame(maxWidth: .infinity)
        .bigForeAerialGlassCardBackground()
    }
}

/// Compact tee-box style control: flag + fairway strip, not a full-width capsule.
private struct PlayStartRoundGolfChip: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.20))
                    .frame(width: 36, height: 36)
                Image(systemName: "flag.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: 3)
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .offset(x: 10, y: 12)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tee Off")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                Text("Start round")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .accessibilityHidden(true)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BigForeDesign.Palette.primaryAction.opacity(0.92),
                            BigForeDesign.Palette.primaryAction.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
        }
        .frame(minHeight: 44)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                systemImage: "list.clipboard",
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
        .bigForeAerialGlassCardBackground()
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
