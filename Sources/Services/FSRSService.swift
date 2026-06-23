import Foundation

// MARK: - App-level rating enum (two-button: Again / Good)

enum AppRating: Int, Codable {
    case again = 1
    case hard  = 2
    case good  = 3
    case easy  = 4
}

// MARK: - Internal FSRS-5 card state (persisted as JSON in card_progress.fsrs_state)

struct FSRSState: Codable {
    var due:           Date
    var stability:     Double
    var difficulty:    Double
    var elapsedDays:   Double
    var scheduledDays: Double
    var reps:          Int
    var lapses:        Int
    var state:         Int    // 0=new, 1=learning, 2=review, 3=relearning
    var lastReview:    Date?

    static var new: FSRSState {
        FSRSState(
            due: Date(),
            stability: 0, difficulty: 0,
            elapsedDays: 0, scheduledDays: 0,
            reps: 0, lapses: 0,
            state: 0, lastReview: nil
        )
    }
}

// MARK: - Result returned to callers

struct FSRSScheduleResult {
    let fsrsStateJSON: String
    let due:           Date
    let interval:      Double
    let reps:          Int
    let difficulty:    Double
}

struct FSRSPreview {
    let againDue: Date
    let goodDue:  Date
}

// MARK: - FSRS-5 Algorithm (self-contained, matches open-spaced-repetition spec)

struct FSRSService {

