import SwiftUI

// MARK: - LoginView

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var emailFocused: Bool = false
    @State private var passwordFocused: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // ── Left: Brand Panel ─────────────────────────────────────
                brandPanel
                    .frame(width: geo.size.width * 0.42)
                    .ignoresSafeArea()

                // Thin divider
                Rectangle()
                    .fill(DS.inkFaint)
                    .frame(width: 1)
                    .ignoresSafeArea()

                // ── Right: Form Panel ─────────────────────────────────────
                formPanel
                    .frame(maxWidth: .infinity)
            }
        }
        .background(DS.ghost.ignoresSafeArea())
        .onAppear {
            withAnimation(DS.springGentle.delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Brand Panel

    private var brandPanel: some View {
        ZStack {
            // Subtle grid texture
            DS.ghost
            gridTexture

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Large wordmark
                VStack(alignment: .leading, spacing: 16) {
                    Text("Flash\nCards")
                        .font(.custom("Canela-Light", size: 72).weight(.light))
                        .foregroundStyle(DS.ink)
                        .lineSpacing(4)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(DS.springGentle.delay(0.05), value: appeared)

                    Rectangle()
                        .fill(DS.accent)
                        .frame(width: appeared ? 56 : 0, height: 2)
                        .animation(DS.springGentle.delay(0.25), value: appeared)

                    Text("Learn anything.\nRemember everything.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(DS.subtext)
                        .lineSpacing(5)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.springGentle.delay(0.3), value: appeared)
                }

                Spacer()

                // Small version tag at bottom
                Text("v2.0")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(DS.subtext.opacity(0.5))
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.springGentle.delay(0.5), value: appeared)
            }
            .padding(.horizontal, 52)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Minimal dot-grid background
    private var gridTexture: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 28
            let dotR: CGFloat = 1
            for col in stride(from: 0.0, through: size.width, by: spacing) {
                for row in stride(from: 0.0, through: size.height, by: spacing) {
                    let rect = CGRect(x: col - dotR, y: row - dotR, width: dotR * 2, height: dotR * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(DS.ink.opacity(0.055)))
                }
            }
        }
    }

    // MARK: - Form Panel

    private var formPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 80)

                // Mode heading
                VStack(alignment: .leading, spacing: 8) {
                    Text(isSignUp ? "Create account" : "Welcome back")
                        .font(.custom("Canela-Light", size: 36))
                        .foregroundStyle(DS.ink)
                        .contentTransition(.opacity)
                        .animation(DS.springGentle, value: isSignUp)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(DS.springGentle.delay(0.15), value: appeared)

                    Text(isSignUp ? "Fill in your details to get started." : "Sign in to continue studying.")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(DS.subtext)
                        .contentTransition(.opacity)
                        .animation(DS.springGentle, value: isSignUp)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.springGentle.delay(0.2), value: appeared)
                }
                .padding(.bottom, 48)

                // Fields
                VStack(spacing: 0) {
                    FloatingLabelField(
                        label: "Email",
                        text: $email,
                        isSecure: false,
                        isFocused: $emailFocused
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(DS.springGentle.delay(0.25), value: appeared)

                    Divider().background(DS.inkFaint)

                    FloatingLabelField(
                        label: "Password",
                        text: $password,
                        isSecure: true,
                        isFocused: $passwordFocused
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(DS.springGentle.delay(0.32), value: appeared)

                    Divider().background(DS.inkFaint)
                }
                .padding(.bottom, 40)

                // Error message
                if let error = authManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 13))
                        Text(error)
                            .font(.system(size: 13, weight: .regular))
                    }
                    .foregroundStyle(Color(hex: "#C0392B"))
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Primary CTA
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
                                .tint(DS.ghost)
                                .scaleEffect(0.85)
                        } else {
                            HStack(spacing: 8) {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 14, weight: .semibold))
                                    .tracking(0.4)
                                    .contentTransition(.opacity)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(DS.ghost)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule().fill(
                            (authManager.isLoading || email.isEmpty || password.isEmpty)
                            ? DS.ink.opacity(0.3)
                            : DS.ink
                        )
                    )
                    .animation(DS.easeQuick, value: authManager.isLoading)
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                .buttonStyle(ScaleButtonStyle())
                .opacity(appeared ? 1 : 0)
                .animation(DS.springGentle.delay(0.38), value: appeared)
                .padding(.bottom, 28)

                // Toggle mode
                Button {
                    withAnimation(DS.springGentle) {
                        isSignUp.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(DS.subtext)
                        Text(isSignUp ? "Sign in" : "Sign up")
                            .foregroundStyle(DS.ink)
                            .underline(true, color: DS.accent)
                    }
                    .font(.system(size: 13, weight: .regular))
                    .contentTransition(.opacity)
                }
                .buttonStyle(ScaleButtonStyle())
                .opacity(appeared ? 1 : 0)
                .animation(DS.springGentle.delay(0.42), value: appeared)

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 56)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: authManager.errorMessage)
        }
        .background(DS.surface)
    }
}

// MARK: - Floating Label Field

struct FloatingLabelField: View {
    let label: String
    @Binding var text: String
    let isSecure: Bool
    @Binding var isFocused: Bool

    @State private var showPassword: Bool = false

    private var isFloating: Bool { isFocused || !text.isEmpty }

    var body: some View {
        ZStack(alignment: .leading) {
            // Floating label
            Text(label)
                .font(.system(
                    size: isFloating ? 10 : 15,
                    weight: isFloating ? .semibold : .light
                ))
                .tracking(isFloating ? 2 : 0)
                .foregroundStyle(
                    isFocused ? DS.accent : DS.subtext
                )
                .offset(y: isFloating ? -18 : 0)
                .animation(DS.springSnappy, value: isFloating)
                .animation(DS.easeQuick, value: isFocused)
                .allowsHitTesting(false)

            HStack {
                Group {
                    if isSecure && !showPassword {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                            .keyboardType(isSecure ? .default : .emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(DS.ink)
                .tint(DS.accent)
                .onTapGesture { isFocused = true }
                // Use FocusState in a real app; approximated here
                .onChange(of: text) { _, _ in
                    isFocused = !text.isEmpty
                }

                if isSecure {
                    Button {
                        withAnimation(DS.easeQuick) {
                            showPassword.toggle()
                        }
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.subtext)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.top, isFloating ? 14 : 0)
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
