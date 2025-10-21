import Foundation
import Starscream

class WebSocketService: WebSocketDelegate {
    private var socket: WebSocket?
    private let serverURL: String

    var onConnected: (() -> Void)?
    var onTranscript: ((String, Bool) -> Void)?
    var onCaption: ((String) -> Void)?
    var onInteraction: ((String) -> Void)?
    var onAnalysis: ((AnalysisResult) -> Void)?
    var onError: ((String) -> Void)?

    init(serverURL: String = "ws://localhost:3000") {
        self.serverURL = serverURL
    }

    func connect(sessionId: String, mode: SessionMode) {
        let urlString = "\(serverURL)?sessionId=\(sessionId)&mode=\(mode.rawValue)"
        guard let url = URL(string: urlString) else {
            onError?("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
    }

    func sendAudio(_ data: Data) {
        socket?.write(data: data)
    }

    func endSession() {
        // Send empty buffer to signal end
        socket?.write(data: Data())
    }

    // MARK: - WebSocketDelegate

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(_):
            print("WebSocket connected")
            onConnected?()

        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")

        case .text(let string):
            handleMessage(string)

        case .binary(let data):
            print("Received binary data: \(data.count) bytes")

        case .error(let error):
            print("WebSocket error: \(error?.localizedDescription ?? "unknown")")
            onError?(error?.localizedDescription ?? "Connection error")

        case .cancelled:
            print("WebSocket cancelled")

        default:
            break
        }
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
                onAnalysis?(analysis)
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
            followUpQuestion: data["followUpQuestion"] as? String ?? ""
        )
    }
}

enum SessionMode: String {
    case solo
    case interactive
}
