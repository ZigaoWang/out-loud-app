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

    func saveSession(
        _ session: Session,
        analysis: AnalysisResult?,
        audioURL: URL?,
        transcriptSegments: [TranscriptSegment]? = nil,
        parentSessionId: String? = nil
    ) {
        var audioFileName: String?

        // Copy audio file to permanent location
        if let audioURL = audioURL {
            // Use the original file extension from the temp file
            let fileExtension = audioURL.pathExtension
            audioFileName = "\(session.id).\(fileExtension)"
            let destinationURL = audioDirectory.appendingPathComponent(audioFileName!)

            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: audioURL, to: destinationURL)
                print("💾 Saved audio file: \(audioFileName!) (size: \((try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0) bytes)")
            } catch {
                print("❌ Failed to copy audio file: \(error)")
            }
        }

        let savedSession = SavedSession(
            id: session.id,
            transcript: session.transcript,
            transcriptSegments: transcriptSegments,
            startTime: session.startTime,
            endTime: session.endTime ?? Date(),
            duration: session.duration,
            audioFileName: audioFileName,
            analysis: analysis,
            title: analysis?.title,
            parentSessionId: parentSessionId,
            followUpSessionIds: nil
        )

        // If this is a follow-up session, update the parent
        if let parentId = parentSessionId {
            updateParentSessionWithFollowUp(parentId: parentId, followUpId: session.id)
        }

        savedSessions.insert(savedSession, at: 0)
        persistSessions()
    }

    private func updateParentSessionWithFollowUp(parentId: String, followUpId: String) {
        guard let index = savedSessions.firstIndex(where: { $0.id == parentId }) else { return }

        let parent = savedSessions[index]
        var followUps = parent.followUpSessionIds ?? []
        followUps.append(followUpId)

        // Create updated session with new follow-up
        let updatedParent = SavedSession(
            id: parent.id,
            transcript: parent.transcript,
            transcriptSegments: parent.transcriptSegments,
            startTime: parent.startTime,
            endTime: parent.endTime,
            duration: parent.duration,
            audioFileName: parent.audioFileName,
            analysis: parent.analysis,
            title: parent.title,
            parentSessionId: parent.parentSessionId,
            followUpSessionIds: followUps
        )

        savedSessions[index] = updatedParent
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

    func getFollowUpSessions(for sessionId: String) -> [SavedSession] {
        savedSessions.filter { $0.parentSessionId == sessionId }
    }

    func getSessionChain(for session: SavedSession) -> [SavedSession] {
        var chain: [SavedSession] = [session]

        // Add all follow-ups
        if let followUpIds = session.followUpSessionIds {
            for followUpId in followUpIds {
                if let followUp = savedSessions.first(where: { $0.id == followUpId }) {
                    chain.append(contentsOf: getSessionChain(for: followUp))
                }
            }
        }

        return chain
    }

    var lastSession: SavedSession? {
        savedSessions.first
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
