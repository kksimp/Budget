//
//  CalendarView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/3/24.
//


import SwiftUI

struct CalendarView: View {
    @ObservedObject var dataManager: DataManager
    @State private var currentBalance: Double = 0.0
    @State private var showChangeBalanceView = false
    @State private var selectedExpense: Expense?
    @State private var editedAmount: String = ""

    var body: some View {
        NavigationView {
            VStack {
                balanceView
                expensesList
            }
            .onAppear(perform: updateBalance)
            .navigationBarTitle("Calendar")
        }
    }

    private var balanceView: some View {
        HStack {
            Spacer()
            Text("Balance: \(String(format: "%.2f", currentBalance))")
                .padding()
                .onTapGesture {
                    showChangeBalanceView.toggle()
                }
        }
        .background(Color.gray.opacity(0.2))
        .sheet(isPresented: $showChangeBalanceView) {
            ChangeBalanceView(currentBalance: $currentBalance)
        }
    }

    private var expensesList: some View {
        List(sortedExpenses(), id: \.id) { (expense: Expense) in
            VStack(alignment: .leading) {
                Text(formattedDate(expense.dueDate))
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Text("Amount: \(String(format: "%.2f", expense.amount))")
                        .foregroundColor(.blue)

                    Spacer()

                    TextField("Edit Amount", text: $editedAmount, onCommit: {
                        if let editedAmountDouble = Double(editedAmount) {
                            updateExpenseAmount(expense, newAmount: editedAmountDouble)
                        }
                        editedAmount = ""
                        selectedExpense = nil
                    })
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .onTapGesture {
                selectedExpense = expense
                editedAmount = String(format: "%.2f", expense.amount)
            }
        }
    }

    private func updateBalance() {
        let totalIncome = dataManager.income.filter { !$0.paid }.reduce(0) { $0 + $1.amount }
        let totalBills = dataManager.bills.filter { !$0.paid }.reduce(0) { $0 + $1.amount }

        currentBalance = totalIncome - totalBills
    }

    private func sortedExpenses() -> [Expense] {
        var allExpenses = dataManager.bills + dataManager.income

        // Add reoccurring bills for the next 5 years
        for bill in dataManager.bills {
            allExpenses.append(contentsOf: bill.createReoccurringExpenses(for: 20))
        }

        // Add reoccurring income for the next 5 years
        for income in dataManager.income {
            allExpenses.append(contentsOf: income.createReoccurringExpenses(for: 20))
        }

        return allExpenses.sorted { (expense1, expense2) -> Bool in
            if Calendar.current.isDate(expense1.dueDate, inSameDayAs: expense2.dueDate) {
                return expense1.isIncome && !expense2.isIncome
            }
            return expense1.dueDate < expense2.dueDate
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy"
        return dateFormatter.string(from: date)
    }

    private func updateExpenseAmount(_ expense: Expense, newAmount: Double) {
        if let index = dataManager.bills.firstIndex(where: { $0.id == expense.id }) {
            dataManager.bills[index].amount = newAmount
        } else if let index = dataManager.income.firstIndex(where: { $0.id == expense.id }) {
            dataManager.income[index].amount = newAmount
        }
        updateBalance()
    }
}
