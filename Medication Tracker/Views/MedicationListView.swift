//
//  MedicationListView.swift
//  Medication Tracker
//
//  Created by Michael Fuhrmann on 11/1/2026.
//

import SwiftUI
import SwiftData

struct MedicationListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: \Medication.updatedAt,
        order: .reverse
    )
    
    private var medications: [Medication]

    @State private var selection: Medication?
    @State private var vm: MedicationViewModel
    @State private var showingAddMedication: Bool = false

    private let username: String

    init(username: String, vm: MedicationViewModel) {
        self.username = username
        _vm = State(initialValue: vm)
    }

    var body: some View {
        NavigationSplitView {
            Group {
                let visibleMeds = medications.filter { $0.status == .active }

                if medications.isEmpty {
                    ContentUnavailableView {
                        Label("No medications", systemImage: "pills")
                    } description: {
                        Text("Add your first medication to start tracking.")
                    } actions: {
                        Button {
                            showingAddMedication = true
                        } label: {
                            Label("Add Medication", systemImage: "plus")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.medicationTracker)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
    #if os(iOS)
                        if #available(iOS 26.0, *) {
                            EmptyView()
                        } else {
                            Spacer()
                                .frame(maxHeight: 5)
                        }
    #else
                        Spacer()
                            .frame(maxHeight: 30)
    #endif

                        List(selection: $selection) {
                            ForEach(visibleMeds) { med in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(med.name)
                                            .font(.headline)
                                        Text(med.dosage)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(med.frequency.title)
                                        .font(.subheadline)
                                }
                                .tag(med)
                            }
                            .onDelete(perform: deleteLocal)
                        }
                    }
    #if os(iOS)
                    .background(Color(uiColor: .systemGroupedBackground))
    #endif
                }
            }
            .navigationTitle("Medications")
            .toolbarTitleDisplayMode(.inlineLarge)
    #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
    #endif
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAddMedication = true
                    } label: {
    #if os(iOS)
                        if #available(iOS 26.0, *) {
                            Image(systemName: "plus")
                                .foregroundStyle(.black)
                        } else {
                            Image(systemName: "plus")
                        }
    #else
                        Image(systemName: "plus")
    #endif
                    }
    #if os(iOS)
                    .tint(
                        {
                            if #available(iOS 26.0, *) { return nil }
                            return Color.white
                        }()
                    )
    #endif
                }
            }
            .toolbarBackground(.medicationTracker, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        } detail: {
            Group {
                if let selection {
                    MedicationDetailView(
                        medication: selection,
                        username: username,
                        vm: vm,
                        selection: $selection
                    )
                } else {
                    ContentUnavailableView("Select a medication", systemImage: "pills")
                }
            }
            .toolbarBackground(.medicationTracker, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .refreshable {
            await vm.syncAll(username: username)
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .sheet(isPresented: $showingAddMedication) {
            NewMedicationView(username: username, vm: vm)
        }
    }

    private func deleteLocal(at offsets: IndexSet) {
        let now = Date()

        for idx in offsets {
            let med = medications[idx]
            med.status = .deleted
            med.updatedAt = now
        }

        do {
            try modelContext.save()
        } catch {
            vm.errorMessage = String(describing: error)
            return
        }

        Task {
            await vm.syncAll(username: username)
        }
    }
}
