import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Text("FLASHCARDS")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ContentView()
}
