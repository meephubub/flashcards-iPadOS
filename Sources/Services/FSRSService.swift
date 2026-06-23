import Foundation
import FSRS

// Alias the library's Card type to avoid collision with our app's Card model.
typealias FSRSLibCard = FSRS.Card

// MARK: - Schedule preview returned to the caller

struct FSRSSchedule {
    let againDue: Date
    let goodDue: Date
}

// MARK: - Service

struct FSRSService {

    private static let scheduler = FSRS(parameters: FSRSParameters())

    // MARK: - Scheduling preview (no DB write)

    static func getSchedule(for progress: CardProgress?) -> FSRSSchedule {
        let card = buildLibCard(from: progress)
        let now  = Date()
        let preview = scheduler.repeat(card: card, now: now)

        let againDue = preview[.again]?.card.due ?? now
        let goodDue  = preview[.good]?.card.due  ?? now

        return FSRSSchedule(againDue: againDue, goodDue: goodDue)
    }

    // MARK: - Record a review and return the updated CardProgress fields

    /// Returns the encoded FSRS state JSON and the new due date.
    static func schedule(
        rating: Rating,
        currentProgress: CardProgress?
    ) throws -> (fsrsStateJSON: String, due: Date, interval: Double, reps: Int, difficulty: Double) {
        let card = buildLibCard(from: currentProgress)
        let now  = Date()

        let result = try scheduler.next(card: card, now: now, grade: rating)
        let updated = result.card

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let stateData = try encoder.encode(FSRSCardState(from: updated))
        let stateJSON = String(data: stateData, encoding: .utf8) ?? "{}"

        return (stateJSON, updated.due, updated.scheduledDays, updated.reps, updated.difficulty)
    }

    // MARK: - Map our Rating enum to the library's Rating enum

    static func libraryRating(from appRating: AppRating) -> Rating {
        switch appRating {
        case .again: return .again
        case .hard:  return .hard
        case .good:  return .good
        case .easy:  return .easy
        }
    }

    // MARK: - Build a library Card from persisted CardProgress

    private static func buildLibCard(from progress: CardProgress?) -> FSRSLibCard {
        guard
            let progress,
            let stateJSON = progress.fsrsState,
            let stateData = stateJSON.data(using: .utf8)
        else {
            return FSRSLibCard()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(FSRSCardState.self, from: stateData) else {
            return FSRSLibCard()
        }

        return FSRSLibCard(
            due:          state.due,
            stability:    state.stability,
            difficulty:   state.difficulty,
            elapsedDays:  state.elapsedDays,
            scheduledDays: state.scheduledDays,
            reps:         state.reps,
            lapses:       state.lapses,
            state:        state.cardState,
            lastReview:   state.lastReview
        )
    }
}

// MARK: - Codable bridge for persisting the FSRS card state as JSON

struct FSRSCardState: Codable {
    let due:           Date
    let stability:     Double
    let difficulty:    Double
    let elapsedDays:   Double
    let scheduledDays: Double
    let reps:          Int
    let lapses:        Int
    let state:         Int      // CardState raw value
    let lastReview:    Date?

    init(from card: FSRSLibCard) {
        self.due           = card.due
        self.stability     = card.stability
        self.difficulty    = card.difficulty
        self.elapsedDays   = card.elapsedDays
        self.scheduledDays = card.scheduledDays
        self.reps          = card.reps
        self.lapses        = card.lapses
        self.state         = card.state.rawValue
        self.lastReview    = card.lastReview
    }

    var cardState: CardState {
        CardState(rawValue: state) ?? .new
    }
}

// MARK: - App-level rating enum (decoupled from the library)

enum AppRating {
    case again, hard, good, easy
}
