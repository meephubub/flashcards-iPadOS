import Foundation

struct Deck: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let cardCount: Int?
    let lastStudied: Date?
    let createdAt: Date?
    let updatedAt: Date?
    let tag: String?
    let userId: UUID?
    let excludeFromSrs: Bool?
    let isPublic: Bool?
    let shareId: String?

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
