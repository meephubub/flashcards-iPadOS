import Foundation

struct Card: Codable, Identifiable {
    let id: UUID
    let deckId: UUID
    let front: String
    let back: String
    let frontImgUrl: String?
    let backImgUrl: String?
    let audioUrl: String?
    let videoUrl: String?
    let cardType: String?
    let tag: String?
    let excludeFromSrs: Bool
    let createdAt: Date?
    let updatedAt: Date?
    let userId: UUID?
    let occlusionData: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deckId = "deck_id"
        case front
        case back
        case frontImgUrl = "front_img_url"
        case backImgUrl = "back_img_url"
        case audioUrl = "audio_url"
        case videoUrl = "video_url"
        case cardType = "card_type"
        case tag
        case excludeFromSrs = "exclude_from_srs"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case occlusionData = "occlusion_data"
    }
}
