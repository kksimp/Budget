//
//  BillsView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 1/28/24.
//

import SwiftUI

struct BillsView: View {
    @ObservedObject var dataManager: DataManager
    @State private var newBillTitle = ""
    @State private var newBillAmount = ""
    @State private var isAddBillSheetPresented = false

    var body: some View {
        NavigationView {
            VStack {
                if dataManager.bills.isEmpty {
                    Text("To add a bill, please press the plus at the top right.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(dataManager.bills) { bill in
                        VStack(alignment: .leading) {
                            Text(bill.title)
                            Text("Amount: \(formattedAmount(bill.amount))")

                            HStack {
                                Button(action: {
                                    markAsPaid(bill: bill)
                                }) {
                                    Text("Mark as Paid")
                                }
                                .foregroundColor(bill.paid ? .green : .blue)

                                Spacer()

                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Bills")
            .navigationBarItems(trailing:
                Button(action: {
                    isAddBillSheetPresented.toggle()
                }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $isAddBillSheetPresented, content: {
                AddBillView(dataManager: dataManager, isPresented: $isAddBillSheetPresented, title: $newBillTitle, amount: $newBillAmount)
            })
        }
    }

    private func formattedAmount(_ amount: Double) -> String {
        String(format: "%.2f", amount)
    }
    
    private func markAsPaid(bill: Expense) {
        if let index = dataManager.bills.firstIndex(where: { $0.id == bill.id }) {
            dataManager.bills[index].paid.toggle()
        }
    }
    
    private func toggleRecurring(bill: Expense) {
        if let index = dataManager.bills.firstIndex(where: { $0.id == bill.id }) {
            dataManager.bills[index].recurring.toggle()
        }
    }
    
    private func addNewBill() {
        guard let amount = Double(newBillAmount) else { return }
        let newBill = Expense(title: newBillTitle, amount: amount, recurring: false, paid: false, dueDate: Date(), recurrenceFrequency: .monthly)
        dataManager.bills.append(newBill)
        newBillTitle = ""
        newBillAmount = ""
    }
}

