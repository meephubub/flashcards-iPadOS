import Foundation
import FSRS
import Supabase

// MARK: - Rating mapping

extension Rating {
    static var again: Rating { .again }
    static var good: Rating { .good }
}

struct FSRSSchedule {
    let againCard: FSRSCard
    let goodCard: FSRSCard
    let againDue: Date
    let goodDue: Date
}

struct FSRSService {

    // MARK: - Scheduling preview (no DB write)

    static func getSchedule(for cardProgress: CardProgress?) -> FSRSSchedule {
        let fsrs = FSRS(parameters: .init())
        let card = buildFSRSCard(from: cardProgress)
        let now = Date()

        let againResult = fsrs.repeat(card: card, now: now)[.again]!
        let goodResult = fsrs.repeat(card: card, now: now)[.good]!

        return FSRSSchedule(
            againCard: againResult.card,
            goodCard: goodResult.card,
            againDue: againResult.card.due,
            goodDue: goodResult.card.due
        )
    }

    // MARK: - Record a review and persist to Supabase

    static func recordReview(cardId: UUID, userId: UUID, rating: Rating, currentProgress: CardProgress?) async throws {
        let fsrs = FSRS(parameters: .init())
        let card = buildFSRSCard(from: currentProgress)
        let now = Date()

        guard let result = fsrs.repeat(card: card, now: now)[rating] else { return }
        let updatedCard = result.card

        // Encode updated FSRS card state to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let stateData = try encoder.encode(FSRSCardState(from: updatedCard))
        let stateJSON = String(data: stateData, encoding: .utf8) ?? "{}"

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let upsertPayload: [String: String] = [
            "card_id": cardId.uuidString,
            "user_id": userId.uuidString,
            "due_date": iso8601.string(from: updatedCard.due),
            "last_reviewed": iso8601.string(from: now),
            "fsrs_state": stateJSON,
            "interval": String(updatedCard.scheduledDays),
            "repetitions": String(updatedCard.reps),
            "ease_factor": String(updatedCard.difficulty)
        ]

        if let existing = currentProgress {
            try await supabase
                .from("card_progress")
                .update(upsertPayload)
                .eq("id", value: existing.id.uuidString)
                .execute()
        } else {
            try await supabase
                .from("card_progress")
                .insert(upsertPayload)
                .execute()
        }
    }

    // MARK: - Helpers

    private static func buildFSRSCard(from progress: CardProgress?) -> FSRSCard {
        guard let progress = progress,
              let stateJSON = progress.fsrsState,
              let stateData = stateJSON.data(using: .utf8) else {
            return FSRSCard()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let state = try? decoder.decode(FSRSCardState.self, from: stateData) {
            var card = FSRSCard()
            card.due = state.due
            card.stability = state.stability
            card.difficulty = state.difficulty
            card.elapsedDays = state.elapsedDays
            card.scheduledDays = state.scheduledDays
            card.reps = state.reps
            card.lapses = state.lapses
            card.state = FSRSCardState.fsrsState(from: state.state)
            card.lastReview = state.lastReview
            return card
        }

        return FSRSCard()
    }
}

// MARK: - Codable bridge for FSRSCard state

struct FSRSCardState: Codable {
    let due: Date
    let stability: Double
    let difficulty: Double
    let elapsedDays: Int
    let scheduledDays: Int
    let reps: Int
    let lapses: Int
    let state: String
    let lastReview: Date?

    init(from card: FSRSCard) {
        self.due = card.due
        self.stability = card.stability
        self.difficulty = card.difficulty
        self.elapsedDays = card.elapsedDays
        self.scheduledDays = card.scheduledDays
        self.reps = card.reps
        self.lapses = card.lapses
        self.state = card.state.rawValue
        self.lastReview = card.lastReview
    }

    static func fsrsState(from raw: String) -> FSRS.State {
        switch raw {
        case "New": return .new
        case "Learning": return .learning
        case "Review": return .review
        case "Relearning": return .relearning
        default: return .new
        }
    }
}
