import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var selectedDeckID: Int? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    DecksListView(selectedDeck: $selectedDeck)
                } detail: {
                    if let deck = selectedDeck {
                        DeckDetailView(deck: deck)
                    } else {
                        emptyDetail
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                LoginView()
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
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

#Preview {
    ContentView()
        .environment(AuthManager())
}
