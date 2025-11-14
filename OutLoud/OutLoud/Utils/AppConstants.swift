import Foundation
import AVFoundation

enum AppConstants {
    // MARK: - Network Configuration
    enum Network {
        static let productionWebSocketURL = "wss://api.out-loud.app"
        static let developmentWebSocketURL = "ws://localhost:3799"

        #if DEBUG
        static let defaultWebSocketURL = developmentWebSocketURL
        #else
        static let defaultWebSocketURL = productionWebSocketURL
        #endif

        static let connectionTimeout: TimeInterval = 5
        static let maxReconnectAttempts = 5
        static let maxReconnectDelay: TimeInterval = 30
    }

    // MARK: - Recording Configuration
    enum Recording {
        static let preparationDelay: TimeInterval = 0.6
        static let initialTranscriptIgnoreDuration: TimeInterval = 0.8
        static let audioBufferSize: AVAudioFrameCount = 4096
        static let targetSampleRate: Double = 16000
        static let targetChannels: AVAudioChannelCount = 1
    }

    // MARK: - UI Configuration
    enum UI {
        static let durationTimerInterval: TimeInterval = 0.1
        static let animationDuration: TimeInterval = 0.25
    }
}
