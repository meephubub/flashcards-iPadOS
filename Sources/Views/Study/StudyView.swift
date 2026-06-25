import SwiftUI

struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: StudyViewModel
    @State private var isExpanded: Bool = false

    init(deck: Deck, userId: UUID) {
        _viewModel = State(initialValue: StudyViewModel(deck: deck, userId: userId))
    }

    // MARK: - Adaptive colors

    private var bgColor: Color { DS.surface }
    private var surfaceColor: Color { DS.ghost }
    private var borderColor: Color { DS.inkFaint }
    private var secondaryText: Color { DS.subtext }
    private var timerWarningColor: Color { DS.ink }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                ProgressView()

            case .studying, .reviewing:
                if isFullscreen {
                    fullscreenStudyContent
                } else {
                    studyContent
                }

            case .finished:
                finishedView
            }
        }
        .navigationBarHidden(true)
        .animation(DS.expand, value: isFullscreen)
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
            topBar
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 32)

            Spacer()

            if let card = viewModel.currentCard {
                cardContent(card: card)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(card.id)
            }

            Spacer()

            bottomControls
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Text(viewModel.deck.name)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(DS.subtext)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    withAnimation(DS.expand) {
                        isFullscreen.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.subtext)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(DS.ghost)
                        )
                }

                Text("\(viewModel.cardsRemaining)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ink)

                Text(viewModel.timerString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.subtext)
                    .animation(.easeInOut, value: viewModel.secondsRemaining < 120)
            }
        }
    }

    // MARK: - Card content

    @ViewBuilder
    private func cardContent(card: Card) -> some View {
        VStack(spacing: isExpanded ? 32 : 24) {
            Text(card.front)
                .font(.system(size: isExpanded ? 42 : 30, weight: .medium, design: .rounded))
                .foregroundStyle(DS.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, isExpanded ? 80 : 40)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.isShowingAnswer {
                Text(card.back)
                    .font(.system(size: isExpanded ? 32 : 24, weight: .regular, design: .rounded))
                    .foregroundStyle(DS.inkLight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isExpanded ? 80 : 40)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DS.expand, value: isExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isShowingAnswer)
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 20) {
            if !viewModel.isShowingAnswer {
                showButton
            } else {
                ratingButtons
            }

            Button {
                HapticManager.lightImpact()
                dismiss()
            } label: {
                Text("Exit")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.subtext)
            }
        }
    }

    // MARK: - Show button

    private var showButton: some View {
        Button {
            withAnimation(DS.springGentle) {
                viewModel.showAnswer()
            }
        } label: {
            Text("Show Answer")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(DS.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(DS.ghost)
                )
        }
        .transition(.opacity)
    }

    // MARK: - Rating buttons

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(DS.springGentle) {
                    viewModel.rateCard(isGood: false)
                }
            } label: {
                VStack(spacing: 4) {
                    Text("Again")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.ink)
                    Text(viewModel.nextDueForAgain)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(DS.subtext)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(DS.ghost)
                )
            }

            Button {
                withAnimation(DS.springGentle) {
                    viewModel.rateCard(isGood: true)
                }
            } label: {
                VStack(spacing: 4) {
                    Text("Good")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.surface)
                    Text(viewModel.nextDueForGood)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(DS.surface.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(DS.accent)
                )
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Finished view

    private var finishedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DS.ink)

            VStack(spacing: 8) {
                Text("Session Complete")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.ink)

                Text("\(viewModel.cardsStudiedCount) cards studied")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(DS.subtext)
            }

            Button {
                HapticManager.lightImpact()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .frame(width: 140, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(DS.ghost)
                    )
            }
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
