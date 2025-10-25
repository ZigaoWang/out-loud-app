import Foundation

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var savedSessions: [SavedSession] = []

    init() {
        // Cloud-only, no local storage
    }

    // MARK: - Persistence

    func saveSession(
        _ session: Session,
        analysis: AnalysisResult?,
        audioURL: URL?,
        transcriptSegments: [TranscriptSegment]? = nil,
        parentSessionId: String? = nil
    ) {
        // Save to cloud only
        Task { @MainActor in
            do {
                // Upload audio file first if exists
                var audioPath: String? = nil
                if let audioURL = audioURL {
                    do {
                        audioPath = try await SupabaseService.shared.uploadAudio(sessionId: session.id, fileURL: audioURL)
                        print("✅ Audio uploaded: \(audioPath ?? "")")
                    } catch {
                        print("❌ Audio upload failed: \(error)")
                        throw error
                    }
                }

                let savedSession = SavedSession(
                    id: session.id,
                    transcript: session.transcript,
                    transcriptSegments: transcriptSegments,
                    startTime: session.startTime,
                    endTime: session.endTime ?? Date(),
                    duration: session.duration,
                    audioFileName: audioPath,
                    analysis: analysis,
                    title: analysis?.title,
                    parentSessionId: parentSessionId,
                    followUpSessionIds: nil
                )

                do {
                    try await SupabaseService.shared.syncSession(savedSession)
                    print("✅ Session synced to cloud")
                } catch {
                    print("❌ Database insert failed: \(error)")
                    throw error
                }
                await loadSessions()
            } catch {
                print("❌ Failed to sync session: \(error)")
            }
        }
    }

    func loadSessions() async {
        do {
            let sessions = try await SupabaseService.shared.fetchSessions()
            await MainActor.run {
                self.savedSessions = sessions
            }
        } catch {
            print("❌ Failed to load sessions: \(error)")
        }
    }

    func deleteSession(_ session: SavedSession) {
        Task {
            do {
                try await SupabaseService.shared.deleteSession(session.id)
                await loadSessions()
            } catch {
                print("❌ Failed to delete session: \(error)")
            }
        }
    }

    var lastSession: SavedSession? {
        savedSessions.first
    }

    var totalTimeSpent: TimeInterval {
        savedSessions.reduce(0) { $0 + $1.duration }
    }

    var sessionCount: Int {
        savedSessions.count
    }

    var formattedTotalTime: String {
        let hours = Int(totalTimeSpent) / 3600
        let minutes = (Int(totalTimeSpent) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
