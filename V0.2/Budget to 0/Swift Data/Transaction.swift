//
//  Transaction.swift
//  Budget to 0
//
//  Enhanced transaction model with category support
//

import Foundation

struct Transaction: Identifiable {
    let id: UUID
    var title: String
    var amount: Double
    var isIncome: Bool
    var isPaid: Bool  // Make sure this is VAR not LET
    var dueDate: Date
    var isRecurring: Bool
    var recurrenceFrequency: RecurrenceFrequency
    var customRecurrenceDays: [Int] = []
    var category: TransactionCategory
    var notes: String
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, amount: Double, isIncome: Bool, isPaid: Bool, dueDate: Date, isRecurring: Bool, recurrenceFrequency: RecurrenceFrequency, customRecurrenceDays: [Int] = [], category: TransactionCategory, notes: String = "", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.isPaid = isPaid
        self.dueDate = dueDate
        self.isRecurring = isRecurring
        self.recurrenceFrequency = recurrenceFrequency
        self.customRecurrenceDays = customRecurrenceDays  // ADD THIS LINE
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
    }

    
    // Generate next occurrence for recurring transactions
    func nextOccurrence() -> Transaction? {
        guard isRecurring else { return nil }
        
        let calendar = Calendar.current
        var nextDate: Date?
        
        switch recurrenceFrequency {
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
        case .biweekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 2, to: dueDate)
        case .monthly:
            nextDate = calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .bimonthly:
            nextDate = calendar.date(byAdding: .month, value: 2, to: dueDate)
        case .semiMonthly:
            nextDate = calendar.date(byAdding: .day, value: 15, to: dueDate)
        case .customDays:
            nextDate = calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .yearly:
            nextDate = calendar.date(byAdding: .year, value: 1, to: dueDate)
        case .oneTime:
            return nil
        }
        
        guard let date = nextDate else { return nil }
        
        return Transaction(
            title: title,
            amount: amount,
            isIncome: isIncome,
            isPaid: false,
            dueDate: date,
            isRecurring: isRecurring,
            recurrenceFrequency: recurrenceFrequency,
            category: category,
            notes: notes
        )
    }
}

enum RecurrenceFrequency: String, CaseIterable {
    case oneTime = "One Time"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case bimonthly = "Bimonthly"
    case semiMonthly = "Semi-Monthly (1st & 15th)"
    case customDays = "Custom Days of Month"
    case yearly = "Yearly"
}

enum TransactionCategory: String, CaseIterable, Codable {
    case housing = "Housing"
    case utilities = "Utilities"
    case transportation = "Transportation"
    case insurance = "Insurance"
    case food = "Food & Groceries"
    case entertainment = "Entertainment"
    case healthcare = "Healthcare"
    case debt = "Debt Payments"
    case savings = "Savings"
    case income = "Income"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .transportation: return "car.fill"
        case .insurance: return "shield.fill"
        case .food: return "cart.fill"
        case .entertainment: return "sparkles"
        case .healthcare: return "cross.case.fill"
        case .debt: return "creditcard.fill"
        case .savings: return "banknote.fill"
        case .income: return "dollarsign.circle.fill"
        case .other: return "tag.fill"
        }
    }
    
    var color: String {
        switch self {
        case .housing: return "blue"
        case .utilities: return "yellow"
        case .transportation: return "purple"
        case .insurance: return "green"
        case .food: return "orange"
        case .entertainment: return "pink"
        case .healthcare: return "red"
        case .debt: return "indigo"
        case .savings: return "mint"
        case .income: return "green"
        case .other: return "gray"
        }
    }
}
