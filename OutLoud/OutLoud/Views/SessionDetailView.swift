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

    // Edit title
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showDeleteConfirmation = false
    @Environment(\.presentationMode) var presentationMode

    private let theme = DashboardTheme.self

    private var currentSession: SavedSession {
        sessionManager.savedSessions.first(where: { $0.id == session.id }) ?? session
    }

    var body: some View {
        ZStack {
            theme.surfaceSecondary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Audio Player Section
                    if currentSession.audioFileName != nil {
                        audioPlayerCard
                    }

                    // Transcript Section
                    transcriptCard

                    // Analysis Section
                    if let analysis = currentSession.analysis {
                        analysisCard(analysis)
                    }
                }
                .padding(.horizontal, adaptivePadding)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: 900)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle(currentSession.displayTitle)
        .toolbar {
            Menu {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .alert("Delete Session", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                sessionManager.deleteSession(currentSession)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
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

                Text(formatTime(audioPlayer?.duration ?? currentSession.duration))
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
            if let segments = currentSession.transcriptSegments, !segments.isEmpty {
                highlightedTranscript(segments: segments)
            } else {
                Text(currentSession.transcript.isEmpty ? "No transcript available" : currentSession.transcript)
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                wordText.foregroundColor = .white
                wordText.backgroundColor = theme.primary
            } else if hasBeenSpoken {
                wordText.foregroundColor = theme.textSecondary
            } else {
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
        guard let audioPath = currentSession.audioFileName,
              let audioURL = SupabaseService.shared.getAudioURL(path: audioPath) else {
            print("⚠️ No audio file available")
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: audioURL)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
                try data.write(to: tempURL)

                await MainActor.run {
                    do {
                        let player = try AVAudioPlayer(contentsOf: tempURL)
                        player.prepareToPlay()
                        self.audioPlayer = player

                        let wrapper = AudioPlayerDelegateWrapper {
                            Task { @MainActor in
                                self.handlePlaybackFinished()
                            }
                        }
                        self.audioPlayerDelegate = wrapper
                        player.delegate = wrapper
                        print("✅ Audio player ready")
                    } catch {
                        print("❌ Failed to create audio player: \(error)")
                    }
                }
            } catch {
                print("❌ Failed to download audio: \(error)")
            }
        }
    }

    private func togglePlayback() {
        guard let player = audioPlayer else { return }

        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            currentTime = audioPlayer?.currentTime ?? 0
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handlePlaybackFinished() {
        isPlaying = false
        stopTimer()
        currentTime = 0
        audioPlayer?.currentTime = 0
    }

    private func seekTo(_ percentage: Double) {
        guard let player = audioPlayer else { return }
        let newTime = player.duration * percentage
        player.currentTime = newTime
        currentTime = newTime
    }

    private func skip(_ seconds: Double) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(player.duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
    }

    private func cleanup() {
        audioPlayer?.stop()
        stopTimer()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var adaptivePadding: CGFloat {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20
        #else
        return 40
        #endif
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
