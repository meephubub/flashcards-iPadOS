import SwiftUI

struct DecksListView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var decks: [Deck] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private let bgColor = Color(hex: "#0A0A0A")
    private let surfaceColor = Color(hex: "#1A1A1A")
    private let borderColor = Color(hex: "#2A2A2A")
    private let secondaryText = Color(hex: "#8A8A8A")

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(secondaryText)
                        .font(.system(size: 15, weight: .medium))

                    TextField("Search decks", text: $searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .onChange(of: searchText) { _, new in
                            debounceSearch(query: new)
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(surfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isLoading && decks.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if decks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(decks) { deck in
                                NavigationLink(destination: DeckDetailView(deck: deck)) {
                                    DeckRowView(deck: deck)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                    .refreshable {
                        await loadDecks()
                    }
                }
            }
        }
        .navigationTitle("Decks")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(bgColor, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.lightImpact()
                    Task { await authManager.signOut() }
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(secondaryText)
                }
            }
        }
        .task {
            await loadDecks()
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        Spacer()
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "rectangle.stack" : "magnifyingglass")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(secondaryText)

            Text(searchText.isEmpty ? "No decks yet" : "No results for \"\(searchText)\"")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(secondaryText)
        }
        Spacer()
    }

    // MARK: - Data loading

    private func loadDecks() async {
        guard let userId = authManager.userId else { return }
        isLoading = true
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

// MARK: - Deck Row

struct DeckRowView: View {
    let deck: Deck

    private let surfaceColor = Color(hex: "#1A1A1A")
    private let borderColor = Color(hex: "#2A2A2A")
    private let secondaryText = Color(hex: "#8A8A8A")

    @State private var isPressed: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let count = deck.cardCount {
                        Label("\(count) cards", systemImage: "rectangle.on.rectangle")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                    }

                    if let last = deck.lastStudied {
                        Label(DateFormatter.lastStudiedFormatter.string(from: last), systemImage: "clock")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isPressed ? Color(hex: "#222222") : surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
            if pressing { HapticManager.selectionChanged() }
        }, perform: {})
        .padding(.vertical, 4)
    }
}
