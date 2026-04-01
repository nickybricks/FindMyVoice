import Foundation
import os.log

private let logger = Logger(subsystem: "com.findmyvoice", category: "api")

/// Communicates with the Python backend on localhost:7890.
final class APIClient {
    static let shared = APIClient()
    private let base = URL(string: "http://127.0.0.1:7890")!

    private init() {}

    // MARK: - Config

    func fetchConfig() async throws -> AppConfig {
        logger.info("GET /config")
        let (data, response) = try await URLSession.shared.data(from: base.appendingPathComponent("config"))
        let http = response as? HTTPURLResponse
        logger.info("GET /config → \(http?.statusCode ?? -1)")
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }

    func saveConfig(_ config: AppConfig) async throws {
        logger.info("POST /config")
        var request = URLRequest(url: base.appendingPathComponent("config"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONEncoder().encode(config)
        let (_, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.error("POST /config → bad response")
            throw URLError(.badServerResponse)
        }
        logger.info("POST /config → \(http.statusCode)")
    }

    // MARK: - Status

    func fetchStatus() async throws -> BackendStatus {
        let (data, response) = try await URLSession.shared.data(from: base.appendingPathComponent("status"))
        let http = response as? HTTPURLResponse
        logger.debug("GET /status → \(http?.statusCode ?? -1)")
        return try JSONDecoder().decode(BackendStatus.self, from: data)
    }

    // MARK: - Recording control

    func startRecording() async throws {
        logger.info("POST /start — requesting recording start")
        var request = URLRequest(url: base.appendingPathComponent("start"))
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let body = String(data: data, encoding: .utf8) ?? ""
        logger.info("POST /start → \(http?.statusCode ?? -1) — \(body)")
    }

    func stopRecording() async throws {
        logger.info("POST /stop — requesting recording stop")
        var request = URLRequest(url: base.appendingPathComponent("stop"))
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let body = String(data: data, encoding: .utf8) ?? ""
        logger.info("POST /stop → \(http?.statusCode ?? -1) — \(body)")
    }

    // MARK: - NeMo

    func fetchNemoStatus() async throws -> NemoStatus {
        logger.info("GET /nemo/status")
        let (data, response) = try await URLSession.shared.data(from: base.appendingPathComponent("nemo/status"))
        let http = response as? HTTPURLResponse
        logger.info("GET /nemo/status → \(http?.statusCode ?? -1)")
        return try JSONDecoder().decode(NemoStatus.self, from: data)
    }

    /// Streams SSE lines from POST /nemo/install. Calls `onLine` for each data line.
    /// Returns true if install succeeded (__DONE__), false on error.
    func installNemo(onLine: @escaping (String) -> Void) async throws -> Bool {
        logger.info("POST /nemo/install — starting SSE install stream")
        var request = URLRequest(url: base.appendingPathComponent("nemo/install"))
        request.httpMethod = "POST"
        request.timeoutInterval = 600 // 10 min for large download

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let http = response as? HTTPURLResponse
        logger.info("POST /nemo/install → \(http?.statusCode ?? -1)")

        for try await line in bytes.lines {
            // SSE format: "data: <content>"
            guard line.hasPrefix("data: ") else { continue }
            let content = String(line.dropFirst(6))

            if content == "__DONE__" {
                logger.info("NeMo install completed successfully")
                return true
            }
            if content.hasPrefix("__ERROR__") {
                logger.error("NeMo install failed: \(content)")
                onLine(content)
                return false
            }
            onLine(content)
        }
        return false
    }
}
