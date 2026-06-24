import SwiftUI

struct ContentView: View {

    @State private var authManager = AuthManager()

    @State private var decks: [Deck] = []
    @State private var selectedDeckID: Int? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        Group {
            if authManager.isAuthenticated {

                NavigationSplitView(columnVisibility: $columnVisibility) {

                    DecksListView(
                        decks: decks,
                        selectedDeckID: $selectedDeckID
                    )

                } detail: {

                    if let deckID = selectedDeckID,
                       let deck = decks.first(where: { $0.id == deckID }) {
                        DeckDetailView(deck: deck)
                    } else {
                        emptyDetail
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .task {
                    await loadDecks()
                }

            } else {
                LoginView()
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }

    private func loadDecks() async {
        guard let userId = authManager.userId else { return }

        do {
            decks = try await DeckService.fetchDecks(for: userId)
        } catch {
            print("Failed to load decks:", error)
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(Color(.tertiaryLabel))

            Text("Select a deck")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
