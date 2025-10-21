import Foundation

// MARK: - Analysis Models

struct AnalysisResult: Codable {
    let summary: String
    let keywords: [String]
    let feedback: String
    let report: Report
    let followUpQuestion: String
}

struct Report: Codable {
    let thinkingIntensity: Int
    let pauseTime: Int
    let coherenceScore: Int
    let missingPoints: [String]
}

// MARK: - Session Models

struct Session {
    let id: String
    let mode: SessionMode
    var transcript: String
    var startTime: Date
    var isRecording: Bool

    init(mode: SessionMode) {
        self.id = UUID().uuidString
        self.mode = mode
        self.transcript = ""
        self.startTime = Date()
        self.isRecording = false
    }
}

// MARK: - UI State Models

enum RecordingState {
    case idle
    case preparing
    case recording
    case processing
    case completed
}

struct TranscriptSegment: Identifiable {
    let id = UUID()
    let text: String
    let isFinal: Bool
    let timestamp: Date
}
