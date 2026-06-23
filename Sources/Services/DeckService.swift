import Foundation
import Supabase

struct DeckService {
    static func fetchDecks(for userId: UUID) async throws -> [Deck] {
        let decks: [Deck] = try await supabase
            .from("decks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return decks
    }

    static func searchDecks(query: String, userId: UUID) async throws -> [Deck] {
        let decks: [Deck] = try await supabase
            .from("decks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .ilike("name", value: "%\(query)%")
            .order("created_at", ascending: false)
            .execute()
            .value
        return decks
    }
}
