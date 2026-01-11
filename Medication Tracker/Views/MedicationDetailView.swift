//
//  MedicationDetailView.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import SwiftUI
import SwiftData

struct MedicationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let medication: Medication
    let username: String
    let vm: MedicationViewModel
    @Binding var selection: Medication?
    
    @State private var showingEdit: Bool = false
    @State private var showingDeleteConfirmFromToolbar: Bool = false
    @State private var showingDeleteConfirmFromButton: Bool = false
    private var showsReminders: Bool { medication.frequency != .as_needed }
    
    private var reminderSummary: String {
        guard showsReminders else { return "Not available for As needed." }
        guard medication.reminderAlert else { return "Off" }
        
        let t1 = medication.reminderTime1?.formatted(date: .omitted, time: .shortened) ?? "Not set"
        if medication.frequency == .twice_daily {
            let t2 = medication.reminderTime2?.formatted(date: .omitted, time: .shortened) ?? "Not set"
            return "\(t1) and \(t2)"
        }
        return t1
    }
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: medication.name)
                LabeledContent("Dosage", value: medication.dosage)
                LabeledContent("Frequency", value: medication.frequency.title)
            } header: {
                Label("Medication", systemImage: "pills")
            }

            if showsReminders {
                Section {
                    LabeledContent("Remind me", value: medication.reminderAlert ? "On" : "Off")

                    if medication.reminderAlert {
                        if let t1 = medication.reminderTime1 {
                            LabeledContent("Time", value: t1.formatted(date: .omitted, time: .shortened))
                        } else {
                            LabeledContent("Time", value: "Not set")
                        }

                        if medication.frequency == .twice_daily {
                            if let t2 = medication.reminderTime2 {
                                LabeledContent("Second time", value: t2.formatted(date: .omitted, time: .shortened))
                            } else {
                                LabeledContent("Second time", value: "Not set")
                            }
                        }
                    }
                } header: {
                    Label("Reminders", systemImage: "bell")
                }
            }

            Section {
                LabeledContent("Created", value: medication.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Updated", value: medication.updatedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("User", value: medication.username)
            } header: {
                Label("Metadata", systemImage: "info.circle")
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmFromButton = true
                } label: {
                    Text("Delete Medication")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .confirmationDialog(
                    "Delete this medication?",
                    isPresented: $showingDeleteConfirmFromButton,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) { deleteMedication() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove it from your medications. It cannot be undone.")
                }
                .listRowBackground(Color.clear)
            } header: {
                EmptyView()
            }
        }
        .navigationTitle(medication.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingDeleteConfirmFromToolbar = true
                } label: {
    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Image(systemName: "trash")
                    } else {
                        Image(systemName: "trash")
                            .foregroundStyle(.white)   // avoids tint bleeding into confirmationDialog
                    }
    #else
                    Image(systemName: "trash")
    #endif
                }
                .confirmationDialog(
                    "Delete this medication?",
                    isPresented: $showingDeleteConfirmFromToolbar,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) { deleteMedication() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove it from your medications. It cannot be undone.")
                }

    #if os(iOS)
                if #available(iOS 26.0, *) {
                    Button("Edit") { showingEdit = true }
                } else {
                    Button {
                        showingEdit = true
                    } label: {
                        Text("Edit")
                            .foregroundStyle(.white)   // avoids tint bleeding into confirmationDialog
                    }
                }
    #else
                Button("Edit") { showingEdit = true }
    #endif
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditMedicationView(medication: medication, username: username, vm: vm)
        }
    #if os(iOS)
        .toolbarColorScheme(
            {
                if #available(iOS 26.0, *) { return nil }
                return ColorScheme.dark
            }(),
            for: .navigationBar
        )
    #endif
    }
    
    private func deleteMedication() {
        withAnimation {
            selection = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            medication.status = .deleted
            medication.updatedAt = Date()
            
            do {
                try modelContext.save()
            } catch {
                return
            }
            
            Task {
                await vm.syncAll(username: username)
            }
        }
    }
}
