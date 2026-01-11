//
//  MedicationViewModel.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class MedicationViewModel {
    private let repository: MedicationRepository
    private let syncActor: MedicationSyncActor?
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var isSyncing: Bool = false

    init(repository: MedicationRepository, syncActor: MedicationSyncActor?) {
        self.repository = repository
        self.syncActor = syncActor
    }

    func syncAll(username: String) async {
        guard let syncActor else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await syncActor.syncAllMeds(username: username)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func refreshFromAPI(username: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await repository.fetchMedications(username: username)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func createMedication(
        username: String,
        name: String,
        dosage: String,
        frequency: MedicationFrequency
    ) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await repository.createMedication(
                username: username,
                name: name,
                dosage: dosage,
                frequency: frequency
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func updateMedication(
        username: String,
        id: String,
        name: String? = nil,
        dosage: String? = nil,
        frequency: MedicationFrequency? = nil
    ) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await repository.updateMedication(
                username: username,
                id: id,
                name: name,
                dosage: dosage,
                frequency: frequency
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func deleteMedication(username: String, id: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repository.deleteMedication(username: username, id: id)
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
