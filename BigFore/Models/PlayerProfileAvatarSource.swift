import Foundation

enum PlayerProfileAvatarSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case none
    case contacts
    case camera
    case photoLibrary

    var id: String { rawValue }
}
