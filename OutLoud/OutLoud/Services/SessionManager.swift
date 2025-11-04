import Foundation

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var savedSessions: [SavedSession] = []
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var uploadSuccess: Bool = false
    @Published var isLoadingSessions: Bool = false

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
                    isUploading = true
                    uploadProgress = 0.0

                    // Retry up to 3 times
                    var lastError: Error?
                    for attempt in 1...3 {
                        do {
                            audioPath = try await SupabaseService.shared.uploadAudio(sessionId: session.id, fileURL: audioURL)
                            uploadProgress = 1.0
                            print("✅ Audio uploaded: \(audioPath ?? "")")
                            break
                        } catch {
                            lastError = error
                            print("❌ Audio upload failed (attempt \(attempt)/3): \(error)")
                            if attempt < 3 {
                                try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                            }
                        }
                    }

                    if audioPath == nil {
                        isUploading = false
                        throw lastError ?? NSError(domain: "Upload failed", code: -1)
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
                    isUploading = false
                    throw error
                }

                uploadSuccess = true
                isUploading = false

                try? await Task.sleep(nanoseconds: 1_500_000_000)
                uploadSuccess = false

                await loadSessions()
            } catch {
                isUploading = false
                print("❌ Failed to sync session: \(error)")
            }
        }
    }

    func loadSessions() async {
        await MainActor.run {
            self.isLoadingSessions = true
        }

        do {
            let sessions = try await SupabaseService.shared.fetchSessions()
            await MainActor.run {
                self.savedSessions = sessions
                self.isLoadingSessions = false
            }
        } catch {
            print("❌ Failed to load sessions: \(error)")
            await MainActor.run {
                self.isLoadingSessions = false
            }
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
