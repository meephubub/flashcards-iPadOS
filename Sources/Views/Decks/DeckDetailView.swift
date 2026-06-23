import SwiftUI

struct DeckDetailView: View {
    @Environment(AuthManager.self) private var authManager
    let deck: Deck

    @State private var cards: [Card] = []
    @State private var dueCount: Int = 0
    @State private var isLoading: Bool = false
    @State private var navigateToStudy: Bool = false

    private let bgColor = Color(hex: "#0A0A0A")
    private let surfaceColor = Color(hex: "#1A1A1A")
    private let borderColor = Color(hex: "#2A2A2A")
    private let secondaryText = Color(hex: "#8A8A8A")

    var body: some View {
        ZStack(alignment: .bottom) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Stats row
                HStack(spacing: 0) {
                    statCell(value: "\(deck.cardCount ?? cards.count)", label: "Total")
                    divider
                    statCell(value: "\(dueCount)", label: "Due")
                    if let last = deck.lastStudied {
                        divider
                        statCell(value: DateFormatter.lastStudiedFormatter.string(from: last), label: "Last Studied")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if cards.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundColor(secondaryText)
                        Text("No cards in this deck")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryText)
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
                    colors: [bgColor.opacity(0), bgColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)

                Button {
                    HapticManager.mediumImpact()
                    navigateToStudy = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(dueCount > 0 ? "Study \(dueCount) Due Cards" : "Study All Cards")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(bgColor)
            }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(bgColor, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToStudy) {
            if let userId = authManager.userId {
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
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(card.back)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
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
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(hex: "#2A2A2A"))
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
            // silently fail; list will be empty
        }
    }
}
