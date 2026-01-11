//
//  MedicationSyncActor.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import Foundation
import SwiftData
import SwiftUI

@ModelActor
actor MedicationSyncActor {

    // MARK: - Public API

    func syncMed(id: String, username: String) async throws {
        guard let local = try fetchLocal(id: id, username: username) else { return }

        let api = await makeAPI()

        // Deleted locally -> delete remotely (best effort) -> delete locally ONLY if remote delete succeeded or 404
        if local.status == .deleted {
            let didDeleteLocally = try await deleteRemoteThenMaybeDeleteLocal(
                username: username,
                id: local.id,
                local: local,
                api: api
            )
            if didDeleteLocally {
                try modelContext.save()
            }
            return
        }

        do {
            let remote = try await api.getMedication(username: username, id: local.id)
            try await reconcile(local: local, remote: remote, api: api)
        } catch let error as APIError {
            if error.isNotFound {
                let created = try await api.createMedication(
                    username: username,
                    body: CreateMedicationRequest(
                        name: local.name,
                        dosage: local.dosage,
                        frequency: local.frequency
                    )
                )
                applyRemote(created, to: local)
            } else {
                throw error
            }
        }

        try modelContext.save()
    }

    func syncAllMeds(username: String) async throws {
            let api = await makeAPI()

            // 1) Pull everything remote and upsert locally (brings down meds that don't exist locally)
            let remotes = try await api.listMedications(username: username)

            var remoteById: [String: MedicationDTO] = [:]
            remoteById.reserveCapacity(remotes.count)
            for r in remotes { remoteById[r.id] = r }

            for remote in remotes {
                if let local = try fetchLocal(id: remote.id, username: username) {
                    if local.status == .deleted {
                        // Locally marked deleted -> delete remotely, delete locally ONLY if remote delete succeeded or 404
                        _ = try await deleteRemoteThenMaybeDeleteLocal(
                            username: username,
                            id: local.id,
                            local: local,
                            api: api
                        )
                    } else {
                        try await reconcile(local: local, remote: remote, api: api)
                    }
                } else {
                    let inserted = Medication(
                        id: remote.id,
                        username: remote.username,
                        name: remote.name,
                        dosage: remote.dosage,
                        frequency: remote.frequency,
                        createdAt: remote.createdAt,
                        updatedAt: remote.updatedAt,
                        status: .active
                    )
                    modelContext.insert(inserted)
                }
            }

            // 2) Push any local meds that are not on the server (or handle deletions)
            let locals = try fetchAllLocal(username: username)
            for local in locals {
                if local.status == .deleted {
                    // delete remotely, delete locally ONLY if remote delete succeeded or 404
                    _ = try await deleteRemoteThenMaybeDeleteLocal(
                        username: username,
                        id: local.id,
                        local: local,
                        api: api
                    )
                    continue
                }

                if remoteById[local.id] == nil {
                    let created = try await api.createMedication(
                        username: username,
                        body: CreateMedicationRequest(
                            name: local.name,
                            dosage: local.dosage,
                            frequency: local.frequency
                        )
                    )
                    applyRemote(created, to: local)
                }
            }

            try modelContext.save()
        }

    // MARK: - Reconciliation

    private func reconcile(
        local: Medication,
        remote: MedicationDTO,
        api: MedicationAPIClient
    ) async throws {
        if remote.updatedAt > local.updatedAt {
            applyRemote(remote, to: local)
            return
        }

        if local.updatedAt > remote.updatedAt {
            let updated = try await api.updateMedication(
                username: local.username,
                id: local.id,
                body: UpdateMedicationRequest(
                    name: local.name,
                    dosage: local.dosage,
                    frequency: local.frequency
                )
            )
            applyRemote(updated, to: local)
        }
    }
    
    
    private func deleteRemoteThenMaybeDeleteLocal(
        username: String,
        id: String,
        local: Medication,
        api: MedicationAPIClient
    ) async throws -> Bool {
        do {
            try await api.deleteMedication(username: username, id: id)
            modelContext.delete(local)
            return true
        } catch let error as APIError {
            if error.isNotFound {
                modelContext.delete(local)
                return true
            }

            // Keep local (still statusRaw == 1) so next sync retries
            throw error
        }
    }

    private func applyRemote(_ remote: MedicationDTO, to local: Medication) {
        local.id = remote.id
        local.username = remote.username
        local.name = remote.name
        local.dosage = remote.dosage
        local.frequency = remote.frequency
        local.createdAt = remote.createdAt
        local.updatedAt = remote.updatedAt
        local.status = .active
    }

    // MARK: - API construction

    private func makeAPI() async -> MedicationAPIClient {
        await MainActor.run { LiveMedicationAPIClient() }
    }

    // MARK: - Fetch helpers

    private func fetchLocal(id: String, username: String) throws -> Medication? {
        var fd = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.id == id && $0.username == username }
        )
        fd.fetchLimit = 1
        return try modelContext.fetch(fd).first
    }

    private func fetchAllLocal(username: String) throws -> [Medication] {
        let fd = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.username == username }
        )
        return try modelContext.fetch(fd)
    }
}
