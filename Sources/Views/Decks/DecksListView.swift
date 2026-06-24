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
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search decks")
        .onChange(of: searchText) { _, new in debounceSearch(query: new) }
        .navigationTitle("Decks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.lightImpact()
                    Task { await authManager.signOut() }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Sign Out")
            }
        }
        .overlay {
            if isLoading && decks.isEmpty {
                ProgressView()
                    .tint(.secondary)
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
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "rectangle.stack" : "magnifyingglass")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color(.tertiaryLabel))
            Text(searchText.isEmpty ? "No decks yet" : "No results for \"\(searchText)\"")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color(.tertiaryLabel))
            Text(message)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                errorMessage = nil
                Task { await loadDecks() }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.top, 8)
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let count = deck.cardCount {
                        Text("\(count) cards")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    if let last = deck.lastStudied, last != "Never" {
                        Text("• \(last)")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}
