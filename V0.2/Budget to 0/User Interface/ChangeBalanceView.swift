//
//  ChangeBalanceView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/7/24.
//

import SwiftUI

struct ChangeBalanceView: View {
    @Binding var currentBalance: Double
    @State private var newBalanceString = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("New Balance", text: $newBalanceString)
                        .keyboardType(.decimalPad)
                }

                Button("Save") {
                    saveNewBalance()
                }
            }
            .navigationBarTitle("Change Balance")
        }
    }

    private func saveNewBalance() {
        guard let newBalance = Double(newBalanceString) else {
            // Handle invalid balance input
            return
        }

        currentBalance = newBalance
    }
}
