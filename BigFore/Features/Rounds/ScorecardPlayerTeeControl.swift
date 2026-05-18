import SwiftData
import SwiftUI

/// Per-player tee badge + picker for the scorecard header (primary player).
struct ScorecardPlayerTeeControl: View {
    @Bindable var player: RoundPlayer
    let round: GolfRound
    let onTeeSelected: (GolfCourseTee) -> Void

    @State private var isTeePickerPresented = false

    @Query private var matchingCourses: [GolfCourse]

    init(player: RoundPlayer, round: GolfRound, onTeeSelected: @escaping (GolfCourseTee) -> Void) {
        self.player = player
        self.round = round
        self.onTeeSelected = onTeeSelected
        let id = round.courseExternalID
        _matchingCourses = Query(filter: #Predicate<GolfCourse> { course in
            course.externalID == id
        })
    }

    private var sortedTees: [GolfCourseTee] {
        ((matchingCourses.first)?.tees ?? []).sorted { lhs, rhs in
            switch (lhs.totalYards, rhs.totalYards) {
            case let (lhsYards?, rhsYards?) where lhsYards != rhsYards:
                return lhsYards < rhsYards
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                break
            }

            let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return lhs.gender.localizedCaseInsensitiveCompare(rhs.gender) == .orderedAscending
        }
    }

    private var canPickTee: Bool {
        round.isComplete == false && sortedTees.count > 1
    }

    var body: some View {
        Group {
            if canPickTee {
                Button {
                    isTeePickerPresented = true
                } label: {
                    badge
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isTeePickerPresented, attachmentAnchor: .point(.top)) {
                    teePickerContent
                        .presentationCompactAdaptation(.popover)
                }
                .accessibilityHint("Opens tee selection.")
            } else {
                badge
                    .accessibilityHint(round.isComplete ? "Tee is fixed for completed rounds." : "Save this course with multiple tees to switch here.")
            }
        }
    }

    private var badge: some View {
        TeeGlassBadge(
            teeName: player.resolvedTeeName(in: round),
            teeGender: player.resolvedTeeGender(in: round),
            circleDiameter: 20,
            compactCaption: true
        )
    }

    private var teePickerContent: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            Text("Tee set")
                .font(.headline)

            if sortedTees.isEmpty {
                Text("No saved tee data for this course. Save the course from Find or Saved to enable tee changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedTees, id: \.persistentModelID) { tee in
                            Button {
                                onTeeSelected(tee)
                                isTeePickerPresented = false
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: BigForeDesign.Spacing.small) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(tee.name) - \(Self.teeGenderDisplay(tee.gender))")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        if let subtitle = teeSubtitle(tee) {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    if tee.name == player.resolvedTeeName(in: round), tee.gender == player.resolvedTeeGender(in: round) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                            .imageScale(.medium)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(BigForeDesign.Spacing.medium)
        .frame(minWidth: 240, maxWidth: 300)
    }

    private func teeSubtitle(_ tee: GolfCourseTee) -> String? {
        var parts: [String] = []
        if let yards = tee.totalYards {
            parts.append("\(yards) yd")
        }
        if let par = tee.parTotal {
            parts.append("Par \(par)")
        }
        if parts.isEmpty {
            return nil
        }
        return parts.joined(separator: " · ")
    }

    private static func teeGenderDisplay(_ raw: String) -> String {
        let g = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch g {
        case "m", "male", "men", "mens":
            return "Male"
        case "f", "female", "women", "womens":
            return "Female"
        default:
            return raw.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        }
    }
}
