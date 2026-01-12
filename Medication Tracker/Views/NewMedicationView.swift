//
//  NewMedicationView.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

struct NewMedicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let username: String
    let vm: MedicationViewModel

    private let maxNameChars: Int = 200
    private let maxDosageChars: Int = 100

    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var frequency: MedicationFrequency = .daily

    @State private var reminderAlert: Bool = false
    @State private var reminderTime1: Date = {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var reminderTime2: Date = {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }()

    @State private var didEditName: Bool = false
    @State private var didEditDosage: Bool = false

    @State private var isSaving: Bool = false
    @State private var localError: String?

    @State private var showingNotificationsDenied: Bool = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDosage: String { dosage.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var nameTooLong: Bool { trimmedName.count > maxNameChars }
    private var dosageTooLong: Bool { trimmedDosage.count > maxDosageChars }

    private var nameTooShort: Bool { didEditName && trimmedName.isEmpty }
    private var dosageTooShort: Bool { didEditDosage && trimmedDosage.isEmpty }

    private var isValid: Bool {
        !trimmedName.isEmpty &&
        !trimmedDosage.isEmpty &&
        trimmedName.count <= maxNameChars &&
        trimmedDosage.count <= maxDosageChars
    }

    private var showsReminders: Bool { frequency != .as_needed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "pills")
                                .font(.headline)
                            Text("Medication")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            TextField("e.g. Aspirin", text: $name)
                                .textInputAutocapitalization(.words)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: name) { _, _ in
                                    didEditName = true
                                }

                            if nameTooShort {
                                Text("Name is required.")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            } else if nameTooLong {
                                Text("Name must be \(maxNameChars) characters or less.")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "scalemass")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Dosage")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            TextField("e.g. 100mg", text: $dosage)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: dosage) { _, _ in
                                    didEditDosage = true
                                }

                            if dosageTooShort {
                                Text("Dosage is required.")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            } else if dosageTooLong {
                                Text("Dosage must be \(maxDosageChars) characters or less.")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }

                        HStack(alignment: .center, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "repeat")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Frequency")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("Frequency", selection: $frequency.animation()) {
                                ForEach(MedicationFrequency.allCases) { f in
                                    Text(f.title)
                                        .tag(f)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(16)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if showsReminders {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell")
                                    .font(.headline)
                                Text("Reminders")
                                    .font(.headline)
                            }

                            Toggle("Remind me", isOn: $reminderAlert.animation())

                            if reminderAlert {
                                DatePicker(
                                    "Time",
                                    selection: $reminderTime1,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.compact)

                                if frequency == .twice_daily {
                                    DatePicker(
                                        "Second time",
                                        selection: $reminderTime2,
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    .datePickerStyle(.compact)
                                }
                            }
                        }
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let localError {
                        Text(localError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await addMedication() }
                    } label: {
                        Text("Add Medication")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.medicationTracker)
                    .controlSize(.large)
                    .disabled(!isValid || isSaving)
                }
                .padding(16)
            }
            .navigationTitle("New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: frequency) { _, newValue in
                if newValue == .as_needed {
                    reminderAlert = false
                }
                if newValue != .twice_daily {
                    reminderTime2 = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
                }
            }
            .onChange(of: reminderAlert) { _, newValue in
                guard newValue else { return }
                guard showsReminders else {
                    reminderAlert = false
                    return
                }
                Task {
                    let ok = await ensureNotificationPermission()
                    if !ok {
                        reminderAlert = false
                        showingNotificationsDenied = true
                    }
                }
            }
            .alert("Notifications are off", isPresented: $showingNotificationsDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to use medication reminders.")
            }
        }
    }

    private func ensureNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return granted
            } catch {
                return false
            }
        default:
            return false
        }
    }

    private func addMedication() async {
        didEditName = true
        didEditDosage = true
        guard isValid else { return }
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        localError = nil

        if showsReminders, reminderAlert {
            let ok = await ensureNotificationPermission()
            if !ok {
                reminderAlert = false
                showingNotificationsDenied = true
                return
            }
        }

        let now = Date()

        do {
            let med = Medication(
                username: username,
                name: trimmedName,
                dosage: trimmedDosage,
                frequency: frequency,
                createdAt: now,
                updatedAt: now,
                status: .active,
                reminderAlert: (frequency == .as_needed) ? false : reminderAlert,
                reminderTime1: (frequency == .as_needed || !reminderAlert) ? nil : reminderTime1,
                reminderTime2: (frequency == .twice_daily && reminderAlert) ? reminderTime2 : nil
            )

            modelContext.insert(med)
            try modelContext.save()

            dismiss()

            Task {
                await vm.syncAll(username: username)
            }
        } catch {
            localError = String(describing: error)
        }
    }
}
