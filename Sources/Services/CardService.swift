import Foundation
import Supabase

struct CardService {
    static func fetchCards(for deckId: UUID) async throws -> [Card] {
        let cards: [Card] = try await supabase
            .from("cards")
            .select()
            .eq("deck_id", value: deckId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        return cards
    }

    static func fetchStudyCards(for deckId: UUID, userId: UUID) async throws -> [(Card, CardProgress?)] {
        // Fetch all non-excluded cards for the deck
        let cards: [Card] = try await supabase
            .from("cards")
            .select()
            .eq("deck_id", value: deckId.uuidString)
            .eq("exclude_from_srs", value: false)
            .execute()
            .value

        // Fetch progress records for this user
        let cardIds = cards.map { $0.id.uuidString }
        var progressMap: [UUID: CardProgress] = [:]

        if !cardIds.isEmpty {
            let progressRecords: [CardProgress] = try await supabase
                .from("card_progress")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("card_id", values: cardIds)
                .execute()
                .value

            for progress in progressRecords {
                progressMap[progress.cardId] = progress
            }
        }

        // Pair cards with their progress, sort by due date (nil due = new card, study first)
        let paired: [(Card, CardProgress?)] = cards.map { card in
            (card, progressMap[card.id])
        }

        let now = Date()
        let sorted = paired.sorted { a, b in
            let aDate = a.1?.dueDate ?? Date.distantPast
            let bDate = b.1?.dueDate ?? Date.distantPast
            // New cards (nil due) and overdue cards first
            let aDue = aDate <= now
            let bDue = bDate <= now
            if aDue && !bDue { return true }
            if !aDue && bDue { return false }
            return aDate < bDate
        }

        return sorted
    }

    // MARK: - Upsert progress after an FSRS review

    static func upsertProgress(
        cardId: UUID,
        userId: UUID,
        fsrsStateJSON: String,
        due: Date,
        interval: Double,
        reps: Int,
        difficulty: Double,
        existing: CardProgress?
    ) async throws {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload: [String: AnyJSON] = [
            "card_id":     .string(cardId.uuidString),
            "user_id":     .string(userId.uuidString),
            "due_date":    .string(iso.string(from: due)),
            "last_reviewed": .string(iso.string(from: Date())),
            "fsrs_state":  .string(fsrsStateJSON),
            "interval":    .double(interval),
            "repetitions": .integer(reps),
            "ease_factor": .double(difficulty)
        ]

        if let existing {
            try await supabase
                .from("card_progress")
                .update(payload)
                .eq("id", value: existing.id.uuidString)
                .execute()
        } else {
            try await supabase
                .from("card_progress")
                .insert(payload)
                .execute()
        }
    }
}
