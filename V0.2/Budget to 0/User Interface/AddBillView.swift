//
//  AddBillView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 1/28/24.
//
import SwiftUI

struct AddBillView: View {
    @ObservedObject var dataManager: DataManager
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var amount: String

    @State private var dueDate = Date()
    @State private var selectedRecurrence = RecurrenceFrequency.oneTime
    @State private var firstRecurrenceDate = Date()
    @State private var secondRecurrenceDate = Date()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Recurrence")) {
                    Picker("Recurrence Frequency", selection: $selectedRecurrence) {
                        ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue)
                        }
                    }

                    if selectedRecurrence == .bimonthly {
                        DatePicker("First Recurrence Date", selection: $firstRecurrenceDate, in: Date()..., displayedComponents: .date)
                        DatePicker("Second Recurrence Date", selection: $secondRecurrenceDate, in: Date()..., displayedComponents: .date)
                    } else {
                        DatePicker("Due Date", selection: $dueDate, in: Date()..., displayedComponents: .date)
                    }
                }

                Section {
                    Button("Save") {
                        addNewBill()
                    }
                }
            }
            .navigationBarTitle("Add Bill")
        }
    }

    private func addNewBill() {
        guard let amountDouble = Double(amount) else { return }

        let newExpense = Expense(
            title: title,
            amount: amountDouble,
            recurring: selectedRecurrence != .oneTime,
            paid: false,
            dueDate: selectedRecurrence == .bimonthly ? firstRecurrenceDate : dueDate,
            recurrenceFrequency: selectedRecurrence
        )

        dataManager.bills.append(newExpense)
        isPresented = false // Close the sheet
    }
}

