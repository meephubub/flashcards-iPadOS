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
        List(selection: $selectedDeckID) {
            ForEach(decks) { deck in
                DeckRowView(deck: deck)
                    .tag(deck.id)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(DS.surface)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .onChange(of: searchText) { _, new in debounceSearch(query: new) }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.lightImpact()
                    Task { await authManager.signOut() }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.subtext)
                }
                .accessibilityLabel("Sign Out")
            }
        }
        .overlay {
            if isLoading && decks.isEmpty {
                ProgressView()
                    .tint(DS.ink)
            } else if let error = errorMessage {
                errorState(error)
            } else if decks.isEmpty {
                emptyState
            }
        }
        .task {
            await loadDecks()
        }
        .refreshable {
            await loadDecks()
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "rectangle.stack" : "magnifyingglass")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(DS.subtext.opacity(0.4))
            Text(searchText.isEmpty ? "No decks" : "No results")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(DS.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(DS.subtext.opacity(0.4))
            Text("Error")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(DS.subtext)
            Button("Retry") {
                errorMessage = nil
                Task { await loadDecks() }
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(DS.ink)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Deck Row

struct DeckRowView: View {
    let deck: Deck

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)

                if let count = deck.cardCount {
                    Text("\(count) cards")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(DS.subtext)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DS.ghost)
        )
    }
}
