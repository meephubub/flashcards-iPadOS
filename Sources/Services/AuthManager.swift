import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AuthManager {

    // MARK: - State

    var currentUser: User?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed Properties

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var userId: UUID? {
        currentUser?.id
    }

    var email: String? {
        currentUser?.email
    }

    var username: String? {
        currentUser?.userMetadata["user_name"]?.stringValue
    }

    var full_name: String? {
        currentUser?.userMetadata["full_name"]?.stringValue
    }

    var avatarUrl: URL? {
        currentUser?.userMetadata["avatar_url"]?.urlValue
    }

    // MARK: - Initialisation

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

            case .signedOut:
                currentUser = nil

            case .passwordRecovery:
                break

            default:
                break
            }
        }
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

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
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )

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
