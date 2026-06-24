import SwiftUI

struct DeckDetailView: View {
    @Environment(AuthManager.self) private var authManager
    let deck: Deck

    @State private var cards: [Card] = []
    @State private var dueCount: Int = 0
    @State private var isLoading: Bool = false
    @State private var navigateToStudy: Bool = false
    @State private var studyUserId: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Stats row
                HStack(spacing: 0) {
                    statCell(value: "\(deck.cardCount ?? cards.count)", label: "Total")
                    divider
                    statCell(value: "\(dueCount)", label: "Due")
                    if let last = deck.lastStudied, last != "Never" {
                        divider
                        statCell(value: last, label: "Last Studied")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if cards.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(.secondary)
                        Text("No cards in this deck")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(cards) { card in
                                cardRow(card)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }

            // Study button
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                .allowsHitTesting(false)

                Button {
                    HapticManager.mediumImpact()
                    guard let userId = authManager.userId else { return }
                    studyUserId = userId
                    navigateToStudy = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(dueCount > 0 ? "Study \(dueCount) Due Cards" : "Study All Cards")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(.label))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToStudy) {
            if let userId = studyUserId {
                StudyView(deck: deck, userId: userId)
            }
        }
        .task {
            await loadCards()
        }
    }

    // MARK: - Card row

    @ViewBuilder
    private func cardRow(_ card: Card) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.front)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(card.back)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.vertical, 3)
    }

    // MARK: - Stat cell helpers

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.5))
            .frame(width: 1, height: 36)
    }

    // MARK: - Data loading

    private func loadCards() async {
        guard let userId = authManager.userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            cards = try await CardService.fetchCards(for: deck.id)
            let studyCards = try await CardService.fetchStudyCards(for: deck.id, userId: userId)
            let now = Date()
            dueCount = studyCards.filter { _, progress in
                guard let due = progress?.dueDate else { return true }
                return due <= now
            }.count
        } catch {
            // silently fail; card list will be empty
        }
    }
}
