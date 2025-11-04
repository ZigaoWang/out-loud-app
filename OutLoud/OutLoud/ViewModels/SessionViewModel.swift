import Foundation
import Combine

class SessionViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var fullTranscript: String = ""
    @Published var analysisResult: AnalysisResult?
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0
    @Published var elapsedTime: TimeInterval = 0

    private var session: Session
    private let audioService: AudioRecordingService
    private let webSocketService: WebSocketService
    private let supabaseService: SupabaseService
    private var durationTimer: Timer?
    private var recordingPreparationWorkItem: DispatchWorkItem?
    private var ignoreInitialTranscriptWorkItem: DispatchWorkItem?
    private var isIgnoringInitialTranscript = false
    private let parentSessionId: String?

    init(
        serverURL: String = AppConstants.Network.defaultWebSocketURL,
        parentSessionId: String? = nil,
        supabaseService: SupabaseService = .shared
    ) {
        self.session = Session()
        self.audioService = AudioRecordingService()
        self.webSocketService = WebSocketService(serverURL: serverURL)
        self.supabaseService = supabaseService
        self.parentSessionId = parentSessionId

        setupServices()
    }

    private func setupServices() {
        // Audio callback
        audioService.onAudioBuffer = { [weak self] data in
            self?.webSocketService.sendAudio(data)
        }

        // Audio level callback
        audioService.onAudioLevel = { [weak self] level in
            self?.audioLevel = level
        }

        // Auto-start recording after WebSocket connects and a short preparation delay
        webSocketService.onConnected = { [weak self] in
            self?.beginRecordingWithDelay()
        }

        // WebSocket callbacks
        webSocketService.onTranscript = { [weak self] text, isFinal in
            DispatchQueue.main.async {
                guard let self = self, !self.isIgnoringInitialTranscript else { return }
                self.fullTranscript = text
                if isFinal {
                    self.session.transcript = text
                }
            }
        }

        webSocketService.onAnalysis = { [weak self] analysis, words in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.analysisResult = analysis
                self.state = .completed

                // Convert words to transcript segments
                var segments: [TranscriptSegment]? = nil
                if let words = words, !words.isEmpty {
                    let text = words.map { $0.word }.joined(separator: " ")
                    let segment = TranscriptSegment(
                        text: text,
                        words: words,
                        startTime: words.first?.startTime ?? 0,
                        endTime: words.last?.endTime ?? 0
                    )
                    segments = [segment]
                }

                // Save session
                SessionManager.shared.saveSession(
                    self.session,
                    analysis: analysis,
                    audioURL: self.session.audioFileURL,
                    transcriptSegments: segments,
                    parentSessionId: self.parentSessionId
                )
            }
        }

        webSocketService.onReconnecting = { [weak self] in
            DispatchQueue.main.async {
                self?.errorMessage = "Reconnecting..."
            }
        }

        webSocketService.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error
                if error.contains("restart session") {
                    self?.state = .idle
                }
            }
        }
    }

    func startSession() {
        guard supabaseService.isAuthenticated else {
            errorMessage = "Please sign in before starting a session."
            state = .idle
            return
        }

        state = .preparing
        elapsedTime = 0
        fullTranscript = ""
        isIgnoringInitialTranscript = true

        Task {
            do {
                let token = try await supabaseService.currentAccessToken()
                await MainActor.run {
                    self.webSocketService.connect(sessionId: self.session.id, token: token)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Session expired. Please sign in again."
                    self.state = .idle
                }
            }
        }
    }

    func stopSession() {
        state = .processing
        session.isRecording = false
        session.endTime = Date()
        session.audioFileURL = audioService.getRecordingURL()
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = false
        stopDurationTimer()
        audioService.stopRecording()
        webSocketService.endSession()
    }

    func resetSession() {
        state = .idle
        fullTranscript = ""
        analysisResult = nil
        errorMessage = nil
        elapsedTime = 0
        session = Session()
        stopDurationTimer()
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = false
        webSocketService.disconnect()
    }


    // MARK: - Duration Timer
    private func startDurationTimer() {
        stopDurationTimer()
        durationTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.UI.durationTimerInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime = Date().timeIntervalSince(self.session.startTime)
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    deinit {
        durationTimer?.invalidate()
        webSocketService.disconnect()
        audioService.stopRecording()
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
    }

    private func beginRecordingWithDelay() {
        DispatchQueue.main.async {
            self.recordingPreparationWorkItem?.cancel()

            let preparationWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                do {
                    self.session.startTime = Date()
                    self.startDurationTimer()
                    try self.audioService.startRecording()
                    self.state = .recording
                    self.session.isRecording = true
                    self.scheduleInitialTranscriptWindow()
                } catch {
                    self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    self.session.isRecording = false
                    self.state = .idle
                }
            }

            self.recordingPreparationWorkItem = preparationWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Recording.preparationDelay, execute: preparationWorkItem)
        }
    }

    private func scheduleInitialTranscriptWindow() {
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.isIgnoringInitialTranscript = false
        }

        ignoreInitialTranscriptWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Recording.initialTranscriptIgnoreDuration, execute: workItem)
    }
}
