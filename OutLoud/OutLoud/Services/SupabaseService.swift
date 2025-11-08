import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let client: SupabaseClient
    private let defaultBackendURL: String?
    private let emailRedirectURL: URL?

    init() {
        // Load from Config.plist (gitignored)
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath),
              let urlString = config["SUPABASE_URL"] as? String,
              let supabaseURL = URL(string: urlString),
              let supabaseKey = config["SUPABASE_ANON_KEY"] as? String else {
            fatalError("Missing Config.plist - copy Config.example.plist to Config.plist and add your credentials")
        }

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        self.defaultBackendURL = config["BACKEND_URL"] as? String

        if let redirectString = config["SUPABASE_EMAIL_REDIRECT_URL"] as? String,
           let redirectURL = URL(string: redirectString), !redirectString.isEmpty {
            self.emailRedirectURL = redirectURL
        } else {
            self.emailRedirectURL = nil
        }
        checkAuth()
    }

    func checkAuth() {
        Task {
            do {
                let user = try await client.auth.session.user
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            } catch {
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
    }

    @discardableResult
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: emailRedirectURL
        )

        await MainActor.run {
            if response.session != nil {
                self.currentUser = response.user
                self.isAuthenticated = true
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }

        // When email confirmation is required, Supabase returns nil session.
        return response.session == nil
    }

    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
    }

    func sendPasswordReset(email: String, redirectTo: URL? = nil) async throws {
        let targetURL = redirectTo ?? emailRedirectURL
        _ = try await client.auth.resetPasswordForEmail(email, redirectTo: targetURL)
    }

    func updatePassword(_ newPassword: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func resendConfirmationEmail(email: String) async throws {
        _ = try await client.auth.resend(email: email, type: .signup)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    func uploadAudio(sessionId: String, fileURL: URL) async throws -> String {
        let session = try await client.auth.session
        guard !session.accessToken.isEmpty else {
            throw NSError(domain: "Session expired", code: 401)
        }

        let data = try Data(contentsOf: fileURL)

        // Use environment variable, Info.plist, or fallback Config.plist for backend URL
        guard let backendURLString = ProcessInfo.processInfo.environment["BACKEND_URL"]
                ?? Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String
                ?? defaultBackendURL,
              let backendURL = URL(string: backendURLString) else {
            throw NSError(domain: "Missing BACKEND_URL", code: 500)
        }

        var request = URLRequest(url: backendURL.appendingPathComponent("upload/audio"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Retry logic
        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (responseData, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "Invalid response", code: 500)
                }

                if httpResponse.statusCode == 200 {
                    let result = try JSONDecoder().decode([String: String].self, from: responseData)
                    guard let path = result["path"] else {
                        throw NSError(domain: "No path in response", code: 500)
                    }
                    print("✅ Audio uploaded: \(path)")
                    return path
                } else if httpResponse.statusCode >= 500 && attempt < 3 {
                    // Retry on server errors
                    try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                    continue
                } else {
                    throw NSError(domain: "Upload failed", code: httpResponse.statusCode)
                }
            } catch {
                lastError = error
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(domain: "Upload failed", code: 500)
    }

    func currentAccessToken() async throws -> String {
        let session = try await client.auth.session
        if session.accessToken.isEmpty {
            throw NSError(domain: "Session expired", code: 401)
        }
        return session.accessToken
    }

    func getAudioURL(path: String) async throws -> URL {
        guard currentUser != nil else { throw NSError(domain: "Not authenticated", code: 401) }
        let signedURL = try await client.storage.from("audio-recordings").createSignedURL(path: path, expiresIn: 3600)
        return signedURL
    }

    func syncSession(_ session: SavedSession) async throws {
        guard let user = currentUser else { throw NSError(domain: "Not authenticated", code: 401) }

        // Verify we have a valid session
        let authSession = try await client.auth.session
        print("🔐 Auth user ID: \(authSession.user.id)")

        struct SessionInsert: Encodable {
            let user_id: UUID
            let session_id: String
            let transcript: String
            let transcript_segments: [TranscriptSegment]?
            let start_time: String
            let end_time: String
            let duration: Double
            let analysis: AnalysisResult?
            let title: String?
            let audio_path: String?
        }

        let sessionData = SessionInsert(
            user_id: user.id,
            session_id: session.id,
            transcript: session.transcript,
            transcript_segments: session.transcriptSegments,
            start_time: ISO8601DateFormatter().string(from: session.startTime),
            end_time: ISO8601DateFormatter().string(from: session.endTime),
            duration: session.duration,
            analysis: session.analysis,
            title: session.title,
            audio_path: session.audioFileName
        )

        try await client.from("sessions")
            .upsert(sessionData, onConflict: "user_id,session_id")
            .execute()
    }

    func fetchSessions() async throws -> [SavedSession] {
        guard let user = currentUser else { return [] }

        let response: [SessionDTO] = try await client
            .from("sessions")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .order("start_time", ascending: false)
            .execute()
            .value

        return response.map { $0.toSavedSession() }
    }

    func deleteSession(_ sessionId: String) async throws {
        guard let user = currentUser else { throw NSError(domain: "Not authenticated", code: 401) }

        // Delete audio file first if exists
        let sessions: [SessionDTO] = try await client
            .from("sessions")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .eq("session_id", value: sessionId)
            .execute()
            .value

        if let session = sessions.first, let audioPath = session.audio_path {
            try? await client.storage.from("audio-recordings").remove(paths: [audioPath])
        }

        try await client
            .from("sessions")
            .delete()
            .eq("user_id", value: user.id.uuidString)
            .eq("session_id", value: sessionId)
            .execute()
    }

}

struct SessionDTO: Codable {
    let session_id: String
    let transcript: String
    let transcript_segments: AnyCodable?
    let start_time: String
    let end_time: String
    let duration: Double
    let analysis: AnyCodable?
    let title: String?
    let audio_path: String?

    func toSavedSession() -> SavedSession {
        let formatter = ISO8601DateFormatter()

        var segments: [TranscriptSegment]? = nil
        var analysisResult: AnalysisResult? = nil

        if let segData = transcript_segments?.value as? [[String: Any]] {
            segments = segData.compactMap { dict in
                guard let text = dict["text"] as? String,
                      let words = dict["words"] as? [[String: Any]],
                      let startTime = dict["startTime"] as? Double,
                      let endTime = dict["endTime"] as? Double else { return nil }

                let transcriptWords = words.compactMap { w -> TranscriptWord? in
                    guard let word = w["word"] as? String,
                          let st = w["startTime"] as? Double,
                          let et = w["endTime"] as? Double else { return nil }
                    return TranscriptWord(word: word, startTime: st, endTime: et)
                }

                return TranscriptSegment(text: text, words: transcriptWords, startTime: startTime, endTime: endTime)
            }
        }

        if let analysisData = analysis?.value as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: analysisData),
           let result = try? JSONDecoder().decode(AnalysisResult.self, from: data) {
            analysisResult = result
        }

        return SavedSession(
            id: session_id,
            transcript: transcript,
            transcriptSegments: segments,
            startTime: formatter.date(from: start_time) ?? Date(),
            endTime: formatter.date(from: end_time) ?? Date(),
            duration: duration,
            audioFileName: audio_path,
            analysis: analysisResult,
            title: title,
            parentSessionId: nil,
            followUpSessionIds: nil
        )
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}
