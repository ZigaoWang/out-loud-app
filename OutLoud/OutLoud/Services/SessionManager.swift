import Foundation

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var savedSessions: [SavedSession] = []

    private let sessionsKey = "saved_sessions"
    private let audioDirectory: URL

    init() {
        // Create audio directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.audioDirectory = documentsPath.appendingPathComponent("Recordings", isDirectory: true)

        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        loadSessions()
    }

    // MARK: - Persistence

    func saveSession(_ session: Session, analysis: AnalysisResult?, audioURL: URL?) {
        var audioFileName: String?

        // Copy audio file to permanent location
        if let audioURL = audioURL {
            audioFileName = "\(session.id).m4a"
            let destinationURL = audioDirectory.appendingPathComponent(audioFileName!)

            try? FileManager.default.copyItem(at: audioURL, to: destinationURL)
        }

        let savedSession = SavedSession(
            id: session.id,
            transcript: session.transcript,
            startTime: session.startTime,
            endTime: session.endTime ?? Date(),
            duration: session.duration,
            audioFileName: audioFileName,
            analysis: analysis
        )

        savedSessions.insert(savedSession, at: 0)
        persistSessions()
    }

    func deleteSession(_ session: SavedSession) {
        // Delete audio file
        if let audioFileName = session.audioFileName {
            let audioURL = audioDirectory.appendingPathComponent(audioFileName)
            try? FileManager.default.removeItem(at: audioURL)
        }

        savedSessions.removeAll { $0.id == session.id }
        persistSessions()
    }

    func getAudioURL(for session: SavedSession) -> URL? {
        guard let audioFileName = session.audioFileName else { return nil }
        return audioDirectory.appendingPathComponent(audioFileName)
    }

    // MARK: - Stats

    var totalTimeSpent: TimeInterval {
        savedSessions.reduce(0) { $0 + $1.duration }
    }

    var sessionCount: Int {
        savedSessions.count
    }

    var formattedTotalTime: String {
        let hours = Int(totalTimeSpent) / 3600
        let minutes = (Int(totalTimeSpent) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Private

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([SavedSession].self, from: data) else {
            return
        }

        savedSessions = sessions
    }

    private func persistSessions() {
        guard let data = try? JSONEncoder().encode(savedSessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }
}
