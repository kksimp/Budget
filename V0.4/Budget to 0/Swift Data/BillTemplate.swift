//
//  BillTemplate.swift
//  Budget to 0
//
//  Template model for recurring bills and income
//

import Foundation

struct BillTemplate: Identifiable, Codable {
    let id: UUID
    var title: String
    var amount: Double
    var isIncome: Bool
    var recurrenceFrequency: RecurrenceFrequency
    var category: TransactionCategory
    var notes: String
    var createdAt: Date
    
    // Date fields for different frequency types
    var dueDay: Int? // For monthly/bimonthly (1-31)
    var startDate: Date? // For weekly/biweekly (the first occurrence)
    var semiMonthlyDay1: Int? // For semi-monthly (first day, e.g., 1)
    var semiMonthlyDay2: Int? // For semi-monthly (second day, e.g., 15)
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        isIncome: Bool,
        recurrenceFrequency: RecurrenceFrequency,
        category: TransactionCategory,
        notes: String = "",
        createdAt: Date = Date(),
        dueDay: Int? = nil,
        startDate: Date? = nil,
        semiMonthlyDay1: Int? = nil,
        semiMonthlyDay2: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.recurrenceFrequency = recurrenceFrequency
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
        self.dueDay = dueDay
        self.startDate = startDate
        self.semiMonthlyDay1 = semiMonthlyDay1
        self.semiMonthlyDay2 = semiMonthlyDay2
    }
}
