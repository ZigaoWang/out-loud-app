import Foundation
import Combine

class SessionViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var currentCaption: String = ""
    @Published var displayedCaption: String = "" // NEW: For streaming effect
    @Published var transcriptSegments: [TranscriptSegment] = []
    @Published var interactionQuestion: String?
    @Published var analysisResult: AnalysisResult?
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0  // NEW: Audio level for visualization

    private var session: Session
    private let audioService: AudioRecordingService
    private let webSocketService: WebSocketService
    private var captionTimer: Timer?
    private var recordingPreparationWorkItem: DispatchWorkItem?
    private var ignoreInitialTranscriptWorkItem: DispatchWorkItem?
    private var isIgnoringInitialTranscript = false
    private var lastFinalTranscript: String = ""
    private var lastFinalChunk: String = ""
    private var lastPartialText: String = ""
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
                guard let self = self else { return }

                // Skip empty text
                if text.isEmpty { return }

                if self.isIgnoringInitialTranscript {
                    return
                }

                let normalizedText = self.normalizeTranscript(text)

                if normalizedText.isEmpty {
                    return
                }

                if isFinal {
                    if normalizedText == self.lastFinalTranscript {
                        return
                    }

                    var newChunk = normalizedText

                    if !self.lastFinalTranscript.isEmpty,
                       normalizedText.hasPrefix(self.lastFinalTranscript) {
                        newChunk = String(normalizedText.dropFirst(self.lastFinalTranscript.count))
                        newChunk = newChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    guard !newChunk.isEmpty else {
                        self.lastFinalTranscript = normalizedText
                        return
                    }

                    if newChunk == self.lastFinalChunk {
                        self.lastFinalTranscript = normalizedText
                        return
                    }

                    // Remove temporary partial segments before adding final chunk
                    self.transcriptSegments.removeAll { !$0.isFinal }

                    self.transcriptSegments.append(
                        TranscriptSegment(
                            text: newChunk,
                            isFinal: true,
                            timestamp: Date()
                        )
                    )

                    self.lastFinalChunk = newChunk
                    self.lastPartialText = ""
                    self.lastFinalTranscript = normalizedText

                    let finalText = self.transcriptSegments
                        .filter { $0.isFinal }
                        .map { $0.text }
                        .joined(separator: " ")
                    self.session.transcript = finalText
                } else {
                    // Partial transcript - update or add
                    // Remove previous partial to keep list tidy
                    if let partialIndex = self.transcriptSegments.lastIndex(where: { !$0.isFinal }) {
                        self.transcriptSegments.remove(at: partialIndex)
                    }

                    var partialText = normalizedText
                    if !self.lastFinalTranscript.isEmpty,
                       partialText.hasPrefix(self.lastFinalTranscript) {
                        partialText = String(partialText.dropFirst(self.lastFinalTranscript.count))
                       partialText = partialText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    guard !partialText.isEmpty else { return }

                    if partialText == self.lastPartialText {
                        return
                    }

                    self.transcriptSegments.append(
                        TranscriptSegment(
                            text: partialText,
                            isFinal: false,
                            timestamp: Date()
                        )
                    )

                    self.lastPartialText = partialText
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
        lastFinalTranscript = ""
        lastFinalChunk = ""
        lastPartialText = ""
        isIgnoringInitialTranscript = true

        // Connect WebSocket (recording will auto-start via onConnected callback)
        webSocketService.connect(sessionId: session.id, mode: session.mode)
    }

    func stopSession() {
        state = .processing
        session.isRecording = false

        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = false
        lastPartialText = ""

        // Stop recording
        audioService.stopRecording()

        // End session (triggers analysis)
        webSocketService.endSession()
    }

    func dismissInteractionQuestion() {
        interactionQuestion = nil
    }

    func resetSession() {
        state = .idle
        currentCaption = ""
        displayedCaption = ""
        transcriptSegments = []
        interactionQuestion = nil
        analysisResult = nil
        errorMessage = nil
        session = Session(mode: session.mode)
        captionTimer?.invalidate()
        captionTimer = nil
        recordingPreparationWorkItem?.cancel()
        ignoreInitialTranscriptWorkItem?.cancel()
        isIgnoringInitialTranscript = false
        lastFinalTranscript = ""
        lastFinalChunk = ""
        lastPartialText = ""

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

    private func normalizeTranscript(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return "" }

        let components = trimmed.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
