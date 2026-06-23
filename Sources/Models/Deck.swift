import Foundation

// CodingKeys are handled automatically via keyDecodingStrategy = .convertFromSnakeCase
// in DeckService.decoder — no manual CodingKeys needed.
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
}
