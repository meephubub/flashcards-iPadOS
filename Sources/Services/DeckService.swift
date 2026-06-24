import Foundation
import Supabase

struct DeckService {

    // Supabase returns ISO 8601 timestamps with timezone offset (e.g. "2025-01-01T00:00:00+00:00").
    // Swift's default JSONDecoder uses .deferredToDate (seconds since 2001) which fails for those
    // strings, causing the entire row decode to throw and producing an empty result array.
    // We provide a custom decoder with the correct strategy here.
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try fractional-seconds ISO 8601 first, then without fractional seconds.
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: str) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(str)")
        }
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static func fetchDecks(for userId: UUID) async throws -> [Deck] {
        let response = try await supabase
            .from("decks")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
        return try decoder.decode([Deck].self, from: response.data)
    }

    static func searchDecks(query: String, userId: UUID) async throws -> [Deck] {
        let response = try await supabase
            .from("decks")
            .select()
            .eq("user_id", value: userId)
            .ilike("name", pattern: "%\(query)%")
            .order("created_at", ascending: false)
            .execute()
        return try decoder.decode([Deck].self, from: response.data)
    }
}
