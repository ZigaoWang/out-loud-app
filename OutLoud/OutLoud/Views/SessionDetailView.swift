import SwiftUI
import AVFoundation

struct SessionDetailView: View {
    let session: SavedSession
    @Binding var isPresented: Bool
    @StateObject private var sessionManager = SessionManager.shared
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var highlightedWordIndex: Int?
    @Environment(\.presentationMode) var presentationMode

    private let theme = DashboardTheme.self

    var body: some View {
        ZStack {
            theme.surfaceSecondary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Audio Player
                    if session.audioFileName != nil {
                        audioPlayerSection
                    }

                    // Transcript with synced highlighting
                    transcriptSection

                    // Analysis
                    if let analysis = session.analysis {
                        analysisSection(analysis)
                    }

                    // Follow-up sessions
                    if let followUpIds = session.followUpSessionIds, !followUpIds.isEmpty {
                        followUpSection(followUpIds)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle(session.displayTitle)
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Audio Player

    private var audioPlayerSection: some View {
        VStack(spacing: 16) {
            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.primary)
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newProgress = value.location.x / geometry.size.width
                                seekTo(progress: max(0, min(1, newProgress)))
                            }
                    )
                }
                .frame(height: 20)

                // Time labels
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .monospacedDigit()

                    Spacer()

                    Text(formatTime(session.duration))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .monospacedDigit()
                }
            }

            // Playback controls
            HStack(spacing: 40) {
                // Play/Pause
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 56, height: 56)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }

                // Skip forward 10s
                Button(action: { skipTime(10) }) {
                    Text("+10s")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(20)
        .background(theme.surfaceSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if isPlaying {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.caption)
                            .foregroundColor(theme.primary)
                    }
                }
            }

            if let segments = session.transcriptSegments, !segments.isEmpty {
                // Word-level synced transcript
                syncedTranscriptView(segments: segments)
                    .padding(16)
                    .background(theme.surfaceSecondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Plain transcript
                Text(session.transcript.isEmpty ? "No transcript available" : session.transcript)
                    .font(.body)
                    .foregroundColor(theme.textPrimary)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(theme.surfaceSecondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func syncedTranscriptView(segments: [TranscriptSegment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { segmentIndex, segment in
                Text(buildAttributedString(for: segment, segmentIndex: segmentIndex))
                    .font(.body)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .id(currentTime) // Force refresh when currentTime changes
    }

    private func buildAttributedString(for segment: TranscriptSegment, segmentIndex: Int) -> AttributedString {
        var result = AttributedString()

        for (wordIndex, word) in segment.words.enumerated() {
            var wordString = AttributedString(word.word + " ")

            // Highlight current word during playback based on timestamp
            if isPlaying && currentTime >= word.startTime && currentTime < word.endTime {
                wordString.foregroundColor = .white
                wordString.backgroundColor = theme.primary
                wordString.font = .body.bold()
            } else if currentTime >= word.endTime {
                // Already played - slightly dimmed
                wordString.foregroundColor = theme.textSecondary
            } else {
                // Not yet played
                wordString.foregroundColor = theme.textPrimary
            }

            result.append(wordString)
        }

        return result
    }

    // MARK: - Analysis

    private func analysisSection(_ analysis: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                // Scores
                HStack(spacing: 12) {
                    ScoreCard(
                        title: "Thinking",
                        score: analysis.report.thinkingIntensity,
                        color: theme.primary
                    )

                    ScoreCard(
                        title: "Coherence",
                        score: analysis.report.coherenceScore,
                        color: theme.secondary
                    )
                }

                Divider()

                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textSecondary)

                    Text(analysis.summary)
                        .font(.body)
                        .foregroundColor(theme.textPrimary)
                        .lineSpacing(4)
                }

                // Keywords
                if !analysis.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keywords")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)

                        FlowLayout(spacing: 8) {
                            ForEach(analysis.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(theme.primary.opacity(0.1))
                                    .foregroundColor(theme.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Feedback
                if !analysis.feedback.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)

                        Text(analysis.feedback)
                            .font(.body)
                            .foregroundColor(theme.textPrimary)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(16)
            .background(theme.surfaceSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Follow-up Sessions

    private func followUpSection(_ followUpIds: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Follow-up Sessions")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            VStack(spacing: 8) {
                ForEach(followUpIds, id: \.self) { followUpId in
                    if let followUp = sessionManager.savedSessions.first(where: { $0.id == followUpId }) {
                        SessionRow(session: followUp)
                    }
                }
            }
        }
    }

    // MARK: - Audio Control

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

    private func seekTo(progress: CGFloat) {
        let newTime = session.duration * Double(progress)
        audioPlayer?.currentTime = newTime
        currentTime = newTime
    }

    private func skipTime(_ seconds: Double) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(session.duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
    }

    private func setupAudioPlayer() {
        guard let audioURL = sessionManager.getAudioURL(for: session) else {
            print("Audio URL not found for session")
            return
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Audio file does not exist at path: \(audioURL.path)")
            return
        }

        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = nil
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            print("Audio player setup successful. Duration: \(audioPlayer?.duration ?? 0)s, File: \(audioURL.lastPathComponent)")
        } catch {
            print("Failed to setup audio player: \(error)")
        }
    }

    private func startTimer() {
        timer?.invalidate() // Invalidate any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }

            self.currentTime = player.currentTime

            // Check if playback finished
            if !player.isPlaying && player.currentTime >= player.duration - 0.1 {
                self.stopPlayback()
            }
        }

        // Ensure timer runs even during UI interactions
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Score Card

struct ScoreCard: View {
    let title: String
    let score: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(score)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(DashboardTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

