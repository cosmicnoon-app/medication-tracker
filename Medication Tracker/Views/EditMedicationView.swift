//
//  EditMedicationView.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import SwiftData
import SwiftUI
import UserNotifications

struct EditMedicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let medication: Medication
    let username: String
    let vm: MedicationViewModel
    
    @State private var name: String
    @State private var dosage: String
    @State private var frequency: MedicationFrequency
    
    @State private var reminderAlert: Bool
    @State private var reminderTime1: Date
    @State private var reminderTime2: Date
    
    @State private var localError: String?
    
    @State private var showingNotificationsDenied: Bool = false
    
    init(medication: Medication, username: String, vm: MedicationViewModel) {
        self.medication = medication
        self.username = username
        self.vm = vm
        
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        _frequency = State(initialValue: medication.frequency)
        
        let defaultT1 = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let defaultT2 = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
        
        _reminderAlert = State(initialValue: medication.reminderAlert)
        _reminderTime1 = State(initialValue: medication.reminderTime1 ?? defaultT1)
        _reminderTime2 = State(initialValue: medication.reminderTime2 ?? defaultT2)
    }
    
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDosage: String { dosage.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    private var isValid: Bool {
        !trimmedName.isEmpty &&
        !trimmedDosage.isEmpty &&
        trimmedName.count <= 200 &&
        trimmedDosage.count <= 100
    }
    
    private var showsReminders: Bool { frequency != .as_needed }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Medication")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextField("e.g. Aspirin", text: $name)
                                .textInputAutocapitalization(.words)
                                .textFieldStyle(.roundedBorder)
                            
                            if trimmedName.count > 200 {
                                Text("Name must be 200 characters or less.")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dosage")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextField("e.g. 100mg", text: $dosage)
                                .textFieldStyle(.roundedBorder)
                            
                            if trimmedDosage.count > 100 {
                                Text("Dosage must be 100 characters or less.")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        HStack(alignment: .center, spacing: 6) {
                            Text("Frequency")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("Frequency", selection: $frequency.animation()) {
                                ForEach(MedicationFrequency.allCases) { f in
                                    Text(f.title).tag(f)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(16)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    if showsReminders {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reminders")
                                .font(.headline)
                            
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
                        save()
                    } label: {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.medicationTracker)
                    .controlSize(.large)
                    .disabled(!isValid)
                }
                .padding(16)
            }
            .navigationTitle("Edit Medication")
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
    
    private func save() {
        guard isValid else { return }

        Task {
            if showsReminders, reminderAlert {
                let ok = await ensureNotificationPermission()
                if !ok {
                    await MainActor.run {
                        reminderAlert = false
                        showingNotificationsDenied = true
                    }
                    return
                }
            }

            let saveSucceeded: Bool = await MainActor.run {
                medication.name = trimmedName
                medication.dosage = trimmedDosage
                medication.frequency = frequency
                medication.updatedAt = Date()

                if frequency == .as_needed {
                    medication.reminderAlert = false
                    medication.reminderTime1 = nil
                    medication.reminderTime2 = nil
                } else {
                    medication.reminderAlert = reminderAlert
                    medication.reminderTime1 = reminderAlert ? reminderTime1 : nil
                    medication.reminderTime2 = (reminderAlert && frequency == .twice_daily) ? reminderTime2 : nil
                }

                do {
                    try modelContext.save()
                    return true
                } catch {
                    localError = String(describing: error)
                    return false
                }
            }

            guard saveSucceeded else { return }

            await vm.syncAll(username: username)

            let uname = username
            let reminders: [MedicationNotificationScheduler.MedicationReminderInfo] = await MainActor.run {
                let meds: [Medication] = (try? modelContext.fetch(FetchDescriptor<Medication>())) ?? []

                return meds.map { m in
                    MedicationNotificationScheduler.MedicationReminderInfo(
                        id: m.id,
                        username: m.username,
                        name: m.name,
                        dosage: m.dosage,
                        frequency: m.frequency,
                        isActive: (m.status == .active),
                        reminderAlert: m.reminderAlert,
                        reminderTime1: m.reminderTime1,
                        reminderTime2: m.reminderTime2
                    )
                }
            }

            await MedicationNotificationScheduler.shared.rescheduleAll(
                username: uname,
                reminders: reminders
            )

            await MainActor.run {
                dismiss()
            }
        }
    }
}
