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
    
    init(id: UUID = UUID(), title: String, amount: Double, isIncome: Bool, recurrenceFrequency: RecurrenceFrequency, category: TransactionCategory, notes: String = "", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.recurrenceFrequency = recurrenceFrequency
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
    }
}
