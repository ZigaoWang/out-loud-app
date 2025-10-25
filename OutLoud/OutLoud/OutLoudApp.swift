import SwiftUI

@main
struct OutLoudApp: App {
    @StateObject private var supabase = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            if supabase.isAuthenticated {
                DashboardView()
            } else {
                AuthView()
            }
        }
    }
}
