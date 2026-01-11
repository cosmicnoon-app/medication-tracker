//
//  MedicationAPIModels.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import Foundation

struct HealthResponse: Codable {
    let status: String
}

struct MedicationDTO: Codable, Hashable {
    let id: String
    let username: String
    let name: String
    let dosage: String
    let frequency: MedicationFrequency
    let createdAt: Date
    let updatedAt: Date
}

struct CreateMedicationRequest: Codable {
    let name: String
    let dosage: String
    let frequency: MedicationFrequency
}

struct UpdateMedicationRequest: Codable {
    let name: String?
    let dosage: String?
    let frequency: MedicationFrequency?
}

struct DataArrayResponse<T: Codable>: Codable {
    let data: [T]
}

struct DataObjectResponse<T: Codable>: Codable {
    let data: T
}

struct DeleteResponse: Codable {
    struct Payload: Codable {
        let id: String
    }
    let data: Payload
}

struct ErrorEnvelope: Codable {
    struct ErrorBody: Codable {
        let code: String
        let message: String
    }
    let error: ErrorBody
}
