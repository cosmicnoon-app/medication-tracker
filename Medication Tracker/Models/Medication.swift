//
//  Medication.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import Foundation
import SwiftData

@Model
final class Medication {
    @Attribute(.unique)
    var id: String

    var username: String
    var name: String
    var dosage: String
    var frequency: MedicationFrequency
    var createdAt: Date
    var updatedAt: Date

    var status: MedicationStatus

    var reminderAlert: Bool = false
    var reminderTime1: Date?
    var reminderTime2: Date?

    init(
        id: String = UUID().uuidString,
        username: String,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        createdAt: Date,
        updatedAt: Date,
        status: MedicationStatus = .active,
        reminderAlert: Bool = false,
        reminderTime1: Date? = nil,
        reminderTime2: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.reminderAlert = reminderAlert
        self.reminderTime1 = reminderTime1
        self.reminderTime2 = reminderTime2
    }
}

enum MedicationStatus: Int, Codable, Sendable {
    case active = 0
    case deleted = 1
}

enum MedicationFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case twice_daily
    case weekly
    case as_needed

    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .daily: return "Daily"
        case .twice_daily: return "Twice daily"
        case .weekly: return "Weekly"
        case .as_needed: return "As needed"
        }
    }
}
