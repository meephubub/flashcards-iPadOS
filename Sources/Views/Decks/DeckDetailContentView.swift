import SwiftUI

struct DeckDetailContentView: View {
    let deck: Deck

    var body: some View {
        VStack(spacing: 20) {
            Text(deck.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DS.ink)

            if let description = deck.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DS.subtext)
            }

            if let cardCount = deck.cardCount {
                HStack {
                    Image(systemName: "rectangle.stack.fill")
                    Text("\(cardCount) cards")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.subtext)
            }

            Spacer()
        }
        .padding()
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
