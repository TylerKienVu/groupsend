import Foundation

struct APIClient {
    static let baseURL = Config.apiBaseURL

    private let token: String?

    init(token: String? = nil) {
        self.token = token
    }

    // MARK: - Requests

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", query: query)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder().decode(T.self, from: data)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder().decode(T.self, from: data)
    }

    // GET /users/me — returns nil on 404 (user has no profile yet), throws on other errors.
    // The generic get() can't handle 404 gracefully because it always decodes the body,
    // so this method inspects the status code first.
    func getMe() async throws -> UserProfile? {
        let request = try buildRequest(path: "/users/me", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        // DEBUG — remove before shipping
        print("getMe status:", http.statusCode)
        print("getMe body:", String(data: data, encoding: .utf8) ?? "<binary>")
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? "Server error (\(http.statusCode))"
            throw NSError(domain: "API", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try decoder().decode(UserProfile.self, from: data)
    }

    // For DELETE requests that return 204 No Content
    func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }

    // PUT /users/me/device-token — pass nil to clear (disable notifications)
    func putDeviceToken(_ token: String?) async throws {
        struct Body: Encodable { let deviceToken: String? }
        var request = try buildRequest(path: "/users/me/device-token", method: "PUT")
        request.httpBody = try JSONEncoder().encode(Body(deviceToken: token))
        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Private

    private func buildRequest(path: String, method: String, query: [String: String] = [:]) throws -> URLRequest {
        var components = URLComponents(string: Self.baseURL + path)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // Prisma returns dates as ISO 8601 with fractional seconds (e.g. "2024-01-15T10:30:00.000Z").
    // Swift's built-in .iso8601 strategy doesn't handle fractional seconds, so we use a custom formatter.
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = formatter.date(from: str) { return date }
            // Fallback: try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(str)")
        }
        return d
    }
}
