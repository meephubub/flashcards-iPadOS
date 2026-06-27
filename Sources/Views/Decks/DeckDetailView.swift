import SwiftUI

struct DeckDetailView: View {
    @Environment(AuthManager.self) private var authManager
    let deck: Deck

    @State private var cards: [Card] = []
    @State private var dueCount: Int = 0
    @State private var isLoading: Bool = false
    @State private var showingStudyView: Bool = false
    @State private var isStudyButtonPressed: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with deck name
                header
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // Stats cards
                statsRow
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                Divider()
                    .background(DS.inkFaint)
                    .padding(.leading, 32)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(DS.ink)
                        .scaleEffect(1.2)
                    Spacer()
                } else if cards.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                ModernCardRow(card: card)
                                    .onTapGesture {
                                        HapticManager.lightImpact()
                                    }
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                    .animation(
                                        DS.springGentle.delay(Double(index) * 0.03),
                                        value: cards.count
                                    )
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 120)
                    }
                }
            }

            // Study button
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [DS.surface.opacity(0), DS.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .allowsHitTesting(false)

                Button {
                    HapticManager.mediumImpact()
                    showingStudyView = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(DS.surface.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.surface)
                        }

                        Text(dueCount > 0 ? "Study \(dueCount) Due Cards" : "Study All Cards")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .tracking(0.3)
                    }
                    .foregroundStyle(DS.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(DS.ink)
                    )
                    .shadow(color: DS.ink.opacity(0.15), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
                .background(DS.surface)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingStudyView) {
            if let userId = authManager.userId {
                StudyView(deck: deck, userId: userId)
            }
        }
        .task {
            await loadCards()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(deck.name)
                .font(.system(size: 36, weight: .light, design: .rounded))
                .foregroundStyle(DS.ink)
                .tracking(-0.5)
                .lineLimit(2)

            if let description = deck.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DS.subtext)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                value: "\(deck.cardCount ?? cards.count)",
                label: "Total Cards",
                icon: "rectangle.stack.fill"
            )

            statCard(
                value: "\(dueCount)",
                label: dueCount == 1 ? "Due Card" : "Due Cards",
                icon: "clock.fill",
                isAccent: dueCount > 0
            )

            if let last = deck.lastStudied, last != "Never" {
                statCard(
                    value: last,
                    label: "Last Studied",
                    icon: "calendar.fill"
                )
            }
        }
    }

    private func statCard(value: String, label: String, icon: String, isAccent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isAccent ? DS.accent : DS.subtext)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.subtext)
                    .tracking(0.5)
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.ghost)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(DS.subtext.opacity(0.3))

            Text("No cards in this deck")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(DS.subtext)
                .tracking(0.2)
        }
        .transition(.opacity)
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

// MARK: - Modern Card Row

struct ModernCardRow: View {
    let card: Card

    @State private var isPressed: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Card icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.ghost)
                    .frame(width: 44, height: 44)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DS.ink.opacity(0.6))
            }

            // Card content
            VStack(alignment: .leading, spacing: 6) {
                Text(card.front)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)

                Text(card.back)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(DS.subtext)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.inkFaint, lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(DS.springSnappy, value: isPressed)
        ._onButtonGesture(pressing: { pressing in
            withAnimation(DS.springSnappy) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
