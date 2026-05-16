import Foundation
import SwiftData

@Model
final class PlayerProfile {
    var id: UUID
    var displayName: String
    var contactIdentifier: String?
    @Attribute(.externalStorage) var avatarImageData: Data?
    var avatarSourceRawValue: String
    var handicapIndex: Double?
    var isPrimaryUser: Bool = false
    var phoneNumber: String?
    var emailAddress: String?
    var homeCourseName: String?
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .nullify, inverse: \RoundPlayer.playerProfile) var roundPlayers: [RoundPlayer]

    init(
        id: UUID = UUID(),
        displayName: String,
        contactIdentifier: String? = nil,
        avatarImageData: Data? = nil,
        avatarSource: PlayerProfileAvatarSource = .none,
        handicapIndex: Double? = nil,
        isPrimaryUser: Bool = false,
        phoneNumber: String? = nil,
        emailAddress: String? = nil,
        homeCourseName: String? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        roundPlayers: [RoundPlayer] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.contactIdentifier = contactIdentifier
        self.avatarImageData = avatarImageData
        self.avatarSourceRawValue = avatarSource.rawValue
        self.handicapIndex = handicapIndex
        self.isPrimaryUser = isPrimaryUser
        self.phoneNumber = phoneNumber
        self.emailAddress = emailAddress
        self.homeCourseName = homeCourseName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.roundPlayers = roundPlayers
    }
}

extension PlayerProfile {
    var avatarSource: PlayerProfileAvatarSource {
        get { PlayerProfileAvatarSource(rawValue: avatarSourceRawValue) ?? .none }
        set { avatarSourceRawValue = newValue.rawValue }
    }
}
