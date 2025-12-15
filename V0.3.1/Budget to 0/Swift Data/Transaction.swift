//
//  Transaction.swift
//  Budget to 0
//
//  Monthly transaction instance (generated from templates or one-time)
//

import Foundation

struct Transaction: Identifiable {
    let id: UUID
    var templateId: UUID? // Links to BillTemplate if generated from template
    var month: Int // 1-12
    var year: Int // e.g., 2024
    var title: String
    var amount: Double
    var isIncome: Bool
    var isPaid: Bool
    var dueDate: Date
    var actualPaymentDate: Date? // When it was actually paid
    var displayOrder: Int // For manual reordering within month
    var category: TransactionCategory
    var notes: String
    var createdAt: Date
    
    init(id: UUID = UUID(), templateId: UUID? = nil, month: Int, year: Int, title: String, amount: Double, isIncome: Bool, isPaid: Bool, dueDate: Date, actualPaymentDate: Date? = nil, displayOrder: Int = 0, category: TransactionCategory, notes: String = "", createdAt: Date = Date()) {
        self.id = id
        self.templateId = templateId
        self.month = month
        self.year = year
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.isPaid = isPaid
        self.dueDate = dueDate
        self.actualPaymentDate = actualPaymentDate
        self.displayOrder = displayOrder
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
    }
}

enum RecurrenceFrequency: String, CaseIterable, Codable {
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
