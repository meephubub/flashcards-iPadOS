import SwiftUI

struct ContentView: View {

    @State private var authManager = AuthManager()
    @State private var selectedTab: Tab = .decks

    @State private var decks: [Deck] = []
    @State private var selectedDeckID: Int? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    enum Tab {
        case decks
        case calendar
    }

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ZStack(alignment: .bottom) {
                    TabView(selection: $selectedTab) {
                        DecksTabView(
                            decks: $decks,
                            selectedDeckID: $selectedDeckID,
                            columnVisibility: $columnVisibility
                        )
                        .tag(Tab.decks)

                        CalendarView()
                            .tag(Tab.calendar)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTab)

                    // Custom tab bar
                    customTabBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .task {
                    await loadDecks()
                    // Request notification permission
                    _ = await NotificationManager.shared.requestAuthorization()
                }

            } else {
                LoginView()
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                title: "Decks",
                icon: "rectangle.stack.fill",
                isSelected: selectedTab == .decks
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    selectedTab = .decks
                }
                HapticManager.lightImpact()
            }

            Spacer()

            TabBarButton(
                title: "Calendar",
                icon: "calendar.fill",
                isSelected: selectedTab == .calendar
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    selectedTab = .calendar
                }
                HapticManager.lightImpact()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
    }

    private func loadDecks() async {
        guard let userId = authManager.userId else { return }

        do {
            decks = try await DeckService.fetchDecks(for: userId)
        } catch {
            print("Failed to load decks:", error)
        }
    }
}

struct DecksTabView: View {
    @Binding var decks: [Deck]
    @Binding var selectedDeckID: Int?
    @Binding var columnVisibility: NavigationSplitViewVisibility

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {

            DecksListView(
                selectedDeckID: $selectedDeckID
            )

        } detail: {

            if let deckID = selectedDeckID,
               let deck = decks.first(where: { $0.id == deckID }) {
                DeckDetailContentView(deck: deck)
            } else {
                emptyDetail
            }
        }
        .navigationSplitViewStyle(.balanced)
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

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? DS.ink : DS.subtext)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(DS.springSnappy, value: isSelected)

                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? DS.ink : DS.subtext)
                    .tracking(0.3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? DS.ghost : Color.clear)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DS.springSnappy, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        ._onButtonGesture(pressing: { pressing in
            withAnimation(DS.springSnappy) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
