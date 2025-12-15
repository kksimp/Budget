//
//  EnhancedDataManager.swift
//  Budget to 0
//
//  Monthly blueprint system with cached balance optimization
//

import Foundation
import Combine

class EnhancedDataManager: ObservableObject {
    @Published var templates: [BillTemplate] = []
    @Published var currentMonthTransactions: [Transaction] = []
    
    let db = DatabaseManager.shared
    
    // Track which month we're currently viewing
    var currentViewingMonth: Int = 0
    var currentViewingYear: Int = 0
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        currentViewingMonth = calendar.component(.month, from: now)
        currentViewingYear = calendar.component(.year, from: now)
        
        loadData()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        print("📥 Loading data from database...")
        
        // Load templates
        templates = db.loadTemplates()
        print("✅ Loaded \(templates.count) templates")
        
        // Load current month's transactions
        loadOrGenerateMonth(month: currentViewingMonth, year: currentViewingYear)
    }
    
    // MARK: - Monthly Transaction Generation
    
    func loadOrGenerateMonth(month: Int, year: Int) {
        print("📅 Loading/generating transactions for \(month)/\(year)")
        
        // Try to load existing transactions for this month
        let existing = db.loadTransactionsForMonth(month: month, year: year)
        
        if !existing.isEmpty {
            print("✅ Found \(existing.count) existing transactions for \(month)/\(year)")
            currentMonthTransactions = existing
        } else {
            print("🔨 Generating new transactions from templates for \(month)/\(year)")
            generateMonthFromTemplates(month: month, year: year)
        }
        
        currentViewingMonth = month
        currentViewingYear = year
        objectWillChange.send()
    }
    
    private func generateMonthFromTemplates(month: Int, year: Int) {
        var newTransactions: [Transaction] = []
        let calendar = Calendar.current
        
        // CRITICAL: Only generate if this month is current month or later
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        let requestedYearMonth = year * 12 + month
        let currentYearMonth = currentYear * 12 + currentMonth
        
        if requestedYearMonth < currentYearMonth {
            print("⚠️ Not generating for \(month)/\(year) - before current month (\(currentMonth)/\(currentYear))")
            return
        }
        
        for template in templates {
            // Determine due date based on template frequency
            let dueDate = calculateDueDate(for: template, month: month, year: year)
            
            let transaction = Transaction(
                templateId: template.id,
                month: month,
                year: year,
                title: template.title,
                amount: template.amount,
                isIncome: template.isIncome,
                isPaid: false,
                dueDate: dueDate,
                actualPaymentDate: nil,
                displayOrder: 0,
                category: template.category,
                notes: template.notes
            )
            
            // Save to database
            if db.saveTransaction(transaction) {
                newTransactions.append(transaction)
            }
        }
        
        print("✅ Generated \(newTransactions.count) transactions for \(month)/\(year)")
        currentMonthTransactions = newTransactions
    }
    
    private func calculateDueDate(for template: BillTemplate, month: Int, year: Int) -> Date {
        let calendar = Calendar.current
        
        switch template.recurrenceFrequency {
        case .monthly:
            // Default to 1st of month
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return calendar.date(from: components) ?? Date()
            
        case .biweekly, .weekly:
            // First occurrence in the month
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return calendar.date(from: components) ?? Date()
            
        case .semiMonthly:
            // 1st and 15th - default to 1st
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return calendar.date(from: components) ?? Date()
            
        case .yearly:
            // Same month/day each year
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return calendar.date(from: components) ?? Date()
            
        default:
            // Default to 1st of month
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return calendar.date(from: components) ?? Date()
        }
    }
    
    // MARK: - Template Management
    
    func addTemplate(_ template: BillTemplate) {
        print("➕ Adding template: \(template.title)")
        
        if db.saveTemplate(template) {
            templates.append(template)
            print("✅ Template added")
            
            // CRITICAL: Generate transaction for current viewing month immediately
            let dueDate = calculateDueDate(for: template, month: currentViewingMonth, year: currentViewingYear)
            
            let transaction = Transaction(
                templateId: template.id,
                month: currentViewingMonth,
                year: currentViewingYear,
                title: template.title,
                amount: template.amount,
                isIncome: template.isIncome,
                isPaid: false,
                dueDate: dueDate,
                actualPaymentDate: nil,
                displayOrder: 0,
                category: template.category,
                notes: template.notes
            )
            
            if db.saveTransaction(transaction) {
                currentMonthTransactions.append(transaction)
                print("✅ Generated transaction for current month")
                
                // Invalidate cache for current month and future
                _ = db.invalidateMonthBalanceFrom(month: currentViewingMonth, year: currentViewingYear)
                
                // Recalculate and cache this month's balance
                recalculateAndCacheMonthBalance(month: currentViewingMonth, year: currentViewingYear)
            }
            
            objectWillChange.send()
        } else {
            print("❌ Failed to add template")
        }
    }
    
    func updateTemplate(_ template: BillTemplate) {
        print("💾 Updating template: \(template.title)")
        
        if db.updateTemplate(template) {
            if let index = templates.firstIndex(where: { $0.id == template.id }) {
                templates[index] = template
                print("✅ Template updated in memory")
                
                // Update the current month's transaction from this template
                if let transactionIndex = currentMonthTransactions.firstIndex(where: { $0.templateId == template.id }) {
                    var updated = currentMonthTransactions[transactionIndex]
                    updated.title = template.title
                    updated.amount = template.amount
                    updated.category = template.category
                    updated.notes = template.notes
                    
                    if db.updateTransaction(updated) {
                        currentMonthTransactions[transactionIndex] = updated
                        print("✅ Updated current month transaction")
                        
                        // Invalidate cache for current month and future
                        _ = db.invalidateMonthBalanceFrom(month: currentViewingMonth, year: currentViewingYear)
                        
                        // Recalculate and cache this month's balance
                        recalculateAndCacheMonthBalance(month: currentViewingMonth, year: currentViewingYear)
                    }
                }
                
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to update template")
        }
    }
    
    func deleteTemplate(_ template: BillTemplate) {
        print("🗑️ Deleting template: \(template.title)")
        
        if db.deleteTemplate(id: template.id) {
            if let index = templates.firstIndex(where: { $0.id == template.id }) {
                templates.remove(at: index)
                print("✅ Template removed from memory")
                
                // Remove current month's transaction from this template
                if let transactionIndex = currentMonthTransactions.firstIndex(where: { $0.templateId == template.id }) {
                    let transaction = currentMonthTransactions[transactionIndex]
                    if db.deleteTransaction(id: transaction.id) {
                        currentMonthTransactions.remove(at: transactionIndex)
                        print("✅ Removed current month transaction")
                        
                        // Invalidate cache for current month and future
                        _ = db.invalidateMonthBalanceFrom(month: currentViewingMonth, year: currentViewingYear)
                        
                        // Recalculate and cache this month's balance
                        recalculateAndCacheMonthBalance(month: currentViewingMonth, year: currentViewingYear)
                    }
                }
                
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to delete template")
        }
    }
    
    // MARK: - Transaction Management (for current month)
    
    func updateTransaction(_ transaction: Transaction) {
        print("💾 Updating transaction: \(transaction.title)")
        
        if db.updateTransaction(transaction) {
            if let index = currentMonthTransactions.firstIndex(where: { $0.id == transaction.id }) {
                currentMonthTransactions[index] = transaction
                print("✅ Transaction updated in memory")
                
                // Invalidate cache for this month and all future months
                _ = db.invalidateMonthBalanceFrom(month: transaction.month, year: transaction.year)
                
                // Recalculate and cache this month's balance
                recalculateAndCacheMonthBalance(month: transaction.month, year: transaction.year)
                
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to update transaction")
        }
    }
    
    func togglePaidStatus(_ transaction: Transaction) {
        let newStatus = !transaction.isPaid
        print("🔄 Toggling paid status for \(transaction.title) to \(newStatus)")
        
        var updated = transaction
        updated.isPaid = newStatus
        
        // If marking as paid, set payment date to today
        if newStatus {
            updated.actualPaymentDate = Date()
        } else {
            updated.actualPaymentDate = nil
        }
        
        updateTransaction(updated)
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        print("🗑️ Deleting transaction: \(transaction.title)")
        
        if db.deleteTransaction(id: transaction.id) {
            if let index = currentMonthTransactions.firstIndex(where: { $0.id == transaction.id }) {
                currentMonthTransactions.remove(at: index)
                print("✅ Transaction removed from memory")
                
                // Invalidate cache for this month and all future months
                _ = db.invalidateMonthBalanceFrom(month: transaction.month, year: transaction.year)
                
                // Recalculate and cache this month's balance
                recalculateAndCacheMonthBalance(month: transaction.month, year: transaction.year)
                
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to delete transaction")
        }
    }
    
    func addOneTimeTransaction(_ transaction: Transaction) {
        print("➕ Adding one-time transaction: \(transaction.title)")
        
        if db.saveTransaction(transaction) {
            // If it's for the current viewing month, add to memory
            if transaction.month == currentViewingMonth && transaction.year == currentViewingYear {
                currentMonthTransactions.append(transaction)
            }
            
            // Invalidate cache for this month and all future months
            _ = db.invalidateMonthBalanceFrom(month: transaction.month, year: transaction.year)
            
            // Recalculate and cache this month's balance
            recalculateAndCacheMonthBalance(month: transaction.month, year: transaction.year)
            
            print("✅ One-time transaction added")
            objectWillChange.send()
        } else {
            print("❌ Failed to add one-time transaction")
        }
    }
    
    // MARK: - Reordering (PERSISTENT!)
    
    func reorderTransactions(from source: IndexSet, to destination: Int) {
        print("🔄 Reordering transactions")
        
        // Get paid and unpaid transactions
        let paid = currentMonthTransactions.filter { $0.isPaid }.sorted {
            ($0.actualPaymentDate ?? $0.dueDate) < ($1.actualPaymentDate ?? $1.dueDate)
        }
        let unpaid = currentMonthTransactions.filter { !$0.isPaid }.sorted { $0.displayOrder < $1.displayOrder }
        
        // Adjust indices for unpaid section
        let paidCount = paid.count
        guard source.allSatisfy({ $0 >= paidCount }) && destination >= paidCount else {
            print("⚠️ Cannot reorder paid transactions")
            return
        }
        
        let adjustedSource = source.map { $0 - paidCount }
        let adjustedDestination = destination - paidCount
        
        var reorderedUnpaid = unpaid
        reorderedUnpaid.move(fromOffsets: IndexSet(adjustedSource), toOffset: adjustedDestination)
        
        // Update displayOrder in database
        for (index, var transaction) in reorderedUnpaid.enumerated() {
            transaction.displayOrder = index
            _ = db.updateTransaction(transaction)
        }
        
        // Reload from database to get fresh data
        currentMonthTransactions = db.loadTransactionsForMonth(month: currentViewingMonth, year: currentViewingYear)
        
        print("✅ Reorder saved to database")
        objectWillChange.send()
    }
    
    // MARK: - Cached Balance Calculation (OPTIMIZED!)
    
    func balanceUpToMonth(month: Int, year: Int) -> Double {
        print("💰 Calculating balance up to \(month)/\(year)")
        
        // STEP 1: Check cache for previous month first
        if month == 1 {
            // January - check December of previous year
            if let cachedBalance = db.loadMonthBalance(month: 12, year: year - 1) {
                print("  ✅ Using cached December \(year - 1) balance: \(cachedBalance)")
                return cachedBalance
            }
        } else {
            // Any other month - check previous month
            let prevMonth = month - 1
            if let cachedBalance = db.loadMonthBalance(month: prevMonth, year: year) {
                print("  ✅ Using cached \(prevMonth)/\(year) balance: \(cachedBalance)")
                return cachedBalance
            }
        }
        
        // STEP 2: No cache - need to calculate from scratch
        print("  ⚠️ No cache found, calculating from scratch...")
        
        // Find the FIRST month that has ANY transactions
        guard let earliestDate = db.getEarliestTransactionDate() else {
            print("  ⚠️ No transactions in database, starting at 0")
            return 0.0
        }
        
        let startYear = earliestDate.year
        let startMonth = earliestDate.month
        
        print("  📅 First transaction found: \(startMonth)/\(startYear)")
        
        let targetYearMonth = year * 12 + month
        let startYearMonth = startYear * 12 + startMonth
        
        // STEP 3: If target month is BEFORE first transaction, return 0
        if targetYearMonth < startYearMonth {
            print("  ⚠️ Target month (\(month)/\(year)) is BEFORE first transaction (\(startMonth)/\(startYear)), returning 0")
            return 0.0
        }
        
        // STEP 4: Calculate from first transaction month to target month (exclusive)
        print("  📅 Calculating from \(startMonth)/\(startYear) to \(month)/\(year)")
        
        var balance = 0.0
        var currentYear = startYear
        var currentMonth = startMonth
        
        while (currentYear * 12 + currentMonth) < targetYearMonth {
            // Check cache first
            if let cachedBalance = db.loadMonthBalance(month: currentMonth, year: currentYear) {
                print("    ✅ Cache hit for \(currentMonth)/\(currentYear): \(cachedBalance)")
                balance = cachedBalance
                
                // Jump to next month
                currentMonth += 1
                if currentMonth > 12 {
                    currentMonth = 1
                    currentYear += 1
                }
                continue
            }
            
            // No cache - calculate this month
            let transactions = db.loadTransactionsForMonth(month: currentMonth, year: currentYear)
            let paidTransactions = transactions.filter { $0.isPaid }
            
            if !paidTransactions.isEmpty {
                print("    📊 \(currentMonth)/\(currentYear): Processing \(paidTransactions.count) paid transactions (starting: \(balance))")
                
                for transaction in paidTransactions {
                    if transaction.isIncome {
                        balance += transaction.amount
                        print("      ✅ +\(transaction.amount) (\(transaction.title))")
                    } else {
                        balance -= transaction.amount
                        print("      ❌ -\(transaction.amount) (\(transaction.title))")
                    }
                }
                
                // ONLY cache if we actually processed transactions
                _ = db.saveMonthBalance(month: currentMonth, year: currentYear, endingBalance: balance)
                print("    💾 Cached \(currentMonth)/\(currentYear) ending balance: \(balance)")
            } else {
                print("    ⏭️  \(currentMonth)/\(currentYear): No paid transactions, carrying forward: \(balance)")
                
                // Even if no transactions, cache the carried-forward balance
                _ = db.saveMonthBalance(month: currentMonth, year: currentYear, endingBalance: balance)
            }
            
            // Move to next month
            currentMonth += 1
            if currentMonth > 12 {
                currentMonth = 1
                currentYear += 1
            }
        }
        
        print("  💰 Final balance up to \(month)/\(year): \(balance)")
        return balance
    }
    
    func recalculateAndCacheMonthBalance(month: Int, year: Int) {
        print("🔄 Recalculating and caching balance for \(month)/\(year)")
        
        // Get starting balance for this month
        let startingBalance = balanceUpToMonth(month: month, year: year)
        
        // Calculate ending balance for this month
        let transactions = db.loadTransactionsForMonth(month: month, year: year)
        let paidTransactions = transactions.filter { $0.isPaid }
        
        var endingBalance = startingBalance
        
        print("  📊 Starting: \(startingBalance), Processing \(paidTransactions.count) paid transactions")
        
        for transaction in paidTransactions {
            if transaction.isIncome {
                endingBalance += transaction.amount
                print("    ✅ +\(transaction.amount) (\(transaction.title))")
            } else {
                endingBalance -= transaction.amount
                print("    ❌ -\(transaction.amount) (\(transaction.title))")
            }
        }
        
        // Save to cache
        _ = db.saveMonthBalance(month: month, year: year, endingBalance: endingBalance)
        print("  ✅ Cached ending balance for \(month)/\(year): \(endingBalance)")
    }
    
    func currentBalance() -> Double {
        print("💰 Calculating current balance")
        
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // Get balance up to current month (uses cache)
        var balance = balanceUpToMonth(month: currentMonth, year: currentYear)
        
        // Add current month's paid transactions
        let paidTransactions = currentMonthTransactions
            .filter { $0.isPaid }
            .sorted { ($0.actualPaymentDate ?? $0.dueDate) < ($1.actualPaymentDate ?? $1.dueDate) }
        
        print("  📊 Current month (\(currentMonth)/\(currentYear)): \(paidTransactions.count) paid transactions")
        
        for transaction in paidTransactions {
            if transaction.isIncome {
                balance += transaction.amount
                print("    ✅ +\(transaction.amount) (\(transaction.title))")
            } else {
                balance -= transaction.amount
                print("    ❌ -\(transaction.amount) (\(transaction.title))")
            }
        }
        
        print("  💰 Final current balance: \(balance)")
        return balance
    }
    
    // MARK: - Monthly Calculations (for Dashboard)
    
    func totalIncome(for date: Date) -> Double {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        let transactions = db.loadTransactionsForMonth(month: month, year: year)
        return transactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    func totalExpenses(for date: Date) -> Double {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        let transactions = db.loadTransactionsForMonth(month: month, year: year)
        return transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    func netIncome(for date: Date) -> Double {
        return totalIncome(for: date) - totalExpenses(for: date)
    }
    
    // MARK: - Upcoming Transactions (next 7 days from current viewing month)
    
    func getUpcomingTransactions(days: Int) -> [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let futureDate = calendar.date(byAdding: .day, value: days, to: today)!
        
        return currentMonthTransactions
            .filter { transaction in
                transaction.dueDate >= today && transaction.dueDate <= futureDate && !transaction.isPaid
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
}
