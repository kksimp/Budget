//
//  Expense.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/3/24.
//

import Foundation

class Expense: Identifiable, ObservableObject {
    var id = UUID()
    var title: String
    var amount: Double
    var recurring: Bool
    var paid: Bool
    var dueDate: Date
    var isIncome: Bool
    var recurrenceFrequency: RecurrenceFrequency

    init(title: String, amount: Double, recurring: Bool, paid: Bool, dueDate: Date, recurrenceFrequency: RecurrenceFrequency) {
        self.title = title
        self.amount = amount
        self.recurring = recurring
        self.paid = paid
        self.dueDate = dueDate
        self.isIncome = amount >= 0
        self.recurrenceFrequency = recurring ? recurrenceFrequency : .oneTime
    }

    func createReoccurringExpenses(for years: Int) -> [Expense] {
        guard recurring else {
            return []
        }

        var reoccurringExpenses: [Expense] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: dueDate)

        for _ in 1...years {
            switch recurrenceFrequency {
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

            let reoccurringExpense = Expense(
                title: title,
                amount: amount,
                recurring: true,
                paid: false,
                dueDate: currentDate,
                recurrenceFrequency: recurrenceFrequency
            )

            reoccurringExpenses.append(reoccurringExpense)
        }

        return reoccurringExpenses
    }
}




