import Foundation
import Starscream

class WebSocketService: WebSocketDelegate {
    private var socket: WebSocket?
    private let serverURL: String
    private var transcriptWords: [TranscriptWord] = []

    // Reconnection state
    private var sessionId: String?
    private var token: String?
    private var reconnectAttempts = 0
    private var maxReconnectAttempts = 5
    private var reconnectTimer: Timer?
    private var isIntentionalDisconnect = false
    private var audioBuffer: [Data] = []
    private var isBuffering = false

    var onConnected: (() -> Void)?
    var onTranscript: ((String, Bool) -> Void)?
    var onCaption: ((String) -> Void)?
    var onInteraction: ((String) -> Void)?
    var onAnalysis: ((AnalysisResult, [TranscriptWord]?) -> Void)?
    var onError: ((String) -> Void)?
    var onReconnecting: (() -> Void)?

    init(serverURL: String = "wss://api.out-loud.app") {
        self.serverURL = serverURL
    }

    func connect(sessionId: String, token: String) {
        self.sessionId = sessionId
        self.token = token
        self.isIntentionalDisconnect = false
        attemptConnection()
    }

    private func attemptConnection() {
        guard let sessionId = sessionId, let token = token else { return }

        let urlString = "\(serverURL)?sessionId=\(sessionId)"
        guard let url = URL(string: urlString) else {
            onError?("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func disconnect() {
        isIntentionalDisconnect = true
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        socket?.disconnect()
        socket = nil
        sessionId = nil
        token = nil
        reconnectAttempts = 0
        audioBuffer.removeAll()
        isBuffering = false
    }

    func sendAudio(_ data: Data) {
        if isBuffering {
            audioBuffer.append(data)
        } else if socket != nil {
            socket?.write(data: data)
        } else {
            isBuffering = true
            audioBuffer.append(data)
        }
    }

    func endSession() {
        isIntentionalDisconnect = true
        socket?.write(data: Data())
    }

    // MARK: - WebSocketDelegate

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(_):
            print("WebSocket connected")
            reconnectAttempts = 0
            flushAudioBuffer()
            onConnected?()

        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
            handleDisconnection(code: code)

        case .text(let string):
            handleMessage(string)

        case .binary(let data):
            print("Received binary data: \(data.count) bytes")

        case .error(let error):
            print("WebSocket error: \(error?.localizedDescription ?? "unknown")")
            if !isIntentionalDisconnect {
                isBuffering = true
                scheduleReconnect()
            }

        case .cancelled:
            print("WebSocket cancelled")

        default:
            break
        }
    }

    private func handleDisconnection(code: UInt16) {
        guard !isIntentionalDisconnect else { return }

        if code != 1000 && code != 1001 {
            isBuffering = true
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            onError?("Connection lost. Please restart session.")
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)

        print("Reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        onReconnecting?()

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.attemptConnection()
        }
    }

    private func flushAudioBuffer() {
        guard !audioBuffer.isEmpty, socket != nil else { return }

        print("Flushing \(audioBuffer.count) buffered audio packets")
        for data in audioBuffer {
            socket?.write(data: data)
        }
        audioBuffer.removeAll()
        isBuffering = false
    }

    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "transcript":
            if let text = json["text"] as? String,
               let isFinal = json["isFinal"] as? Bool {
                onTranscript?(text, isFinal)
            }

        case "caption":
            if let text = json["text"] as? String {
                onCaption?(text)
            }

        case "interaction":
            if let question = json["question"] as? String {
                onInteraction?(question)
            }

        case "analysis":
            if let analysisData = json["data"] as? [String: Any] {
                let analysis = parseAnalysis(analysisData)

                // Parse word-level timestamps if available
                var words: [TranscriptWord]? = nil
                if let wordsData = json["words"] as? [[String: Any]] {
                    words = wordsData.compactMap { wordDict in
                        guard let word = wordDict["word"] as? String,
                              let startTime = wordDict["startTime"] as? Double,
                              let endTime = wordDict["endTime"] as? Double else {
                            return nil
                        }
                        return TranscriptWord(word: word, startTime: startTime, endTime: endTime)
                    }
                }

                onAnalysis?(analysis, words)
            }

        case "error":
            if let errorMessage = json["message"] as? String {
                onError?(errorMessage)
            }

        default:
            print("Unknown message type: \(type)")
        }
    }

    private func parseAnalysis(_ data: [String: Any]) -> AnalysisResult {
        let report = data["report"] as? [String: Any]

        return AnalysisResult(
            summary: data["summary"] as? String ?? "",
            keywords: data["keywords"] as? [String] ?? [],
            feedback: data["feedback"] as? String ?? "",
            report: Report(
                thinkingIntensity: report?["thinkingIntensity"] as? Int ?? 0,
                pauseTime: report?["pauseTime"] as? Int ?? 0,
                coherenceScore: report?["coherenceScore"] as? Int ?? 0,
                missingPoints: report?["missingPoints"] as? [String] ?? []
            ),
            followUpQuestion: data["followUpQuestion"] as? String ?? "",
            title: data["title"] as? String ?? nil
        )
    }

    deinit {
        reconnectTimer?.invalidate()
        disconnect()
    }
}
