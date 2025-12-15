//
//  IncomeView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/3/24.
//

import SwiftUI

struct IncomeView: View {
    @ObservedObject var dataManager: DataManager
    @State private var newIncomeTitle = ""
    @State private var newIncomeAmount = ""
    @State private var newIncomeRecurrenceFrequency = ""
    @State private var isAddIncomeSheetPresented = false
    
    var body: some View {
        NavigationView {
            VStack {
                if dataManager.income.isEmpty {
                    Text("To add income, please press the plus at the top right.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(dataManager.income) { income in
                        VStack(alignment: .leading) {
                            Text(income.title)
                            Text("Amount: \(formattedAmount(income.amount))")
                            
                            HStack {
                                Button(action: {
                                    markAsPaid(income: income)
                                }) {
                                    Text("Mark as Paid")
                                }
                                .foregroundColor(income.paid ? .green : .blue)
                                
                                
                            }}
                    }
                }
            }
            .navigationBarTitle("Income")
            .navigationBarItems(trailing:
                                    Button(action: {
                isAddIncomeSheetPresented.toggle()
            }) {
                Image(systemName: "plus")
            }
            )
            .sheet(isPresented: $isAddIncomeSheetPresented, content: {
                AddIncomeView(dataManager: dataManager, isPresented: $isAddIncomeSheetPresented, title: $newIncomeTitle, amount: $newIncomeAmount)
            })
        }
    }
    
    private func formattedAmount(_ amount: Double) -> String {
        String(format: "%.2f", amount)
    }
    
    
    private func markAsPaid(income: Expense) {
        if let index = dataManager.income.firstIndex(where: { $0.id == income.id }) {
            dataManager.income[index].paid.toggle()
        }
    }
    
    private func toggleRecurring(income: Expense) {
        if let index = dataManager.income.firstIndex(where: { $0.id == income.id }) {
            dataManager.income[index].recurring.toggle()
        }
    }
    
    private func addNewIncome() {
        guard let amount = Double(newIncomeAmount), let selectedRecurrenceFrequency = RecurrenceFrequency(rawValue: newIncomeRecurrenceFrequency) else {
            return
        }
        
        let newIncome = Expense(
            title: newIncomeTitle,
            amount: amount,
            recurring: true,
            paid: false,
            dueDate: Date(),
            recurrenceFrequency: selectedRecurrenceFrequency
        )
        
        dataManager.income.append(newIncome)
        newIncomeTitle = ""
        newIncomeAmount = ""
        newIncomeRecurrenceFrequency = "" // Reset the recurrence frequency
    }
    
    
    
}
