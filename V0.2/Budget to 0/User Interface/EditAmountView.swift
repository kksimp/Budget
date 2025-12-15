//
//  EditAmountView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 3/2/24.
//
import SwiftUI

extension NumberFormatter {
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }
}

struct EditAmountView: View {
    @Binding var amount: Double
    @Binding var recurrenceFrequency: RecurrenceFrequency

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Amount")) {
                    TextField("Enter amount", value: $amount, formatter: NumberFormatter.currency)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Recurrence Frequency")) {
                    Picker("Frequency", selection: $recurrenceFrequency) {
                        ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarItems(trailing: Button("Done", action: {}))
        }
    }
    
}
