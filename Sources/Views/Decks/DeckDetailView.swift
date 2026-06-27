import SwiftUI

// MARK: - Tag Tree Node

struct TagNode: Identifiable {
    let id: String        // full path e.g. "english/poetry"
    let label: String     // last component e.g. "poetry"
    var children: [TagNode] = []
    var decks: [Deck] = []

    var totalDeckCount: Int {
        decks.count + children.reduce(0) { $0 + $1.totalDeckCount }
    }
}

// MARK: - DecksListView

struct DecksListView: View {
    @Environment(AuthManager.self) private var authManager
    @Binding var selectedDeckID: Int?

    @State private var decks: [Deck] = []
    @State private var isLoading = true
    @State private var tagTree: [TagNode] = []
    @State private var expandedNodes: Set<String> = []
    @State private var headerVisible = false
    @State private var progressVisible = false
    @State private var contentVisible = false
    @State private var showAllDecks = false

    // Progress mock: fraction of due cards studied today
    var studiedFraction: Double {
        guard !decks.isEmpty else { return 0 }
        // Use lastStudied as a proxy; real impl would compare dueCount vs studied
        let studied = decks.filter { $0.lastStudied != nil && $0.lastStudied != "Never" }.count
        return Double(studied) / Double(decks.count)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var displayName: String {
        authManager.full_name ?? authManager.userId.map { _ in "there" } ?? "there"
    }

    var totalDue: Int {
        // Sum across all decks' due counts if available; placeholder
        decks.compactMap { $0.cardCount }.reduce(0, +)
    }

    var body: some View {
        ZStack {
            DS.surface.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Greeting ──────────────────────────────────────
                    greetingSection
                        .padding(.horizontal, 40)
                        .padding(.top, 48)
                        .padding(.bottom, 28)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 14)

                    // ── Progress bar ──────────────────────────────────
                    progressSection
                        .padding(.horizontal, 40)
                        .padding(.bottom, 32)
                        .opacity(progressVisible ? 1 : 0)
                        .offset(y: progressVisible ? 0 : 10)

                    // ── Study button ──────────────────────────────────
                    studyButton
                        .padding(.horizontal, 40)
                        .padding(.bottom, 44)
                        .opacity(progressVisible ? 1 : 0)

                    // ── Deck list ─────────────────────────────────────
                    deckSection
                        .padding(.horizontal, 40)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 12)

                    Spacer(minLength: 60)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .task {
            await loadDecks()
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(greeting), \(displayName)")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(DS.ink)
                .tracking(-0.3)

            Text(totalDue > 0 ? "\(totalDue) cards ready to review." : "Ready to study?")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(DS.subtext)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnimatedProgressBar(fraction: studiedFraction)
                .frame(height: 6)
        }
    }

    // MARK: - Study Button

    @State private var studyButtonPressed = false

    private var studyButton: some View {
        Button {
            HapticManager.mediumImpact()
        } label: {
            Text("Study")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(DS.surface)
                .frame(width: 100, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DS.ink)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Deck Section

    private var deckSection: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("DECKS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(DS.subtext)

                Spacer()

                if decks.count > 3 {
                    Button {
                        withAnimation(DS.springGentle) {
                            showAllDecks.toggle()
                        }
                        HapticManager.lightImpact()
                    } label: {
                        Text(showAllDecks ? "Show less" : "Show all \(decks.count)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.accent)
                    }
                }
            }
            .padding(.bottom, 16)

            if isLoading {
                deckSkeletonRows
            } else if tagTree.isEmpty {
                emptyState
            } else {
                tagTreeList
            }
        }
    }

    // MARK: - Tag Tree List

    private var tagTreeList: some View {
        VStack(spacing: 0) {
            let visibleNodes = showAllDecks ? tagTree : Array(tagTree.prefix(5))
            ForEach(Array(visibleNodes.enumerated()), id: \.element.id) { index, node in
                TagNodeRow(
                    node: node,
                    depth: 0,
                    expandedNodes: $expandedNodes,
                    selectedDeckID: $selectedDeckID,
                    animationDelay: Double(index) * 0.05
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))

                if index < visibleNodes.count - 1 {
                    Divider()
                        .background(DS.inkFaint)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }

    // MARK: - Skeleton

    private var deckSkeletonRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.ghost)
                        .frame(width: CGFloat.random(in: 60...120), height: 13)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.ghost)
                        .frame(width: 60, height: 13)
                }
                .padding(.vertical, 16)
                .shimmer()

