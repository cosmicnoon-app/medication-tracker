//
//  Medication_TrackerTests.swift
//  Medication TrackerTests
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import Foundation
import Testing
import UserNotifications
@testable import Medication_Tracker

@Suite(.serialized)
struct Medication_TrackerTests {
    
    @Test
    @MainActor
    func medicationFrequency_idEqualsRawValue() async throws {
        #expect(MedicationFrequency.daily.id == "daily")
        #expect(MedicationFrequency.twice_daily.id == "twice_daily")
        #expect(MedicationFrequency.weekly.id == "weekly")
        #expect(MedicationFrequency.as_needed.id == "as_needed")
    }
    
    @Test
    @MainActor
    func medicationFrequency_title() async throws {
        #expect(MedicationFrequency.daily.title == "Daily")
        #expect(MedicationFrequency.twice_daily.title == "Twice daily")
        #expect(MedicationFrequency.weekly.title == "Weekly")
        #expect(MedicationFrequency.as_needed.title == "As needed")
    }
    
    @Test
    @MainActor
    func medicationStatus_codableRoundTrip() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original: MedicationStatus = .deleted
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MedicationStatus.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test
    @MainActor
    func medicationFrequency_codableRoundTrip() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original: MedicationFrequency = .twice_daily
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MedicationFrequency.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test
    @MainActor
    func medicationInitializer_assignsFieldsAndDefaults() async throws {
        let now = Date()
        
        let med = Medication(
            id: "fixed-id",
            username: "test-user",
            name: "Aspirin",
            dosage: "100mg",
            frequency: .daily,
            createdAt: now,
            updatedAt: now
        )
        
        #expect(med.id == "fixed-id")
        #expect(med.username == "test-user")
        #expect(med.name == "Aspirin")
        #expect(med.dosage == "100mg")
        #expect(med.frequency == .daily)
        #expect(med.createdAt == now)
        #expect(med.updatedAt == now)
        
        #expect(med.status == .active)
        #expect(med.reminderAlert == false)
        #expect(med.reminderTime1 == nil)
        #expect(med.reminderTime2 == nil)
    }
    
    @Test
    @MainActor
    func medicationInitializer_allowsReminderFields() async throws {
        let now = Date()
        let t1 = Date(timeIntervalSince1970: 1_000_000)
        let t2 = Date(timeIntervalSince1970: 2_000_000)
        
        let med = Medication(
            id: "id",
            username: "u",
            name: "N",
            dosage: "D",
            frequency: .twice_daily,
            createdAt: now,
            updatedAt: now,
            status: .active,
            reminderAlert: true,
            reminderTime1: t1,
            reminderTime2: t2
        )
        
        #expect(med.reminderAlert == true)
        #expect(med.reminderTime1 == t1)
        #expect(med.reminderTime2 == t2)
    }
    
    @Test
    @MainActor
    func api_createMedication_sendsHeadersAndBody_andAccepts201_andDecodesFractionalISO8601Dates() async throws {
        defer { MockURLProtocol.handler = nil }
        
        let session = makeMockedSession()
        let client = LiveMedicationAPIClient(
            baseURL: URL(string: "https://example.com")!,
            apiKey: "test-key",
            session: session
        )
        
        MockURLProtocol.handler = { req in
            #expect(req.httpMethod == "POST")
            #expect(req.url?.absoluteString == "https://example.com/users/test-user/medications")
            
            let headers = req.allHTTPHeaderFields ?? [:]
            #expect(headers["x-api-key"] == "test-key")
            #expect(headers["Accept"] == "application/json")
            #expect(headers["Content-Type"] == "application/json")
            
            let json = decodeBodyJSON(req)
            #expect(json["name"] as? String == "Addd")
            #expect(json["dosage"] as? String == "100 mg")
            #expect(json["frequency"] as? String == "twice_daily")
            
            let body = """
                {
                  "data": {
                    "id": "82d77c26-2858-4eba-8901-e4644452f5c4",
                    "username": "test-user",
                    "name": "Addd",
                    "dosage": "100 mg",
                    "frequency": "twice_daily",
                    "createdAt": "2026-01-11T08:23:24.965Z",
                    "updatedAt": "2026-01-11T08:23:24.965Z"
                  }
                }
                """.data(using: .utf8)!
            
            return MockURLProtocol.Stub(
                statusCode: 201,
                headers: ["Content-Type": "application/json"],
                body: body
            )
        }
        
        let dto = try await client.createMedication(
            username: "test-user",
            body: CreateMedicationRequest(
                name: "Addd",
                dosage: "100 mg",
                frequency: .twice_daily
            )
        )
        
        #expect(dto.id == "82d77c26-2858-4eba-8901-e4644452f5c4")
        #expect(dto.username == "test-user")
        #expect(dto.name == "Addd")
        #expect(dto.dosage == "100 mg")
        #expect(dto.frequency == .twice_daily)
        #expect(dto.createdAt == dto.updatedAt)
    }
    
    @Test
    @MainActor
    func api_listMedications_sendsAuthHeader_andDecodesEmptyArray() async throws {
        defer { MockURLProtocol.handler = nil }
        
        let session = makeMockedSession()
        let client = LiveMedicationAPIClient(
            baseURL: URL(string: "https://example.com")!,
            apiKey: "k",
            session: session
        )
        
        MockURLProtocol.handler = { req in
            #expect(req.httpMethod == "GET")
            #expect(req.url?.absoluteString == "https://example.com/users/u/medications")
            #expect((req.allHTTPHeaderFields ?? [:])["x-api-key"] == "k")
            
            let body = #"{"data":[]}"#.data(using: .utf8)!
            return MockURLProtocol.Stub(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: body
            )
        }
        
        let meds = try await client.listMedications(username: "u")
        #expect(meds.isEmpty)
    }
    
