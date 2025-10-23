import SwiftUI
import AVFoundation

struct SessionDetailView: View {
    let session: SavedSession
    @Binding var isPresented: Bool
    @StateObject private var sessionManager = SessionManager.shared

    // Audio playback
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var timer: Timer?
    @State private var audioPlayerDelegate: AudioPlayerDelegateWrapper?

    private let theme = DashboardTheme.self

    var body: some View {
        ZStack {
            theme.surfaceSecondary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Audio Player Section
                    if session.audioFileName != nil {
                        audioPlayerCard
                    }

                    // Transcript Section
                    transcriptCard

                    // Analysis Section
                    if let analysis = session.analysis {
                        analysisCard(analysis)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle(session.displayTitle)
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Audio Player Card

    private var audioPlayerCard: some View {
        VStack(spacing: 20) {
            // Progress Bar
            progressBar

            // Time Display
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .monospacedDigit()

                Spacer()

                Text(formatTime(audioPlayer?.duration ?? session.duration))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .monospacedDigit()
            }

            // Play Controls
            HStack(spacing: 30) {
                // Skip Back 10s
                Button(action: { skip(-10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .foregroundColor(theme.textPrimary)
                }
                .disabled(audioPlayer == nil)

                // Play/Pause Button
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(audioPlayer == nil ? theme.textSecondary : theme.primary)
                            .frame(width: 60, height: 60)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .disabled(audioPlayer == nil)

                // Skip Forward 10s
                Button(action: { skip(10) }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                        .foregroundColor(theme.textPrimary)
                }
                .disabled(audioPlayer == nil)
            }
        }
        .padding(24)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.primary)
                    .frame(width: geometry.size.width * progressPercentage, height: 8)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard audioPlayer != nil else { return }
                        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                        seekTo(newProgress)
                    }
            )
        }
        .frame(height: 20)
    }

