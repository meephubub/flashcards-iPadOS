import SwiftUI

struct DecksListView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var decks: [Deck] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15, weight: .medium))

                TextField("Search decks", text: $searchText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if isLoading && decks.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") {
                        errorMessage = nil
                        Task { await loadDecks() }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
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
        .background(Color(.systemBackground))
        .navigationTitle("Decks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.lightImpact()
                    Task { await authManager.signOut() }
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "No decks yet" : "No results for \"\(searchText)\"")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        Spacer()
    }

    // MARK: - Data loading

    private func loadDecks() async {
        guard let userId = authManager.userId else {
            print("[v0] loadDecks: no userId, skipping")
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            print("[v0] loadDecks: fetching for userId=\(userId)")
            if searchText.isEmpty {
                decks = try await DeckService.fetchDecks(for: userId)
            } else {
                decks = try await DeckService.searchDecks(query: searchText, userId: userId)
            }
            print("[v0] loadDecks: got \(decks.count) decks")
        } catch {
            print("[v0] loadDecks error: \(error)")
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

    @State private var isPressed: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let count = deck.cardCount {
                        Label("\(count) cards", systemImage: "rectangle.on.rectangle")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    if let last = deck.lastStudied, last != "Never" {
                        Label(last, systemImage: "clock")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isPressed
                      ? Color(.secondarySystemBackground).opacity(0.7)
                      : Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
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
