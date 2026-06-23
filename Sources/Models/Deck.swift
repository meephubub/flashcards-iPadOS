import Foundation

struct Deck: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let cardCount: Int?
    /// Stored as plain text in the DB (e.g. "Never" or a date string).
    let lastStudied: String?
    let createdAt: Date?
    let updatedAt: Date?
    let tag: String?
    let userId: UUID?
    let excludeFromSrs: Bool?
    let isPublic: Bool?
    let shareId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case cardCount = "card_count"
        case lastStudied = "last_studied"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case tag
        case userId = "user_id"
        case excludeFromSrs = "exclude_from_srs"
        case isPublic = "is_public"
        case shareId = "share_id"
    }
}
