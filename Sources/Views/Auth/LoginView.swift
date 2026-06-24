import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var showError: Bool = false

    // Adaptive design constants
    private let bgColor = Color(.systemBackground)
    private let surfaceColor = Color(.secondarySystemBackground)
    private let borderColor = Color(.separator).opacity(0.5)
    private let secondaryText = Color(.secondaryLabel)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App title
                VStack(spacing: 8) {
                    Text("FLASHCARDS")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .tracking(6)

                    Text(isSignUp ? "Create your account" : "Welcome back")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(secondaryText)
                }
                .padding(.bottom, 56)

                // Input fields
                VStack(spacing: 12) {
                    fieldInput(placeholder: "Email", text: $email, isSecure: false)
                    fieldInput(placeholder: "Password", text: $password, isSecure: true)
                }
                .padding(.bottom, 20)

                // Error message
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(.systemRed))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Primary action button
                Button {
                    HapticManager.lightImpact()
                    Task {
                        if isSignUp {
                            await authManager.signUp(email: email, password: password)
                        } else {
                            await authManager.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    ZStack {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(Color(.systemBackground))
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(.systemBackground))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(.label))
                    )
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                // Toggle sign in / sign up
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSignUp.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(secondaryText)
                        Text(isSignUp ? "Sign In" : "Sign Up")
                            .foregroundStyle(.primary)
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                }

                Spacer()
            }
            .padding(.horizontal, 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authManager.errorMessage)
        }
    }

    @ViewBuilder
    private func fieldInput(placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 16, weight: .regular, design: .rounded))
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