    // MARK: - Transcript Card

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                if isPlaying {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 8, height: 8)
                        Text("Playing")
                            .font(.caption)
                            .foregroundColor(theme.primary)
                    }
                }
            }

            // Display transcript with word highlighting
            if let segments = session.transcriptSegments, !segments.isEmpty {
                highlightedTranscript(segments: segments)
            } else {
                Text(session.transcript.isEmpty ? "No transcript available" : session.transcript)
                    .font(.body)
                    .foregroundColor(theme.textPrimary)
                    .lineSpacing(8)
            }
        }
        .padding(20)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func highlightedTranscript(segments: [TranscriptSegment]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(segments.indices, id: \.self) { segmentIndex in
                let segment = segments[segmentIndex]
                Text(buildWordHighlighting(for: segment))
                    .font(.body)
                    .lineSpacing(8)
            }
        }
        .animation(.easeInOut(duration: 0.1), value: currentTime)
    }

    private func buildWordHighlighting(for segment: TranscriptSegment) -> AttributedString {
        var result = AttributedString()

        for word in segment.words {
            // Validate word has proper timestamps
            guard word.startTime >= 0 && word.endTime > word.startTime else {
                // Fallback for invalid timestamps
                var wordText = AttributedString(word.word)
                wordText.foregroundColor = theme.textPrimary
                result.append(wordText)
                result.append(AttributedString(" "))
                continue
            }

            var wordText = AttributedString(word.word)

            // Calculate timing with tolerance
            let tolerance: Double = 0.05 // 50ms tolerance
            let isCurrentWord = isPlaying &&
                                currentTime >= (word.startTime - tolerance) &&
                                currentTime < (word.endTime + tolerance)
            let hasBeenSpoken = currentTime >= (word.endTime - tolerance)

            if isCurrentWord {
                // Highlight current word - bold, white text on blue background
                wordText.foregroundColor = .white
                wordText.backgroundColor = theme.primary
                wordText.font = .body.bold()
            } else if hasBeenSpoken {
                // Already spoken - dimmed gray
                wordText.foregroundColor = theme.textSecondary
            } else {
                // Not yet spoken - normal black
                wordText.foregroundColor = theme.textPrimary
            }

            result.append(wordText)
            result.append(AttributedString(" ")) // Space between words
        }

        return result
    }

    // MARK: - Analysis Card

    private func analysisCard(_ analysis: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Analysis")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            // Scores
            HStack(spacing: 12) {
                scoreCard(title: "Thinking", score: analysis.report.thinkingIntensity, color: theme.primary)
                scoreCard(title: "Coherence", score: analysis.report.coherenceScore, color: theme.secondary)
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
                    .lineSpacing(6)
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
        }
        .padding(20)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func scoreCard(title: String, score: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Text("\(score)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Audio Playback Logic

    private var progressPercentage: CGFloat {
        guard let player = audioPlayer, player.duration > 0 else { return 0 }
        return CGFloat(currentTime / player.duration)
    }

    private func setupAudioPlayer() {
        guard let audioURL = sessionManager.getAudioURL(for: session) else {
            print("❌ No audio URL for session")
            return
        }

        print("📂 Audio file path: \(audioURL.path)")

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file doesn't exist at: \(audioURL.path)")
            return
        }

        // Check file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let fileSize = attrs[.size] as? Int64 {
            print("📦 Audio file size: \(fileSize) bytes")

            // Validate file size
            guard fileSize > 1000 else {
                print("❌ Audio file too small, likely corrupted")
                return
            }
        }

        // Debug: Print first few word timestamps
        if let segments = session.transcriptSegments, let firstSegment = segments.first {
            print("🎯 Word timestamps (first 5):")
            for (index, word) in firstSegment.words.prefix(5).enumerated() {
                print("   \(index + 1). \"\(word.word)\" [\(String(format: "%.2f", word.startTime))s - \(String(format: "%.2f", word.endTime))s]")
            }
        }

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)

            // Create and configure player
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0

            // Create and store delegate
            audioPlayerDelegate = AudioPlayerDelegateWrapper(onFinish: { [self] in
                self.handlePlaybackFinished()
            })
            audioPlayer?.delegate = audioPlayerDelegate

            print("✅ Audio player ready - Duration: \(String(format: "%.2f", audioPlayer?.duration ?? 0))s")
        } catch {
            print("❌ Failed to setup audio player: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
        }
    }

    private func togglePlayback() {
        guard let player = audioPlayer else {
            print("❌ No audio player available, attempting to setup...")
            setupAudioPlayer()
            return
        }

        if isPlaying {
            player.pause()
            stopTimer()
            isPlaying = false
            print("⏸️ Paused at \(String(format: "%.2f", currentTime))s")
        } else {
            // If at the end, restart from beginning
            if currentTime >= player.duration - 0.1 {
                player.currentTime = 0
                currentTime = 0
                print("🔄 Restarting from beginning")
            }

            let success = player.play()
            if success {
                startTimer()
                isPlaying = true
                print("▶️ Playing from \(String(format: "%.2f", currentTime))s")
                print("   Volume: \(player.volume), Duration: \(String(format: "%.2f", player.duration))s")
                print("   isPlaying: \(player.isPlaying)")
            } else {
                print("❌ Failed to start playback")
            }
        }
    }

    private func startTimer() {
        stopTimer() // Clean up any existing timer

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
            guard let player = self.audioPlayer else { return }

            // Update current time
            let newTime = player.currentTime
            DispatchQueue.main.async {
                self.currentTime = newTime
            }

            // Debug: Print current word being highlighted (every 0.5s)
            if Int(newTime * 10) % 5 == 0 {
                if let segments = session.transcriptSegments, let firstSegment = segments.first {
                    let currentWord = firstSegment.words.first(where: { word in
                        newTime >= word.startTime && newTime < word.endTime
                    })
                    if let word = currentWord {
                        print("⏱️ \(String(format: "%.2f", newTime))s: \"\(word.word)\" [\(String(format: "%.2f", word.startTime))s-\(String(format: "%.2f", word.endTime))s]")
                    }
                }
            }

            // Check if playback finished
            if !player.isPlaying && player.currentTime > 0 {
                DispatchQueue.main.async {
                    self.handlePlaybackFinished()
                }
            }
        }

        // Ensure timer runs during UI interactions
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handlePlaybackFinished() {
        print("🏁 Playback finished")
        stopTimer()
        isPlaying = false
        // Keep currentTime at the end so user can see full transcript is highlighted
    }

    private func seekTo(_ percentage: Double) {
        guard let player = audioPlayer else { return }
        let newTime = player.duration * percentage
        player.currentTime = newTime
        currentTime = newTime
        print("⏩ Seeked to \(String(format: "%.2f", newTime))s")
    }

    private func skip(_ seconds: Double) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(player.duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
        print("⏭️ Skipped to \(String(format: "%.2f", newTime))s")
    }

    private func cleanup() {
        audioPlayer?.stop()
        audioPlayer?.delegate = nil
        audioPlayerDelegate = nil
        stopTimer()
        isPlaying = false
        currentTime = 0
        print("🧹 Cleaned up audio player")
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayer Delegate Helper

private class AudioPlayerDelegateWrapper: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎵 AVAudioPlayer finished playing, success: \(flag)")
        onFinish()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio player decode error: \(error?.localizedDescription ?? "unknown")")
    }
}
