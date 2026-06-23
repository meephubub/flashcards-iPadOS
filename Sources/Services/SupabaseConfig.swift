import Foundation
import Supabase

// MARK: - Replace with your actual Supabase project credentials
private let supabaseURL = URL(string: "https://jouowhbhiuuewfwpntex.supabase.co")!
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpvdW93aGJoaXV1ZXdmd3BudGV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY5NzQwODIsImV4cCI6MjA2MjU1MDA4Mn0.LeXWS-Zsdwev-eNHx2AoNxJLALq56LIUw-jzeUMymbE"

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseAnonKey
)
