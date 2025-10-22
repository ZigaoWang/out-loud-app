import SwiftUI
import AVFoundation

private enum DashboardTheme {
    static let primary = Color(red: 0.32, green: 0.45, blue: 0.91)
    static let secondary = Color(red: 0.31, green: 0.68, blue: 0.59)
    static let accent = Color(red: 0.88, green: 0.54, blue: 0.32)
    static let surface = Color(.systemBackground)
    static let surfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.55)
}

struct DashboardView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var navigateToSession = false
    @State private var selectedSession: SavedSession?

    var body: some View {
        NavigationView {
            ZStack {
                DashboardTheme.surfaceSecondary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        statsSection
                        startButton

                        if !sessionManager.savedSessions.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                NavigationLink(
                    destination: SessionView(),
                    isActive: $navigateToSession
                ) {
                    EmptyView()
                }

                if let session = selectedSession {
                    SessionDetailView(session: session, isPresented: Binding(
                        get: { selectedSession != nil },
                        set: { if !$0 { selectedSession = nil } }
                    ))
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Out Loud")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(DashboardTheme.textPrimary)

            Text("讲出来,才能真正学会")
                .font(.subheadline)
                .foregroundColor(DashboardTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Time",
                value: sessionManager.formattedTotalTime,
                icon: "clock.fill",
                color: DashboardTheme.primary
            )

            StatCard(
                title: "Sessions",
                value: "\(sessionManager.sessionCount)",
                icon: "mic.fill",
                color: DashboardTheme.secondary
            )
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: {
            navigateToSession = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 24, weight: .semibold))

                Text("Start New Session")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        DashboardTheme.primary,
                        DashboardTheme.primary.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: DashboardTheme.primary.opacity(0.3), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundColor(DashboardTheme.textPrimary)

            VStack(spacing: 12) {
                ForEach(sessionManager.savedSessions.prefix(10)) { session in
                    SessionRow(session: session)
                        .onTapGesture {
                            selectedSession = session
                        }
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DashboardTheme.textPrimary)

            Text(title)
                .font(.subheadline)
                .foregroundColor(DashboardTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DashboardTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SavedSession

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(DashboardTheme.primary.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DashboardTheme.primary)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(session.formattedDate)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DashboardTheme.textPrimary)

                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(DashboardTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DashboardTheme.textTertiary)
        }
        .padding(16)
        .background(DashboardTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: SavedSession
    @Binding var isPresented: Bool
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    stopPlayback()
                    isPresented = false
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.formattedDate)
                                .font(.headline)
                                .foregroundColor(DashboardTheme.textPrimary)

                            Text(session.formattedDuration)
                                .font(.subheadline)
                                .foregroundColor(DashboardTheme.textSecondary)
                        }

                        Spacer()

                        Button(action: {
                            stopPlayback()
                            isPresented = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(DashboardTheme.textTertiary)
                        }
                    }

                    // Audio Player
                    if session.audioFileName != nil {
                        audioPlayerSection
                    }

                    Divider()

                    // Transcript
                    ScrollView {
                        Text(session.transcript)
                            .font(.body)
                            .foregroundColor(DashboardTheme.textPrimary)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                }
                .padding(24)
                .background(DashboardTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private var audioPlayerSection: some View {
        VStack(spacing: 16) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(DashboardTheme.surfaceSecondary)
                        .frame(height: 4)
                        .clipShape(Capsule())

                    Rectangle()
                        .fill(DashboardTheme.primary)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .clipShape(Capsule())
                }
            }
            .frame(height: 4)

            // Controls
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(DashboardTheme.textSecondary)

                Spacer()

                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DashboardTheme.primary)
                }

                Spacer()

                Text(formatTime(session.duration))
                    .font(.caption)
                    .foregroundColor(DashboardTheme.textSecondary)
            }
        }
        .padding(16)
        .background(DashboardTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progress: CGFloat {
        guard session.duration > 0 else { return 0 }
        return CGFloat(currentTime / session.duration)
    }

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            timer?.invalidate()
            isPlaying = false
        } else {
            if audioPlayer == nil {
                setupAudioPlayer()
            }
            audioPlayer?.play()
            startTimer()
            isPlaying = true
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        timer?.invalidate()
        isPlaying = false
        currentTime = 0
    }

    private func setupAudioPlayer() {
        guard let audioURL = SessionManager.shared.getAudioURL(for: session) else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to setup audio player: \(error)")
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                currentTime = player.currentTime

                if !player.isPlaying {
                    stopPlayback()
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