    // Default FSRS-5 weights (w0…w18)
    private static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722, 7.2102,
        0.5316, 1.0651, 0.0234, 1.6160,  0.1544,
        1.0824, 1.9813, 0.0953, 0.2975,  2.2042,
        0.2407, 2.9466, 0.5034, 0.6567
    ]
    private static let requestRetention: Double = 0.9
    private static let maximumInterval:  Double = 36500

    // MARK: - Public interface

    /// Returns the projected due dates for Again and Good without persisting anything.
    static func preview(currentProgress: CardProgress?) -> FSRSPreview {
        let state = loadState(from: currentProgress)
        let now   = Date()
        let againDue = projectDue(rating: .again, state: state, now: now)
        let goodDue  = projectDue(rating: .good,  state: state, now: now)
        return FSRSPreview(againDue: againDue, goodDue: goodDue)
    }

    /// Schedules a review and returns the new state ready to be persisted.
    static func schedule(rating: AppRating, currentProgress: CardProgress?) throws -> FSRSScheduleResult {
        let state  = loadState(from: currentProgress)
        let now    = Date()
        let next   = nextState(rating: rating, state: state, now: now)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(next)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return FSRSScheduleResult(
            fsrsStateJSON: json,
            due:           next.due,
            interval:      next.scheduledDays,
            reps:          next.reps,
            difficulty:    next.difficulty
        )
    }

    // MARK: - State loading

    private static func loadState(from progress: CardProgress?) -> FSRSState {
        guard
            let json  = progress?.fsrsState,
            let data  = json.data(using: .utf8)
        else { return .new }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(FSRSState.self, from: data)) ?? .new
    }

    // MARK: - Core scheduling

    private static func nextState(rating: AppRating, state: FSRSState, now: Date) -> FSRSState {
        var next = state
        next.reps += 1

        let elapsed = state.lastReview.map { daysBetween($0, now) } ?? 0
        next.elapsedDays = elapsed

        switch state.state {
        case 0: // new
            next.difficulty = initDifficulty(rating)
            next.stability  = initStability(rating)
            next = applyShortTermSchedule(&next, rating: rating, now: now)

        case 1, 3: // learning / relearning
            next.difficulty = nextDifficulty(state.difficulty, rating: rating)
            next.stability  = nextShortTermStability(state.stability, rating: rating)
            next = applyShortTermSchedule(&next, rating: rating, now: now)

        default: // review (2)
            let r = forgettingCurve(elapsed: elapsed, stability: state.stability)
            next.difficulty = nextDifficulty(state.difficulty, rating: rating)
            switch rating {
            case .again:
                next.stability = nextForgetStability(d: state.difficulty, s: state.stability, r: r)
                next.lapses   += 1
                next.scheduledDays = 0
                next.due       = dateOffset(now, minutes: 5)
                next.state     = 3
            case .hard:
                next.stability = nextRecallStability(d: state.difficulty, s: state.stability, r: r, rating: .hard)
                let interval   = clampInterval(nextInterval(next.stability, elapsed: elapsed))
                next.scheduledDays = Double(interval)
                next.due       = dateOffset(now, days: interval)
                next.state     = 2
            case .good:
                next.stability = nextRecallStability(d: state.difficulty, s: state.stability, r: r, rating: .good)
                let interval   = clampInterval(nextInterval(next.stability, elapsed: elapsed))
                next.scheduledDays = Double(interval)
                next.due       = dateOffset(now, days: interval)
                next.state     = 2
            case .easy:
                next.stability = nextRecallStability(d: state.difficulty, s: state.stability, r: r, rating: .easy)
                let interval   = clampInterval(nextInterval(next.stability, elapsed: elapsed))
                next.scheduledDays = Double(interval)
                next.due       = dateOffset(now, days: interval)
                next.state     = 2
            }
        }

        next.lastReview = now
        return next
    }

    /// Project the due date for a given rating without mutating state (used for previews).
    private static func projectDue(rating: AppRating, state: FSRSState, now: Date) -> Date {
        nextState(rating: rating, state: state, now: now).due
    }

    // MARK: - Short-term (learning/relearning) schedule

    private static func applyShortTermSchedule(_ next: inout FSRSState, rating: AppRating, now: Date) -> FSRSState {
        switch rating {
        case .again:
            next.scheduledDays = 0
            next.due   = dateOffset(now, minutes: 1)
            next.state = (next.state == 0) ? 1 : next.state
        case .hard:
            next.scheduledDays = 0
            next.due   = dateOffset(now, minutes: 5)
            next.state = (next.state == 0) ? 1 : next.state
        case .good:
            next.scheduledDays = 0
            next.due   = dateOffset(now, minutes: 10)
            next.state = (next.state == 0) ? 1 : next.state
        case .easy:
            let interval = clampInterval(nextInterval(next.stability, elapsed: next.elapsedDays))
            next.scheduledDays = Double(interval)
            next.due   = dateOffset(now, days: interval)
            next.state = 2
        }
        return next
    }

    // MARK: - FSRS-5 math

    private static func initDifficulty(_ rating: AppRating) -> Double {
        let d = w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1
        return min(max(d, 1), 10)
    }

    private static func initStability(_ rating: AppRating) -> Double {
        max(w[rating.rawValue - 1], 0.1)
    }

    private static func nextDifficulty(_ d: Double, rating: AppRating) -> Double {
        let delta = w[6] * (Double(rating.rawValue) - 3.0)
        let raw   = d - delta + w[7] * (10 - d)   // mean-reversion
        return min(max(raw, 1), 10)
    }

    private static func forgettingCurve(elapsed: Double, stability: Double) -> Double {
        pow(1 + (19.0 / 81.0) * (elapsed / stability), -0.5)
    }

    private static func nextInterval(_ stability: Double, elapsed: Double) -> Int {
        let interval = stability / requestRetention * (pow(requestRetention, 1 / -0.5) - 1)
        return max(1, min(Int(interval.rounded()), Int(maximumInterval)))
    }

    private static func nextRecallStability(d: Double, s: Double, r: Double, rating: AppRating) -> Double {
        let hardPenalty: Double = rating == .hard ? w[15] : 1
        let easyBonus:   Double = rating == .easy ? w[16] : 1
        return s * (exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus + 1)
    }

    private static func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        max(w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14]), 0.1)
    }

    private static func nextShortTermStability(_ s: Double, rating: AppRating) -> Double {
        max(s * exp(w[17] * (Double(rating.rawValue) - 3 + w[18])), 0.1)
    }

    // MARK: - Helpers

    private static func clampInterval(_ i: Int) -> Int {
        max(1, min(i, Int(maximumInterval)))
    }

    private static func daysBetween(_ a: Date, _ b: Date) -> Double {
        b.timeIntervalSince(a) / 86400
    }

    private static func dateOffset(_ base: Date, minutes: Int) -> Date {
        base.addingTimeInterval(Double(minutes) * 60)
    }

    private static func dateOffset(_ base: Date, days: Int) -> Date {
        base.addingTimeInterval(Double(days) * 86400)
    }
}
