import Foundation
import Supabase

@Observable
final class AuthManager {

    var currentUser: User?
    var isLoading: Bool = false
    var errorMessage: String?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var userId: UUID? {
        currentUser?.id
    }

    init() {
        Task {
            await loadSession()
            await listenForAuthChanges()
        }
    }

    // MARK: - Session

    private func loadSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
        } catch {
            currentUser = nil
        }
    }

    private func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn, .tokenRefreshed, .userUpdated:
                currentUser = session?.user
            case .signedOut, .passwordRecovery:
                currentUser = nil
            default:
                break
            }
        }
    }

    // MARK: - Auth Actions

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            currentUser = session.user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            currentUser = response.user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
