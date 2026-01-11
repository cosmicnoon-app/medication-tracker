//
//  SwiftDataMedicationStore.swift
//  Medication Tracker
//

import Foundation
import SwiftData

final class SwiftDataMedicationStore: MedicationStore {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func upsert(_ remote: [MedicationDTO]) throws {
        let ctx = ModelContext(container)

        for dto in remote {
            var fd = FetchDescriptor<Medication>(
                predicate: #Predicate { $0.id == dto.id }
            )
            fd.fetchLimit = 1

            if let existing = try ctx.fetch(fd).first {
                existing.username = dto.username
                existing.name = dto.name
                existing.dosage = dto.dosage
                existing.frequency = dto.frequency
                existing.createdAt = dto.createdAt
                existing.updatedAt = dto.updatedAt
            } else {
                ctx.insert(Medication(
                    id: dto.id,
                    username: dto.username,
                    name: dto.name,
                    dosage: dto.dosage,
                    frequency: dto.frequency,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt
                ))
            }
        }

        try ctx.save()
    }

    func deleteLocal(id: String) throws {
        let ctx = ModelContext(container)

        let fd = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.id == id }
        )
        let matches = try ctx.fetch(fd)
        for m in matches {
            ctx.delete(m)
        }

        try ctx.save()
    }

    func save() throws {
        // no-op; each operation saves within its own context
    }
}
