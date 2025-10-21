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

    private var session: Session
    private let audioService: AudioRecordingService
    private let webSocketService: WebSocketService
    private var captionTimer: Timer?
    private var recordingPreparationWorkItem: DispatchWorkItem?
    private var ignoreInitialTranscriptWorkItem: DispatchWorkItem?
    private var isIgnoringInitialTranscript = false
    private let recordingPreparationDelay: TimeInterval = 0.6
    private let initialTranscriptIgnoreDuration: TimeInterval = 0.8

    init(mode: SessionMode, serverURL: String = "ws://localhost:3000") {
        self.session = Session(mode: mode)
        self.audioService = AudioRecordingService()
        self.webSocketService = WebSocketService(serverURL: serverURL)

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
            DispatchQueue.main.async {
                self?.currentCaption = caption
                self?.startCaptionStreamingEffect()
            }
        }

        webSocketService.onInteraction = { [weak self] question in
            DispatchQueue.main.async {
                self?.interactionQuestion = question
            }
        }

        webSocketService.onAnalysis = { [weak self] analysis in
            DispatchQueue.main.async {
                self?.analysisResult = analysis
                self?.state = .completed
            }
        }

        webSocketService.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error
                self?.state = .idle
            }
        }
    }

    func startSession() {
        state = .preparing
        session.startTime = Date()
        fullTranscript = ""
        isIgnoringInitialTranscript = true
        webSocketService.connect(sessionId: session.id, mode: session.mode)
    }

    func stopSession() {
        state = .processing
        session.isRecording = false
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = false
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
        session = Session(mode: session.mode)
        captionTimer?.invalidate()
        captionTimer = nil
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = false
        webSocketService.disconnect()
    }

    // MARK: - Streaming Caption Effect
    private func startCaptionStreamingEffect() {
        captionTimer?.invalidate()
        displayedCaption = ""

        let targetCaption = currentCaption
        var currentIndex = 0

        captionTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if currentIndex < targetCaption.count {
                let index = targetCaption.index(targetCaption.startIndex, offsetBy: currentIndex)
                self.displayedCaption = String(targetCaption[...index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }

    deinit {
        captionTimer?.invalidate()
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
