import Foundation

/// Communicates with the Python backend on localhost:7890.
final class APIClient {
    static let shared = APIClient()
    private let base = URL(string: "http://127.0.0.1:7890")!

    private init() {}

    // MARK: - Config

    func fetchConfig() async throws -> AppConfig {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("config"))
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }

    func saveConfig(_ config: AppConfig) async throws {
        var request = URLRequest(url: base.appendingPathComponent("config"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONEncoder().encode(config)
        let (_, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Status

    func fetchStatus() async throws -> BackendStatus {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("status"))
        return try JSONDecoder().decode(BackendStatus.self, from: data)
    }

    // MARK: - Recording control

    func startRecording() async throws {
        var request = URLRequest(url: base.appendingPathComponent("start"))
        request.httpMethod = "POST"
        let _ = try await URLSession.shared.data(for: request)
    }

    func stopRecording() async throws {
        var request = URLRequest(url: base.appendingPathComponent("stop"))
        request.httpMethod = "POST"
        let _ = try await URLSession.shared.data(for: request)
    }
}
