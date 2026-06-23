import Foundation

struct Card: Codable, Identifiable {
    let id: Int
    let deckId: Int
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
    let occlusionData: AnyCodable?

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

/// Thin wrapper so `occlusion_data` (arbitrary JSON) doesn't break decoding.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let string = try? container.decode(String.self) { value = string }
        else if let array = try? container.decode([AnyCodable].self) { value = array }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let string as String: try container.encode(string)
        case let array as [AnyCodable]: try container.encode(array)
        case let dict as [String: AnyCodable]: try container.encode(dict)
        default: try container.encodeNil()
        }
    }
}
