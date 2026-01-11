//
//  MedicationAPIClient.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import Foundation

protocol MedicationAPIClient: Sendable {
    func health() async throws -> HealthResponse

    func listMedications(username: String) async throws -> [MedicationDTO]
    func getMedication(username: String, id: String) async throws -> MedicationDTO

    func createMedication(username: String, body: CreateMedicationRequest) async throws -> MedicationDTO
    func updateMedication(username: String, id: String, body: UpdateMedicationRequest) async throws -> MedicationDTO

    func deleteMedication(username: String, id: String) async throws
}

struct LiveMedicationAPIClient: MedicationAPIClient {
    let baseURL: URL
    let apiKey: String
    let session: URLSession

    init(
        baseURL: URL = URL(string: "https://api-jictu6k26a-uc.a.run.app")!,
        apiKey: String = "healthengine-mobile-test-2026",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    func health() async throws -> HealthResponse {
        let url = baseURL.appendingPathComponent("health")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await send(req, decode: HealthResponse.self)
    }

    func listMedications(username: String) async throws -> [MedicationDTO] {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(username)
            .appendingPathComponent("medications")

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addAuth(&req)

        let wrapper = try await send(req, decode: DataArrayResponse<MedicationDTO>.self)
        return wrapper.data
    }

    func getMedication(username: String, id: String) async throws -> MedicationDTO {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(username)
            .appendingPathComponent("medications")
            .appendingPathComponent(id)

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addAuth(&req)

        let wrapper = try await send(req, decode: DataObjectResponse<MedicationDTO>.self)
        return wrapper.data
    }

    func createMedication(username: String, body: CreateMedicationRequest) async throws -> MedicationDTO {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(username)
            .appendingPathComponent("medications")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addAuth(&req)
        addJSON(&req)
        req.httpBody = try encoder.encode(body)

        let wrapper = try await send(req, decode: DataObjectResponse<MedicationDTO>.self, accepted: [200, 201])
        return wrapper.data
    }

    func updateMedication(username: String, id: String, body: UpdateMedicationRequest) async throws -> MedicationDTO {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(username)
            .appendingPathComponent("medications")
            .appendingPathComponent(id)

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        addAuth(&req)
        addJSON(&req)
        req.httpBody = try encoder.encode(body)

        let wrapper = try await send(req, decode: DataObjectResponse<MedicationDTO>.self)
        return wrapper.data
    }

    func deleteMedication(username: String, id: String) async throws {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(username)
            .appendingPathComponent("medications")
            .appendingPathComponent(id)

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        addAuth(&req)

        _ = try await send(req, decode: DeleteResponse.self)
    }

    // MARK: - Internals

    private func addAuth(_ req: inout URLRequest) {
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    }

    private func addJSON(_ req: inout URLRequest) {
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]

        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)

            if let dt = isoFrac.date(from: s) { return dt }
            if let dt = isoNoFrac.date(from: s) { return dt }

            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "Expected ISO8601 date, got: \(s)"
            )
        }

        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(isoFrac.string(from: date))
        }

        return e
    }

#if DEBUG
    private func dbg(_ s: @autoclosure () -> String) { print("[API] \(s())") }

    private func debugRequest(_ req: URLRequest) {
        let method = req.httpMethod ?? "?"
        let url = req.url?.absoluteString ?? "<nil>"
        dbg("➡️ \(method) \(url)")
        if let h = req.allHTTPHeaderFields, !h.isEmpty {
            dbg("   headers: \(h)")
        }
        if let body = req.httpBody, !body.isEmpty {
            if let str = String(data: body, encoding: .utf8) {
                dbg("   body: \(str)")
            } else {
                dbg("   body: <\(body.count) bytes>")
            }
        }
    }

    private func debugResponse(_ http: HTTPURLResponse, data: Data) {
        let url = http.url?.absoluteString ?? "<nil>"
        dbg("⬅️ \(http.statusCode) \(url)")
        let body = String(data: data, encoding: .utf8) ?? ""
        if !body.isEmpty {
            dbg("   body: \(body)")
        }
    }
#endif

    private func send<T: Decodable>(
        _ request: URLRequest,
        decode type: T.Type,
        accepted: Set<Int> = [200]
    ) async throws -> T {
#if DEBUG
        debugRequest(request)
#endif

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
#if DEBUG
            dbg("❌ invalid response type: \(Swift.type(of: response))")#endif
            throw APIError.invalidResponse
        }

#if DEBUG
        debugResponse(http, data: data)
#endif

        guard accepted.contains(http.statusCode) else {
            if let apiErr = try? decoder.decode(ErrorEnvelope.self, from: data) {
#if DEBUG
                dbg("❌ server error decoded: \(apiErr.error.code) \(apiErr.error.message)")
#endif
                throw APIError.server(code: apiErr.error.code, message: apiErr.error.message, status: http.statusCode)
            }
            let body = String(data: data, encoding: .utf8) ?? ""
#if DEBUG
            dbg("❌ http error raw body: \(body)")
#endif
            throw APIError.http(status: http.statusCode, body: body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
#if DEBUG
            dbg("❌ decoding failed for \(String(describing: T.self)): \(error)")
            if !body.isEmpty { dbg("   body: \(body)") }
#endif
            throw APIError.decoding(message: String(describing: error), body: body)
        }
    }
}

enum APIError: Error, LocalizedError, Sendable {
    case invalidResponse
    case http(status: Int, body: String)
    case server(code: String, message: String, status: Int)
    case decoding(message: String, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response."
        case .http(let status, let body): return "HTTP \(status): \(body)"
        case .server(let code, let message, let status): return "HTTP \(status) \(code): \(message)"
        case .decoding(let message, _): return "Decoding error: \(message)"
        }
    }

    var isNotFound: Bool {
        switch self {
        case .http(let status, _): return status == 404
        case .server(_, _, let status): return status == 404
        default: return false
        }
    }
}
