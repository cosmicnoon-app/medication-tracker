//
//  MedicationRepository.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//


import Foundation

protocol MedicationRepository: Sendable {
    func fetchMedications(username: String) async throws -> [MedicationDTO]

    func createMedication(
        username: String,
        name: String,
        dosage: String,
        frequency: MedicationFrequency
    ) async throws -> MedicationDTO

    func updateMedication(
        username: String,
        id: String,
        name: String?,
        dosage: String?,
        frequency: MedicationFrequency?
    ) async throws -> MedicationDTO

    func deleteMedication(username: String, id: String) async throws
}

final class DefaultMedicationRepository: MedicationRepository {
    private let api: MedicationAPIClient
    private let store: MedicationStore

    init(api: MedicationAPIClient, store: MedicationStore) {
        self.api = api
        self.store = store
    }

    func fetchMedications(username: String) async throws -> [MedicationDTO] {
        let meds = try await api.listMedications(username: username)
        try store.upsert(meds)
        try store.save()
        return meds
    }

    func createMedication(
        username: String,
        name: String,
        dosage: String,
        frequency: MedicationFrequency
    ) async throws -> MedicationDTO {
        let created = try await api.createMedication(
            username: username,
            body: CreateMedicationRequest(name: name, dosage: dosage, frequency: frequency)
        )
        try store.upsert([created])
        try store.save()
        return created
    }

    func updateMedication(
        username: String,
        id: String,
        name: String?,
        dosage: String?,
        frequency: MedicationFrequency?
    ) async throws -> MedicationDTO {
        let updated = try await api.updateMedication(
            username: username,
            id: id,
            body: UpdateMedicationRequest(name: name, dosage: dosage, frequency: frequency)
        )
        try store.upsert([updated])
        try store.save()
        return updated
    }

    func deleteMedication(username: String, id: String) async throws {
        try await api.deleteMedication(username: username, id: id)
        try store.deleteLocal(id: id)
        try store.save()
    }
}

protocol MedicationStore: Sendable {
    func upsert(_ remote: [MedicationDTO]) throws
    func deleteLocal(id: String) throws
    func save() throws
}
