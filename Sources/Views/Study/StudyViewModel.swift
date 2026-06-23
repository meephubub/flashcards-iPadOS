import Foundation
import FSRS

@Observable
final class StudyViewModel {

    // MARK: - Session state

    enum SessionState {
        case loading
        case studying
        case reviewing       // cycling wrong cards after 50
        case finished
    }

    let deck: Deck
    let userId: UUID

    private(set) var state: SessionState = .loading
    private(set) var sessionCards: [(Card, CardProgress?)] = []
    private(set) var wrongCards: [(Card, CardProgress?)] = []

    private(set) var currentCardIndex: Int = 0
    private(set) var cardsStudiedCount: Int = 0
    private(set) var isShowingAnswer: Bool = false

    /// Cards remaining in the current pass
    var cardsRemaining: Int {
        switch state {
        case .studying:
            return max(0, sessionCards.count - currentCardIndex)
        case .reviewing:
            return wrongCards.count
        default:
            return 0
        }
    }

    var currentCard: Card? {
        switch state {
        case .studying:
            guard currentCardIndex < sessionCards.count else { return nil }
            return sessionCards[currentCardIndex].0
        case .reviewing:
            guard currentCardIndex < wrongCards.count else { return nil }
            return wrongCards[currentCardIndex].0
        default:
            return nil
        }
    }

    private var currentProgress: CardProgress? {
        switch state {
        case .studying:
            guard currentCardIndex < sessionCards.count else { return nil }
            return sessionCards[currentCardIndex].1
        case .reviewing:
            guard currentCardIndex < wrongCards.count else { return nil }
            return wrongCards[currentCardIndex].1
        default:
            return nil
        }
    }

    // MARK: - FSRS schedule for current card

    private(set) var schedule: FSRSSchedule?

    var nextDueForAgain: String {
        schedule?.againDue.relativeStudyString() ?? "—"
    }

    var nextDueForGood: String {
        schedule?.goodDue.relativeStudyString() ?? "—"
    }

    // MARK: - Timer (25 min countdown)

    private(set) var secondsRemaining: Int = 25 * 60
    private var timerTask: Task<Void, Never>?

    var timerString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Init

    init(deck: Deck, userId: UUID) {
        self.deck = deck
        self.userId = userId
    }

    // MARK: - Load

    func load() async {
        state = .loading
        do {
            sessionCards = try await CardService.fetchStudyCards(for: deck.id, userId: userId)
            state = sessionCards.isEmpty ? .finished : .studying
            if state == .studying {
                computeSchedule()
                startTimer()
            }
        } catch {
            state = .finished
        }
    }

    // MARK: - Actions

    func showAnswer() {
        guard !isShowingAnswer else { return }
        isShowingAnswer = true
        HapticManager.lightImpact()
    }

    func rateCard(isGood: Bool) {
        guard let card = currentCard else { return }
        let rating: Rating = isGood ? .good : .again

        isGood ? HapticManager.success() : HapticManager.warning()

        // Record to Supabase in background
        let progress = currentProgress
        let cardId = card.id
        let uid = userId
        Task {
            try? await FSRSService.recordReview(cardId: cardId, userId: uid, rating: rating, currentProgress: progress)
        }

        if !isGood {
            // Queue for review pass
            if state == .studying {
                wrongCards.append((card, currentProgress))
            }
        }

        cardsStudiedCount += 1
        advance()
    }

    // MARK: - Session flow

    private func advance() {
        isShowingAnswer = false
        schedule = nil

        switch state {
        case .studying:
            let nextIndex = currentCardIndex + 1

            // After 50 cards, switch to review mode if there are wrong cards
            if cardsStudiedCount >= 50 && !wrongCards.isEmpty {
                currentCardIndex = 0
                state = .reviewing
                computeSchedule()
                return
            }

            if nextIndex >= sessionCards.count {
                // End of deck — review wrong cards if any
                if wrongCards.isEmpty {
                    state = .finished
                    timerTask?.cancel()
                } else {
                    currentCardIndex = 0
                    state = .reviewing
                    computeSchedule()
                }
            } else {
                currentCardIndex = nextIndex
                computeSchedule()
            }

        case .reviewing:
            // Remove the card that was just answered correctly; "again" cards go back in
            // For review mode we only advance; wrong cards already recorded in studying
            let nextIndex = currentCardIndex + 1
            if nextIndex >= wrongCards.count {
                // All reviewed — done
                state = .finished
                timerTask?.cancel()
            } else {
                currentCardIndex = nextIndex
                computeSchedule()
            }

        default:
            break
        }
    }

    private func computeSchedule() {
        schedule = FSRSService.getSchedule(for: currentProgress)
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while secondsRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    secondsRemaining -= 1
                }
            }
        }
    }

    func cancelTimer() {
        timerTask?.cancel()
    }
}
