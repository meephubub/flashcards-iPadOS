import Foundation

struct CardProgress: Codable, Identifiable {
    let id: UUID
    let cardId: UUID
    let easeFactor: Double?
    let interval: Double?
    let repetitions: Int?
    let dueDate: Date?
    let lastReviewed: Date?
    let fsrsState: String?
    let fsrsParams: String?
    let userId: UUID?
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