                if i < 2 { Divider().background(DS.inkFaint) }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(DS.subtext.opacity(0.3))
            Text("No decks yet")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(DS.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Data

    private func loadDecks() async {
        guard let userId = authManager.userId else { isLoading = false; return }
        isLoading = true
        defer { isLoading = false }
        do {
            decks = try await DeckService.fetchDecks(for: userId)
            tagTree = buildTagTree(from: decks)
        } catch {}
    }

    /// Builds a tree from decks using their `tag` field.
    /// Tags like "english/poetry" create nested nodes.
    private func buildTagTree(from decks: [Deck]) -> [TagNode] {
        var roots: [String: TagNode] = [:]

        func insert(deck: Deck, into tree: inout [String: TagNode], pathComponents: [String], fullPath: String) {
            guard !pathComponents.isEmpty else { return }
            let component = pathComponents[0]
            let nodePath = fullPath.components(separatedBy: "/")
                .prefix(fullPath.components(separatedBy: "/").count - pathComponents.count + 1)
                .joined(separator: "/")

            if tree[component] == nil {
                tree[component] = TagNode(id: nodePath, label: component)
            }

            if pathComponents.count == 1 {
                tree[component]!.decks.append(deck)
            } else {
                let children = tree[component]!.children
                var childMap: [String: TagNode] = Dictionary(
                    uniqueKeysWithValues: children.map { ($0.label, $0) }
                )
                insert(deck: deck, into: &childMap, pathComponents: Array(pathComponents.dropFirst()), fullPath: fullPath)
                tree[component]!.children = childMap.values.sorted { $0.label < $1.label }
            }
        }

        for deck in decks {
            let tag = deck.tag ?? "uncategorised"
            let components = tag.split(separator: "/").map(String.init)
            insert(deck: deck, into: &roots, pathComponents: components, fullPath: tag)
        }

        return roots.values.sorted { $0.label < $1.label }
    }

    // MARK: - Animation

    private func animateIn() {
        withAnimation(DS.springGentle) { headerVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(DS.springGentle) { progressVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(DS.springGentle) { contentVisible = true }
        }
    }
}

// MARK: - Tag Node Row

struct TagNodeRow: View {
    let node: TagNode
    let depth: Int
    @Binding var expandedNodes: Set<String>
    @Binding var selectedDeckID: Int?
    var animationDelay: Double = 0

    @State private var appeared = false
    @State private var isPressed = false

    var isExpanded: Bool { expandedNodes.contains(node.id) }
    var hasChildren: Bool { !node.children.isEmpty }
    var indentWidth: CGFloat { CGFloat(depth) * 16 }

    var body: some View {
        VStack(spacing: 0) {
            // Row itself
            Button {
                HapticManager.lightImpact()
                withAnimation(DS.springSnappy) {
                    if isExpanded {
                        expandedNodes.remove(node.id)
                    } else {
                        expandedNodes.insert(node.id)
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    if depth > 0 {
                        // Indent guide line
                        HStack(spacing: 0) {
                            ForEach(0..<depth, id: \.self) { _ in
                                Rectangle()
                                    .fill(DS.inkFaint)
                                    .frame(width: 1)
                                    .padding(.leading, 8)
                                    .padding(.trailing, 7)
                            }
                        }
                    }

                    Text(node.label)
                        .font(.system(size: 15, weight: depth == 0 ? .regular : .light, design: .rounded))
                        .foregroundStyle(DS.ink)

                    Spacer()

                    HStack(spacing: 6) {
                        Text("\(node.totalDeckCount) \(node.totalDeckCount == 1 ? "deck" : "decks")")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(DS.subtext)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.subtext)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(DS.springSnappy, value: isExpanded)
                    }
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DS.springSnappy, value: isPressed)
            ._onButtonGesture(pressing: { pressing in
                withAnimation(DS.springSnappy) { isPressed = pressing }
            }, perform: {})

            // Expanded children
            if isExpanded {
                VStack(spacing: 0) {
                    // Direct decks
                    ForEach(node.decks) { deck in
                        DeckInlineRow(deck: deck, depth: depth + 1, selectedDeckID: $selectedDeckID)
                        Divider().background(DS.inkFaint)
                    }

                    // Child tag nodes
                    ForEach(Array(node.children.enumerated()), id: \.element.id) { idx, child in
                        TagNodeRow(
                            node: child,
                            depth: depth + 1,
                            expandedNodes: $expandedNodes,
                            selectedDeckID: $selectedDeckID
                        )
                        if idx < node.children.count - 1 {
                            Divider().background(DS.inkFaint)
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(DS.springGentle.delay(animationDelay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Deck Inline Row

struct DeckInlineRow: View {
    let deck: Deck
    let depth: Int
    @Binding var selectedDeckID: Int?

    @State private var isPressed = false
    @State private var navigating = false

    var body: some View {
        NavigationLink(destination: DeckDetailContentView(deck: deck)) {
            HStack(spacing: 0) {
                // Indent lines
                HStack(spacing: 0) {
                    ForEach(0..<depth, id: \.self) { _ in
                        Rectangle()
                            .fill(DS.inkFaint)
                            .frame(width: 1)
                            .padding(.leading, 8)
                            .padding(.trailing, 7)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.name)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(DS.ink)

                    if let desc = deck.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(DS.subtext)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let count = deck.cardCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.subtext)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(DS.ghost)
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.inkFaint)
                    .padding(.leading, 8)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(DS.springSnappy, value: isPressed)
        ._onButtonGesture(pressing: { pressing in
            withAnimation(DS.springSnappy) { isPressed = pressing }
            if pressing { HapticManager.lightImpact() }
        }, perform: {})
    }
}

// MARK: - Animated Progress Bar

struct AnimatedProgressBar: View {
    let fraction: Double

    @State private var animatedFraction: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(DS.ghost)
                    .frame(height: 6)

                // Fill
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DS.ink, DS.ink.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * animatedFraction, height: 6)
                    .animation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.3), value: animatedFraction)
            }
        }
        .onAppear {
            animatedFraction = max(fraction, fraction == 0 ? 0 : 0.04)
        }
        .onChange(of: fraction) { _, new in
            animatedFraction = new
        }
    }
}

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: DS.surface.opacity(0.5), location: phase),
                        .init(color: .clear, location: phase + 0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
