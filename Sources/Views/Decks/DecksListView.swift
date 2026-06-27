import SwiftUI

struct DecksListView: View {
    @Environment(AuthManager.self) private var authManager
    @Binding var selectedDeckID: Int?
    @State private var decks: [Deck] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            DS.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Search bar
                searchBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                Divider()
                    .background(DS.inkFaint)
                    .padding(.leading, 24)

                if isLoading && decks.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(DS.ink)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    errorState(error)
                    Spacer()
                } else if decks.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(decks.enumerated()), id: \.element.id) { index, deck in
                                ModernDeckRow(deck: deck, isSelected: selectedDeckID == deck.id)
                                    .onTapGesture {
                                        withAnimation(DS.springSnappy) {
                                            selectedDeckID = deck.id
                                        }
                                        HapticManager.lightImpact()
                                    }
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                    .animation(
                                        DS.springGentle.delay(Double(index) * 0.05),
                                        value: decks.count
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }

                Spacer()

                // Sign out button
                signOutButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .task {
            await loadDecks()
        }
        .onChange(of: searchText) { _, new in debounceSearch(query: new) }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Decks")
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundStyle(DS.ink)
                .tracking(-0.5)
            Spacer()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.subtext)

            TextField("Search decks", text: $searchText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DS.ink)
                .tint(DS.accent)

            if !searchText.isEmpty {
                Button {
                    withAnimation(DS.springSnappy) {
                        searchText = ""
                    }
                    HapticManager.lightImpact()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.subtext)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DS.ghost)
        )
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            HapticManager.lightImpact()
            Task { await authManager.signOut() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .medium))
                Text("Sign Out")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(DS.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DS.ghost)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "rectangle.stack" : "magnifyingglass")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(DS.subtext.opacity(0.3))
                .scaleEffect(1.0)
                .animation(DS.springGentle, value: searchText.isEmpty)
            Text(searchText.isEmpty ? "No decks yet" : "No results found")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(DS.subtext)
                .tracking(0.2)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(DS.subtext.opacity(0.3))
            Text("Something went wrong")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(DS.subtext)
                .tracking(0.2)
            Button("Try again") {
                errorMessage = nil
                Task { await loadDecks() }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(DS.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.ghost)
            )
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    // MARK: - Data loading

    private func loadDecks() async {
        guard let userId = authManager.userId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if searchText.isEmpty {
                decks = try await DeckService.fetchDecks(for: userId)
            } else {
                decks = try await DeckService.searchDecks(query: searchText, userId: userId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func debounceSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await loadDecks()
            }
        }
    }
}

// MARK: - Modern Deck Row

struct ModernDeckRow: View {
    let deck: Deck
    let isSelected: Bool

    @State private var isPressed: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Deck icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? DS.ink : DS.ghost)
                    .frame(width: 44, height: 44)

                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? DS.surface : DS.ink.opacity(0.6))
            }
            .animation(DS.springSnappy, value: isSelected)

            // Deck info
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .animation(DS.springSnappy, value: isSelected)

                if let count = deck.cardCount {
                    HStack(spacing: 4) {
                        Text("\(count)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.subtext)
                        Text("cards")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(DS.subtext)
                    }
                }
            }

            Spacer()

            // Selection indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.subtext.opacity(isSelected ? 0.8 : 0.3))
                .scaleEffect(isSelected ? 1.0 : 0.8)
                .animation(DS.springSnappy, value: isSelected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? DS.ghost : DS.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? DS.inkFaint : Color.clear, lineWidth: 1)
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
