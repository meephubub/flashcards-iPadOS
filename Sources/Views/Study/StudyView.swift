import SwiftUI
import Down
import UIKit

struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: StudyViewModel

    init(deck: Deck, userId: UUID) {
        _viewModel = State(initialValue: StudyViewModel(deck: deck, userId: userId))
    }

    // MARK: - Adaptive colors

    private var bgColor: Color { Color(.systemBackground) }
    private var surfaceColor: Color { Color(.secondarySystemBackground) }
    private var borderColor: Color { Color(.separator).opacity(0.5) }
    private var secondaryText: Color { Color(.secondaryLabel) }
    private var timerWarningColor: Color { Color(.systemRed) }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                ProgressView()

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
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)

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
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Text(viewModel.deck.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 16) {
                Text("\(viewModel.cardsRemaining) left")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(surfaceColor)
                            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
                    )

                Text(viewModel.timerString)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(viewModel.secondsRemaining < 120 ? timerWarningColor : secondaryText)
                    .animation(.easeInOut, value: viewModel.secondsRemaining < 120)
            }
        }
    }

    // MARK: - Card content

    @ViewBuilder
    private func cardContent(card: Card) -> some View {
        VStack(spacing: 0) {
            MarkdownView(markdown: card.front, fontSize: 28, isBold: true)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.isShowingAnswer {
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 1)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 28)
                    .transition(.opacity)

                MarkdownView(markdown: card.back, fontSize: 22, isBold: false)
                    .foregroundStyle(.secondary)
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
                Text("space")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryText)

                showButton
            } else {
                HStack {
                    Text("1 → Again")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(secondaryText)
                    Spacer()
                    Text("space → Good")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(secondaryText)
                }

                ratingButtons
            }

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
                    .foregroundStyle(secondaryText)
                }

                Spacer()

                Text("esc Exit")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(.tertiaryLabel))
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
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(surfaceColor)
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
            VStack(spacing: 6) {
                Text(viewModel.nextDueForAgain)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryText)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.rateCard(isGood: false)
                    }
                } label: {
                    Text("Again")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(surfaceColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(Color(.systemRed).opacity(0.4), lineWidth: 1.5)
                                )
                        )
                }
            }

            VStack(spacing: 6) {
                Text(viewModel.nextDueForGood)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryText)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.rateCard(isGood: true)
                    }
                } label: {
                    Text("Good")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color(.label))
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
                .foregroundStyle(Color(.secondaryLabel))

            Text("Session Complete")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("\(viewModel.cardsStudiedCount) cards studied")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                HapticManager.lightImpact()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 160, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(surfaceColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
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

// MARK: - Markdown View Wrapper

struct MarkdownView: UIViewRepresentable {
    let markdown: String
    let fontSize: CGFloat
    let isBold: Bool

    func makeUIView(context: Context) -> DownView {
        let downView = DownView(frame: .zero)
        downView.backgroundColor = .clear
        return downView
    }

    func updateUIView(_ uiView: DownView, context: Context) {
        let markdownString = Down(markdownString: markdown)
        let styling = DownStyler(
            baseFontSize: fontSize,
            baseFontColor: .label,
            codeFontName: "Menlo",
            quoteFontName: "Georgia",
            strongFontName: isBold ? ".systemRounded" : nil
        )
        uiView.downStyler = styling

        do {
            let attributedString = try markdownString.toAttributedString(styler: styling)
            uiView.attributedString = attributedString
        } catch {
            // Fallback to plain text if markdown parsing fails
            let plainString = NSAttributedString(
                string: markdown,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: isBold ? .bold : .regular)
                ]
            )
            uiView.attributedString = plainString
        }
    }
}
