//
//  MedicationNotificationScheduler.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import Foundation
import UserNotifications

protocol NotificationCenterProtocol: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

final class MedicationNotificationScheduler {

    struct MedicationReminderInfo: Sendable, Hashable {
        let id: String
        let username: String
        let name: String
        let dosage: String
        let frequency: MedicationFrequency

        let isActive: Bool
        let reminderAlert: Bool
        let reminderTime1: Date?
        let reminderTime2: Date?

        init(
            id: String,
            username: String,
            name: String,
            dosage: String,
            frequency: MedicationFrequency,
            isActive: Bool,
            reminderAlert: Bool,
            reminderTime1: Date?,
            reminderTime2: Date?
        ) {
            self.id = id
            self.username = username
            self.name = name
            self.dosage = dosage
            self.frequency = frequency
            self.isActive = isActive
            self.reminderAlert = reminderAlert
            self.reminderTime1 = reminderTime1
            self.reminderTime2 = reminderTime2
        }
    }

    static let shared = MedicationNotificationScheduler()

    private let center: NotificationCenterProtocol
    private let calendar: Calendar

    init(
        center: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    // MARK: - Authorization

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await center.authorizationStatus()

        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Public API

    func rescheduleAll(username: String, reminders: [MedicationReminderInfo]) async {
        let allowed = await requestAuthorizationIfNeeded()
        if !allowed { return }

        // cancel everything we might have scheduled before, then re-add what's needed
        let allIds = reminders.flatMap { r in
            [
                requestId(medicationId: r.id, slot: 1),
                requestId(medicationId: r.id, slot: 2)
            ]
        }
        center.removePendingNotificationRequests(withIdentifiers: allIds)
        center.removeDeliveredNotifications(withIdentifiers: allIds)

        for r in reminders {
            guard r.isActive else { continue }
            guard r.frequency != .as_needed else { continue }
            guard r.reminderAlert else { continue }

            let requests = makeRequests(username: username, reminder: r)
            for req in requests {
                do { try await center.add(req) } catch { }
            }
        }
    }

    func cancel(medicationId: String) async {
        let ids = [
            requestId(medicationId: medicationId, slot: 1),
            requestId(medicationId: medicationId, slot: 2)
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Building requests

    private func makeRequests(username: String, reminder: MedicationReminderInfo) -> [UNNotificationRequest] {
        var out: [UNNotificationRequest] = []
        out.reserveCapacity(2)

        if let t1 = reminder.reminderTime1,
           let trigger1 = makeTrigger(frequency: reminder.frequency, time: t1) {
            out.append(
                UNNotificationRequest(
                    identifier: requestId(medicationId: reminder.id, slot: 1),
                    content: makeContent(username: username, reminder: reminder, slot: 1),
                    trigger: trigger1
                )
            )
        }

        if reminder.frequency == .twice_daily,
           let t2 = reminder.reminderTime2,
           let trigger2 = makeTrigger(frequency: reminder.frequency, time: t2) {
            out.append(
                UNNotificationRequest(
                    identifier: requestId(medicationId: reminder.id, slot: 2),
                    content: makeContent(username: username, reminder: reminder, slot: 2),
                    trigger: trigger2
                )
            )
        }

        return out
    }

    private func makeTrigger(
        frequency: MedicationFrequency,
        time: Date
    ) -> UNCalendarNotificationTrigger? {
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)

        switch frequency {
        case .daily, .twice_daily:
            var dc = DateComponents()
            dc.hour = hour
            dc.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)

        case .weekly:
            let weekday = calendar.component(.weekday, from: time)
            var dc = DateComponents()
            dc.weekday = weekday
            dc.hour = hour
            dc.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)

        case .as_needed:
            return nil
        }
    }

    private func makeContent(
        username: String,
        reminder: MedicationReminderInfo,
        slot: Int
    ) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = "Medication Reminder"
        c.body = "Time to take \(reminder.name) (\(reminder.dosage))."
        c.sound = .default
        c.userInfo = [
            "username": username,
            "medicationId": reminder.id,
            "slot": slot,
            "frequency": reminder.frequency.rawValue
        ]
        return c
    }

    private func requestId(medicationId: String, slot: Int) -> String {
        "medreminder.\(medicationId).\(slot)"
    }
}
