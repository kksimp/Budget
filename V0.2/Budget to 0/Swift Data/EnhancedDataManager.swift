//
//  EnhancedDataManager.swift
//  Budget to 0
//
//  Enhanced data manager with SQLite persistence
//

import Foundation
import Combine

class EnhancedDataManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var startingBalance: Double = 0.0
    
    let db = DatabaseManager.shared
    private let startingBalanceKey = "startingBalance"
    
    init() {
        loadData()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        print("📥 Loading data from database...")
        
        // Load transactions
        transactions = db.loadTransactions()
        print("✅ Loaded \(transactions.count) transactions")
        
        // Load starting balance
        if let balanceString = db.loadSetting(key: startingBalanceKey),
           let balance = Double(balanceString) {
            startingBalance = balance
            print("✅ Loaded starting balance: \(balance)")
        } else {
            startingBalance = 0.0
            print("⚠️ No starting balance found, defaulting to 0")
        }
    }
    
    // MARK: - Transaction Management
    
    func addTransaction(_ transaction: Transaction) {
        print("➕ Adding transaction: \(transaction.title)")
        
        if db.saveTransaction(transaction) {
            transactions.append(transaction)
            print("✅ Transaction added to in-memory array")
            
            // Force UI update
            objectWillChange.send()
        } else {
            print("❌ Failed to add transaction to database")
        }
    }
    
    func updateTransaction(_ transaction: Transaction) {
        print("💾 Updating transaction: \(transaction.title)")
        
        if db.updateTransaction(transaction) {
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = transaction
                print("✅ Updated in-memory transaction")
                
                // Force UI update
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to update transaction in database")
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        print("🗑️ Attempting to delete: \(transaction.title)")
        
        if db.deleteTransaction(id: transaction.id) {
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions.remove(at: index)
                print("✅ Removed from in-memory array")
                
                // Force UI update
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to delete transaction from database")
        }
    }
    
    func togglePaidStatus(_ transaction: Transaction) {
        let newStatus = !transaction.isPaid
        print("🔄 Toggling paid status for \(transaction.title) from \(transaction.isPaid) to \(newStatus)")
        
        // Update the transaction
        var updated = transaction
        updated.isPaid = newStatus
        
        if db.updateTransaction(updated) {
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = updated
                print("✅ Updated in-memory transaction paid status")
                
                // Force UI update
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to toggle paid status")
        }
    }
    
    // MARK: - Balance Management
    
    func updateStartingBalance(_ balance: Double) {
        startingBalance = balance
        let success = db.saveSetting(key: startingBalanceKey, value: String(balance))
        
        if success {
            print("✅ Starting balance updated to \(balance)")
        } else {
            print("❌ Failed to update starting balance")
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    func currentBalance() -> Double {
        var balance = startingBalance
        
        // Get ALL transactions that have been paid, sorted by date
        let paidTransactions = transactions
            .filter { $0.isPaid }
            .sorted { $0.dueDate < $1.dueDate }
        
        for transaction in paidTransactions {
            if transaction.isIncome {
                balance += transaction.amount
            } else {
                balance -= transaction.amount
            }
        }
        
        return balance
    }
    
    // MARK: - Monthly Calculations


    func totalIncome(for date: Date) -> Double {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        var total = 0.0
        var processedDates: Set<String> = []
        
        func dateKey(for date: Date, title: String) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(formatter.string(from: date))_\(title)"
        }
        
        // First: Add all one-time income in this month
        for transaction in transactions {
            if !transaction.isRecurring && transaction.isIncome &&
               transaction.dueDate >= startOfMonth && transaction.dueDate <= endOfMonth {
                total += transaction.amount
                processedDates.insert(dateKey(for: transaction.dueDate, title: transaction.title))
            }
        }
        
        // Second: Generate recurring income instances for this month
        for transaction in transactions {
            if transaction.isRecurring && transaction.isIncome {
                let instances = generateRecurringInstances(
                    for: transaction,
                    startDate: startOfMonth,
                    endDate: endOfMonth
                )
                
                for instance in instances {
                    let key = dateKey(for: instance.dueDate, title: instance.title)
                    if !processedDates.contains(key) {
                        total += instance.amount
                    }
                }
            }
        }
        
        return total
    }

    func totalExpenses(for date: Date) -> Double {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        var total = 0.0
        var processedDates: Set<String> = []
        
        func dateKey(for date: Date, title: String) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(formatter.string(from: date))_\(title)"
        }
        
        // First: Add all one-time expenses in this month
        for transaction in transactions {
            if !transaction.isRecurring && !transaction.isIncome &&
               transaction.dueDate >= startOfMonth && transaction.dueDate <= endOfMonth {
                total += transaction.amount
                processedDates.insert(dateKey(for: transaction.dueDate, title: transaction.title))
            }
        }
        
        // Second: Generate recurring expense instances for this month
        for transaction in transactions {
            if transaction.isRecurring && !transaction.isIncome {
                let instances = generateRecurringInstances(
                    for: transaction,
                    startDate: startOfMonth,
                    endDate: endOfMonth
                )
                
                for instance in instances {
                    let key = dateKey(for: instance.dueDate, title: instance.title)
                    if !processedDates.contains(key) {
                        total += instance.amount
                    }
                }
            }
        }
        
        return total
    }

    func netIncome(for date: Date) -> Double {
        return totalIncome(for: date) - totalExpenses(for: date)
    }

    // MARK: - Recurring Instance Generation (for Dashboard calculations)

    private func generateRecurringInstances(for transaction: Transaction, startDate: Date, endDate: Date) -> [Transaction] {
        var instances: [Transaction] = []
        var currentDate = transaction.dueDate
        let calendar = Calendar.current
        
        let maxInstances = 100 // Safety limit
        var count = 0
        
        // Fast-forward to start of range if needed
        while currentDate < startDate && count < maxInstances {
            switch transaction.recurrenceFrequency {
            case .daily:
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
            case .weekly:
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) else { break }
                currentDate = next
            case .biweekly:
                guard let next = calendar.date(byAdding: .weekOfYear, value: 2, to: currentDate) else { break }
                currentDate = next
            case .monthly:
                guard let next = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
                currentDate = next
            case .bimonthly:
                guard let next = calendar.date(byAdding: .month, value: 2, to: currentDate) else { break }
                currentDate = next
            case .semiMonthly:
                guard let next = calendar.date(byAdding: .day, value: 15, to: currentDate) else { break }
                currentDate = next
            case .yearly:
                guard let next = calendar.date(byAdding: .year, value: 1, to: currentDate) else { break }
                currentDate = next
            case .customDays, .oneTime:
                break
            }
            count += 1
        }
        
        // Now generate instances within range
        count = 0
        while currentDate <= endDate && count < maxInstances {
            if currentDate >= startDate && currentDate <= endDate {
                let instance = Transaction(
                    id: UUID(),
                    title: transaction.title,
                    amount: transaction.amount,
                    isIncome: transaction.isIncome,
                    isPaid: false,
                    dueDate: currentDate,
                    isRecurring: transaction.isRecurring,
                    recurrenceFrequency: transaction.recurrenceFrequency,
                    customRecurrenceDays: transaction.customRecurrenceDays,
                    category: transaction.category,
                    notes: transaction.notes,
                    createdAt: transaction.createdAt
                )
                instances.append(instance)
            }
            
            switch transaction.recurrenceFrequency {
            case .daily:
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
            case .weekly:
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) else { break }
                currentDate = next
            case .biweekly:
                guard let next = calendar.date(byAdding: .weekOfYear, value: 2, to: currentDate) else { break }
                currentDate = next
            case .monthly:
                guard let next = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
                currentDate = next
            case .bimonthly:
                guard let next = calendar.date(byAdding: .month, value: 2, to: currentDate) else { break }
                currentDate = next
            case .semiMonthly:
                guard let next = calendar.date(byAdding: .day, value: 15, to: currentDate) else { break }
                currentDate = next
            case .yearly:
                guard let next = calendar.date(byAdding: .year, value: 1, to: currentDate) else { break }
                currentDate = next
            case .customDays, .oneTime:
                break
            }
            
            count += 1
        }
        
        return instances
    }

    
    // MARK: - Upcoming Transactions
    
    func getUpcomingTransactions(days: Int) -> [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let futureDate = calendar.date(byAdding: .day, value: days, to: today)!
        
        return transactions
            .filter { transaction in
                transaction.dueDate >= today && transaction.dueDate <= futureDate && !transaction.isPaid
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
}
