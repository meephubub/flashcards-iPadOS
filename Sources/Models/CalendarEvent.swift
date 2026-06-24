import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let startsAt: Date
    let endsAt: Date?
    let allDay: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case allDay = "all_day"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
