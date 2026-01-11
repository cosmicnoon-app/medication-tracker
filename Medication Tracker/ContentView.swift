//
//  ContentView.swift
//  Medication Tracker
//

import SwiftUI

struct ContentView: View {
    let vm: MedicationViewModel
    let username: String

    var body: some View {
        MedicationListView(
            username: username,
            vm: vm
        )
    }
}
