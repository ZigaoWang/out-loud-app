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
    var transcript: String
    var startTime: Date
    var endTime: Date?
    var isRecording: Bool
    var audioFileURL: URL?

    init() {
        self.id = UUID().uuidString
        self.transcript = ""
        self.startTime = Date()
        self.endTime = nil
        self.isRecording = false
        self.audioFileURL = nil
    }

    var duration: TimeInterval {
        guard let end = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return end.timeIntervalSince(startTime)
    }
}

// MARK: - Saved Session Models

struct SavedSession: Codable, Identifiable {
    let id: String
    let transcript: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let audioFileName: String?
    let analysis: AnalysisResult?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