    @Test
    @MainActor
    func api_non2xx_withErrorEnvelope_throwsServerError() async throws {
        defer { MockURLProtocol.handler = nil }
        
        let session = makeMockedSession()
        let client = LiveMedicationAPIClient(
            baseURL: URL(string: "https://example.com")!,
            apiKey: "k",
            session: session
        )
        
        MockURLProtocol.handler = { req in
            #expect(req.httpMethod == "GET")
            #expect(req.url?.absoluteString == "https://example.com/users/u/medications")
            
            let body = """
                {
                  "error": {
                    "code": "bad_request",
                    "message": "Nope"
                  }
                }
                """.data(using: .utf8)!
            
            return MockURLProtocol.Stub(
                statusCode: 400,
                headers: ["Content-Type": "application/json"],
                body: body
            )
        }
        
        do {
            _ = try await client.listMedications(username: "u")
            #expect(Bool(false))
        } catch let err as APIError {
            switch err {
            case .server(let code, let message, let status):
                #expect(code == "bad_request")
                #expect(message == "Nope")
                #expect(status == 400)
            default:
                #expect(Bool(false))
            }
        }
    }
    
    @Test
    @MainActor
    func scheduler_skipsInactiveAndAsNeeded() async {
        let mockCenter = MockNotificationCenter()
        mockCenter.status = .authorized

        let scheduler = MedicationNotificationScheduler(center: mockCenter)

        let reminders: [MedicationNotificationScheduler.MedicationReminderInfo] = [
            .init(
                id: "1",
                username: "u",
                name: "A",
                dosage: "1",
                frequency: .as_needed,
                isActive: true,
                reminderAlert: true,
                reminderTime1: Date(),
                reminderTime2: nil
            ),
            .init(
                id: "2",
                username: "u",
                name: "B",
                dosage: "1",
                frequency: .daily,
                isActive: false,
                reminderAlert: true,
                reminderTime1: Date(),
                reminderTime2: nil
            )
        ]

        await scheduler.rescheduleAll(username: "u", reminders: reminders)

        #expect(mockCenter.addedRequests.isEmpty)
    }

    @Test
    @MainActor
    func scheduler_createsTwoRequestsForTwiceDaily() async {
        let mockCenter = MockNotificationCenter()
        mockCenter.status = .authorized

        let scheduler = MedicationNotificationScheduler(center: mockCenter)

        let t1 = Date()
        let t2 = Date().addingTimeInterval(60)

        let reminders: [MedicationNotificationScheduler.MedicationReminderInfo] = [
            .init(
                id: "abc",
                username: "u",
                name: "Aspirin",
                dosage: "100mg",
                frequency: .twice_daily,
                isActive: true,
                reminderAlert: true,
                reminderTime1: t1,
                reminderTime2: t2
            )
        ]

        await scheduler.rescheduleAll(username: "u", reminders: reminders)

        #expect(mockCenter.addedRequests.count == 2)
        #expect(mockCenter.addedRequests[0].identifier == "medreminder.abc.1")
        #expect(mockCenter.addedRequests[1].identifier == "medreminder.abc.2")
    }

    @Test
    @MainActor
    func scheduler_setsCorrectNotificationBody() async {
        let mockCenter = MockNotificationCenter()
        mockCenter.status = .authorized

        let scheduler = MedicationNotificationScheduler(center: mockCenter)

        let reminders: [MedicationNotificationScheduler.MedicationReminderInfo] = [
            .init(
                id: "x",
                username: "u",
                name: "Vitamin D",
                dosage: "1000 IU",
                frequency: .daily,
                isActive: true,
                reminderAlert: true,
                reminderTime1: Date(),
                reminderTime2: nil
            )
        ]

        await scheduler.rescheduleAll(username: "u", reminders: reminders)

        let content = mockCenter.addedRequests.first!.content
        #expect(content.title == "Medication Reminder")
        #expect(content.body.contains("Vitamin D"))
    }
}

final class MockURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }
    
    static var handler: (@Sendable (URLRequest) throws -> Stub)?
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        
        do {
            let stub = try handler(request)
            
            let url = request.url ?? URL(string: "https://invalid.local")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() { }
}

private func makeMockedSession() -> URLSession {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: cfg)
}

private func decodeBodyJSON(_ request: URLRequest) -> [String: Any] {
    guard let data = request.httpBody else { return [:] }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}

final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {

    private let lock = NSLock()

    private var _status: UNAuthorizationStatus = .authorized
    private var _addedRequests: [UNNotificationRequest] = []
    private var _removedPendingIds: [String] = []
    private var _removedDeliveredIds: [String] = []

    var status: UNAuthorizationStatus {
        get { lock.withLock { _status } }
        set { lock.withLock { _status = newValue } }
    }

    var addedRequests: [UNNotificationRequest] {
        lock.withLock { _addedRequests }
    }

    var removedPendingIds: [String] {
        lock.withLock { _removedPendingIds }
    }

    var removedDeliveredIds: [String] {
        lock.withLock { _removedDeliveredIds }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        true
    }

    func add(_ request: UNNotificationRequest) async throws {
        lock.withLock { _addedRequests.append(request) }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        lock.withLock { _removedPendingIds.append(contentsOf: identifiers) }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        lock.withLock { _removedDeliveredIds.append(contentsOf: identifiers) }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
