import Foundation
import Supabase

// MARK: - Replace with your actual Supabase project credentials
private let supabaseURL = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
private let supabaseAnonKey = "YOUR_ANON_KEY"

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseAnonKey
)
