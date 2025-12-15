//
//  DataManager.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/3/24.
//

import Foundation
import Combine

class DataManager: ObservableObject {
    @Published var bills: [Expense] = []
    @Published var income: [Expense] = []
    @Published var manuallySetBalance: Double? = nil
    
    func markExpenseAsPaid(_ expense: Expense) {
        if let index = bills.firstIndex(where: { $0.id == expense.id }) {
            bills[index].paid = true
        } else if let index = income.firstIndex(where: { $0.id == expense.id }) {
            income[index].paid = true
        }
    }
    
    func createReoccurringExpenses(for expense: Expense, years: Int) {
        guard expense.recurring else {
            return
        }
        
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: expense.dueDate)
        
        for _ in 1...years {
            let reoccurringExpense = Expense(
                title: expense.title,
                amount: expense.amount,
                recurring: true,
                paid: false,
                dueDate: currentDate,
                recurrenceFrequency: expense.recurrenceFrequency
            )
            
            if expense.isIncome {
                income.append(reoccurringExpense)
            } else {
                bills.append(reoccurringExpense)
            }
            
            switch expense.recurrenceFrequency {
            case .oneTime:
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case .daily:
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case .weekly:
                currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            case .biweekly:
                currentDate = calendar.date(byAdding: .weekOfYear, value: 2, to: currentDate) ?? currentDate
            case .monthly:
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            case .bimonthly:
                currentDate = calendar.date(byAdding: .month, value: 2, to: currentDate) ?? currentDate
            case .yearly:
                currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
            }
        }
    }
}

