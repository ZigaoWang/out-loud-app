import SwiftUI
import AVFoundation

@main
struct OutLoudApp: App {
    @StateObject private var supabase = SupabaseService.shared

    init() {
        requestPermissions()
    }

    var body: some Scene {
        WindowGroup {
            if supabase.isAuthenticated {
                DashboardView()
            } else {
                AuthView()
            }
        }
    }

    private func requestPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
}
