import SwiftUI

struct StudyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: StudyViewModel

    private let bgColor = Color(hex: "#0A0A0A")
    private let surfaceColor = Color(hex: "#1A1A1A")
    private let borderColor = Color(hex: "#2A2A2A")
    private let secondaryText = Color(hex: "#8A8A8A")

    init(deck: Deck, userId: UUID) {
        _viewModel = State(initialValue: StudyViewModel(deck: deck, userId: userId))
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                ProgressView()
                    .tint(.white)

            case .studying, .reviewing:
                studyContent

            case .finished:
                finishedView
            }
        }
        .navigationBarHidden(true)
        .task { await viewModel.load() }
        .onDisappear { viewModel.cancelTimer() }
        .onKeyPress(.space) {
            handleSpaceKey()
            return .handled
        }
        .onKeyPress("1") {
            if viewModel.isShowingAnswer { viewModel.rateCard(isGood: false) }
            return .handled
        }
    }

    // MARK: - Study content

    @ViewBuilder
    private var studyContent: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)

            Spacer()

            // Card
            if let card = viewModel.currentCard {
                cardContent(card: card)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(card.id)
            }

            Spacer()

            // Bottom controls
            bottomControls
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Text(viewModel.deck.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 16) {
                // Cards remaining pill
                Text("\(viewModel.cardsRemaining) left")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(surfaceColor)
                            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
                    )

                // Timer
                Text(viewModel.timerString)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(viewModel.secondsRemaining < 120 ? Color(hex: "#FF6B6B") : secondaryText)
                    .animation(.easeInOut, value: viewModel.secondsRemaining < 120)
            }
        }
    }

    // MARK: - Card content

    @ViewBuilder
    private func cardContent(card: Card) -> some View {
        VStack(spacing: 0) {
            // Front
            Text(card.front)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)

            // Divider + Back (revealed)
            if viewModel.isShowingAnswer {
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 1)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 28)
                    .transition(.opacity)

                Text(card.back)
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isShowingAnswer)
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 16) {
            if !viewModel.isShowingAnswer {
                // Show hint
                Text("space")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(secondaryText)

                showButton
            } else {
                // Rating hints
                HStack {
                    Text("1 → Again")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryText)
                    Spacer()
                    Text("space → Good")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryText)
                }

                ratingButtons
            }

            // Exit row
            HStack {
                Button {
                    HapticManager.lightImpact()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Exit")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(secondaryText)
                }

                Spacer()

                Text("esc Exit")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(borderColor)
            }
        }
    }

    // MARK: - Show button

    private var showButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.showAnswer()
            }
        } label: {
            Text("Show")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(hex: "#1C1C2E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
        }
        .transition(.opacity)
    }

    // MARK: - Rating buttons

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            // Again
            VStack(spacing: 6) {
                Text(viewModel.nextDueForAgain)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(secondaryText)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.rateCard(isGood: false)
                    }
                } label: {
                    Text("Again")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                                )
                        )
                }
            }

            // Good
            VStack(spacing: 6) {
                Text(viewModel.nextDueForGood)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(secondaryText)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.rateCard(isGood: true)
                    }
                } label: {
                    Text("Good")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color(hex: "#1C1C2E"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                        )
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Finished view

    private var finishedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.white)

            Text("Session Complete")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("\(viewModel.cardsStudiedCount) cards studied")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: "#8A8A8A"))

            Button {
                HapticManager.lightImpact()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 160, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(Color(hex: "#1C1C2E"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(Color(hex: "#2A2A2A"), lineWidth: 1)
                            )
                    )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Keyboard handler

    private func handleSpaceKey() {
        if viewModel.isShowingAnswer {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.rateCard(isGood: true)
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.showAnswer()
            }
        }
    }
}
