import Foundation

struct CardProgress: Codable, Identifiable {
    let id: Int
    let cardId: Int
    let easeFactor: Double?
    let interval: Int?
    let repetitions: Int?
    let dueDate: Date?
    let lastReviewed: Date?
    /// Stored as JSONB — decoded as a raw string for passing to FSRSService.
    let fsrsState: AnyCodable?
    let fsrsParams: AnyCodable?
    let userId: UUID
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case easeFactor = "ease_factor"
        case interval
        case repetitions
        case dueDate = "due_date"
        case lastReviewed = "last_reviewed"
        case fsrsState = "fsrs_state"
        case fsrsParams = "fsrs_params"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
