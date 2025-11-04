import Foundation
import Combine

class SessionViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var currentCaption: String = ""
    @Published var displayedCaption: String = ""
    @Published var fullTranscript: String = "" // Single flowing transcript
    @Published var interactionQuestion: String?
    @Published var analysisResult: AnalysisResult?
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0
    @Published var elapsedTime: TimeInterval = 0

    private var session: Session
    private let audioService: AudioRecordingService
    private let webSocketService: WebSocketService
    private let supabaseService: SupabaseService
    private var captionTimer: Timer?
    private var durationTimer: Timer?
    private var recordingPreparationWorkItem: DispatchWorkItem?
    private var ignoreInitialTranscriptWorkItem: DispatchWorkItem?
    private var isIgnoringInitialTranscript = false
    private let recordingPreparationDelay: TimeInterval = 0.6
    private let initialTranscriptIgnoreDuration: TimeInterval = 0.8
    private let parentSessionId: String?
    private var lastCaptionTime: Date?
    private var previousCaption: String = ""

    init(
        serverURL: String = "wss://api.out-loud.app",
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

        webSocketService.onCaption = { [weak self] caption in
            // Disabled for now
        }

        webSocketService.onInteraction = { [weak self] question in
            DispatchQueue.main.async {
                self?.interactionQuestion = question
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

    func dismissInteractionQuestion() {
        interactionQuestion = nil
    }

    func resetSession() {
        state = .idle
        currentCaption = ""
        displayedCaption = ""
        fullTranscript = ""
        interactionQuestion = nil
        analysisResult = nil
        errorMessage = nil
        elapsedTime = 0
        session = Session()
        captionTimer?.invalidate()
        captionTimer = nil
        stopDurationTimer()
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = false
        webSocketService.disconnect()
    }


    // MARK: - Duration Timer
    private func startDurationTimer() {
        stopDurationTimer()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime = Date().timeIntervalSince(self.session.startTime)
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    deinit {
        captionTimer?.invalidate()
        durationTimer?.invalidate()
        webSocketService.disconnect()
        audioService.stopRecording()
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
    }

    private func beginRecordingWithDelay() {
        DispatchQueue.main.async {
            let delay = self.recordingPreparationDelay
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
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: preparationWorkItem)
        }
    }

    private func scheduleInitialTranscriptWindow() {
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.isIgnoringInitialTranscript = false
        }

        ignoreInitialTranscriptWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + initialTranscriptIgnoreDuration, execute: workItem)
    }
}
