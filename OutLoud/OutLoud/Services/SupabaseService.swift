import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let client: SupabaseClient

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
                    self.isAuthenticated = false
                }
            }
        }
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
    }

    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    func uploadAudio(sessionId: String, fileURL: URL) async throws -> String {
        // Refresh session if needed
        let session = try await client.auth.session
        guard !session.accessToken.isEmpty else {
            throw NSError(domain: "Session expired", code: 401)
        }

        let data = try Data(contentsOf: fileURL)

        var request = URLRequest(url: URL(string: "http://localhost:3000/upload/audio")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

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

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Upload failed", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        let result = try JSONDecoder().decode([String: String].self, from: responseData)
        guard let path = result["path"] else {
            throw NSError(domain: "No path in response", code: 500)
        }

        print("✅ Audio uploaded: \(path)")
        return path
    }

    func getAudioURL(path: String) -> URL? {
        guard currentUser != nil else { return nil }
        return try? client.storage.from("audio-recordings").getPublicURL(path: path)
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
            let start_time: String
            let end_time: String
            let duration: Double
            let title: String?
            let audio_path: String?
        }

        let sessionData = SessionInsert(
            user_id: user.id,
            session_id: session.id,
            transcript: session.transcript,
            start_time: ISO8601DateFormatter().string(from: session.startTime),
            end_time: ISO8601DateFormatter().string(from: session.endTime),
            duration: session.duration,
            title: session.title,
            audio_path: session.audioFileName
        )

        try await client.database.from("sessions").insert(sessionData).execute()
    }

    func fetchSessions() async throws -> [SavedSession] {
        guard let user = currentUser else { return [] }

        let response: [SessionDTO] = try await client.database
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
        let sessions: [SessionDTO] = try await client.database
            .from("sessions")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .eq("session_id", value: sessionId)
            .execute()
            .value

        if let session = sessions.first, let audioPath = session.audio_path {
            try? await client.storage.from("audio-recordings").remove(paths: [audioPath])
        }

        try await client.database
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
    let start_time: String
    let end_time: String
    let duration: Double
    let title: String?
    let audio_path: String?

    func toSavedSession() -> SavedSession {
        let formatter = ISO8601DateFormatter()
        return SavedSession(
            id: session_id,
            transcript: transcript,
            transcriptSegments: nil,
            startTime: formatter.date(from: start_time) ?? Date(),
            endTime: formatter.date(from: end_time) ?? Date(),
            duration: duration,
            audioFileName: audio_path,
            analysis: nil,
            title: title,
            parentSessionId: nil,
            followUpSessionIds: nil
        )
    }
}
