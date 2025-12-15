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
        
        templates = db.loadTemplates()
        print("✅ Loaded \(templates.count) templates")
        
        loadOrGenerateMonth(month: currentViewingMonth, year: currentViewingYear)
    }
    
    // MARK: - Monthly Transaction Generation

    func loadOrGenerateMonth(month: Int, year: Int) {
        print("📅 loadOrGenerateMonth called for \(month)/\(year)")
        
        let existing = db.loadTransactionsForMonth(month: month, year: year)
        print("🔍 Existing transactions found: \(existing.count)")
        
        // Map existing transactions to their templates
        let existingTemplateIds = Set(existing.map { $0.templateId })
        
        // Identify which templates are missing for this month
        let missingTemplates = templates.filter { !existingTemplateIds.contains($0.id) }
        print("🔍 Missing templates for this month: \(missingTemplates.map { $0.title })")
        
        // Generate transactions only for missing templates
        for template in missingTemplates {
            generateTransactions(for: template, month: month, year: year)
        }
        
        // Reload month transactions after generation
        currentMonthTransactions = db.loadTransactionsForMonth(month: month, year: year)
        print("📊 Current month transactions in memory: \(currentMonthTransactions.count)")
        
        currentViewingMonth = month
        currentViewingYear = year
        objectWillChange.send()
    }

    // Generate transactions for a single template
    private func generateTransactions(for template: BillTemplate, month: Int, year: Int) {
        let dueDates = calculateDueDates(for: template, month: month, year: year)
        print("🔨 Generating \(dueDates.count) transactions for template '\(template.title)' for \(month)/\(year)")
        
        for (index, dueDate) in dueDates.enumerated() {
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
                displayOrder: index,
                category: template.category,
                notes: template.notes
            )
            
            if db.saveTransaction(transaction) {
                print("✅ Generated transaction: \(transaction.title) | Due: \(transaction.dueDate)")
            } else {
                print("❌ Failed to save transaction for template: \(template.title)")
            }
        }
    }


    
    private func generateMonthFromTemplates(month: Int, year: Int) {
        print("🔨 generateMonthFromTemplates START for \(month)/\(year)")

        var newTransactions: [Transaction] = []
        let calendar = Calendar.current

        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let requestedYearMonth = year * 12 + month
        let currentYearMonth = currentYear * 12 + currentMonth

        print("🧮 requestedYearMonth = \(requestedYearMonth)")
        print("🧮 currentYearMonth   = \(currentYearMonth)")

        if requestedYearMonth < currentYearMonth {
            print("❌ GENERATION BLOCKED — requested month is before current month")
            return
        }

        print("✅ GENERATION ALLOWED")

        print("📦 Templates loaded: \(templates.count)")
        print("📦 Income templates: \(templates.filter { $0.isIncome }.count)")
        print("📦 Bill templates: \(templates.filter { !$0.isIncome }.count)")

        
        // Only block months before the first-ever transaction
        if let earliest = db.getEarliestTransactionDate() {
            let earliestYM = earliest.year * 12 + earliest.month
            if requestedYearMonth < earliestYM {
                print("⚠️ Not generating for \(month)/\(year) — before earliest transaction")
                return
            }
        }

        
        for template in templates {
            let dueDates = calculateDueDates(for: template, month: month, year: year)
            
            for (index, dueDate) in dueDates.enumerated() {
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
                    displayOrder: index,
                    category: template.category,
                    notes: template.notes
                )
                
                if db.saveTransaction(transaction) {
                    newTransactions.append(transaction)
                }
            }
        }
        
        print("✅ Generated \(newTransactions.count) transactions for \(month)/\(year)")
        currentMonthTransactions = newTransactions
    }
    
    private func calculateDueDates(for template: BillTemplate, month: Int, year: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        
        switch template.recurrenceFrequency {
        case .monthly:
            if let dueDay = template.dueDay {
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = min(dueDay, daysInMonth(month: month, year: year))
                if let date = calendar.date(from: components) {
                    dates.append(date)
                }
            }
            
        case .bimonthly:
            // Every other month
            if let dueDay = template.dueDay {
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = min(dueDay, daysInMonth(month: month, year: year))
                if let date = calendar.date(from: components) {
                    dates.append(date)
                }
            }
            
        case .semiMonthly:
            if let day1 = template.semiMonthlyDay1, let day2 = template.semiMonthlyDay2 {
                var components1 = DateComponents()
                components1.year = year
                components1.month = month
                components1.day = min(day1, daysInMonth(month: month, year: year))
                if let date1 = calendar.date(from: components1) {
                    dates.append(date1)
                }
                
                var components2 = DateComponents()
                components2.year = year
                components2.month = month
                components2.day = min(day2, daysInMonth(month: month, year: year))
                if let date2 = calendar.date(from: components2) {
                    dates.append(date2)
                }
            }
            
        case .weekly:
            if let startDate = template.startDate {
                let weekday = calendar.component(.weekday, from: startDate)
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = 1
                
                if var date = calendar.date(from: components) {
                    let firstWeekday = calendar.component(.weekday, from: date)
                    let daysToAdd = (weekday - firstWeekday + 7) % 7
                    
                    date = calendar.date(byAdding: .day, value: daysToAdd, to: date)!
                    
                    while calendar.component(.month, from: date) == month {
                        dates.append(date)
                        date = calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
                    }
                }
            }
            
        case .biweekly:
            if let startDate = template.startDate {
                var current = startDate
                
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = 1
                let monthStart = calendar.date(from: components)!
                
                components.month = month + 1
                components.day = 1
                let nextMonthStart = calendar.date(from: components)!
                
                while current < monthStart {
                    current = calendar.date(byAdding: .weekOfYear, value: 2, to: current)!
                }
                
                while current < nextMonthStart {
                    if calendar.component(.month, from: current) == month {
                        dates.append(current)
                    }
                    current = calendar.date(byAdding: .weekOfYear, value: 2, to: current)!
                }
            }
            
        case .yearly:
            if let dueDay = template.dueDay {
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = min(dueDay, daysInMonth(month: month, year: year))
                if let date = calendar.date(from: components) {
                    dates.append(date)
                }
            }
            
        default:
            break
        }
        
        return dates.sorted()
    }
    
    private func daysInMonth(month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        
        if let date = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: date) {
            return range.count
        }
        
        return 31
    }
    
    // MARK: - Template Management
    
    func addTemplate(_ template: BillTemplate) {
        print("➕ Adding template: \(template.title)")
        
        if db.saveTemplate(template) {
            templates.append(template)
            print("✅ Template added")
            
            let dueDates = calculateDueDates(for: template, month: currentViewingMonth, year: currentViewingYear)
            
            for (index, dueDate) in dueDates.enumerated() {
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
                    displayOrder: currentMonthTransactions.count + index,
                    category: template.category,
                    notes: template.notes
                )
                
                if db.saveTransaction(transaction) {
                    currentMonthTransactions.append(transaction)
                    print("✅ Generated transaction for current month")
                }
            }
            
            _ = db.invalidateMonthBalanceFrom(month: currentViewingMonth, year: currentViewingYear)
            recalculateAndCacheMonthBalance(month: currentViewingMonth, year: currentViewingYear)
            
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
                
                // Update all current month transactions from this template
                let transactionsToUpdate = currentMonthTransactions.filter { $0.templateId == template.id }
                for var transaction in transactionsToUpdate {
                    transaction.title = template.title
                    transaction.amount = template.amount
                    transaction.category = template.category
                    transaction.notes = template.notes
                    
                    if db.updateTransaction(transaction) {
                        if let idx = currentMonthTransactions.firstIndex(where: { $0.id == transaction.id }) {
                            currentMonthTransactions[idx] = transaction
                        }
                    }
                }
                
                _ = db.invalidateMonthBalanceFrom(month: currentViewingMonth, year: currentViewingYear)
                recalculateAndCacheMonthBalance(month: currentViewingMonth, year: currentViewingYear)
                
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
                
                let transactionsToDelete = currentMonthTransactions.filter { $0.templateId == template.id }
                for transaction in transactionsToDelete {
                    if db.deleteTransaction(id: transaction.id) {
                        if let idx = currentMonthTransactions.firstIndex(where: { $0.id == transaction.id }) {
                            currentMonthTransactions.remove(at: idx)
                        }
                    }
                }
                
                _ = db.invalidateMonthBalanceFrom(month: currentViewingMonth, year: currentViewingYear)
                recalculateAndCacheMonthBalance(month: currentViewingMonth, year: currentViewingYear)
                
                objectWillChange.send()
            }
        } else {
            print("❌ Failed to delete template")
        }
    }
    
    // MARK: - Transaction Management
    
    func updateTransaction(_ transaction: Transaction) {
        print("💾 Updating transaction: \(transaction.title)")
        
        if db.updateTransaction(transaction) {
            if let index = currentMonthTransactions.firstIndex(where: { $0.id == transaction.id }) {
                currentMonthTransactions[index] = transaction
                print("✅ Transaction updated in memory")
                
                _ = db.invalidateMonthBalanceFrom(month: transaction.month, year: transaction.year)
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
                
                _ = db.invalidateMonthBalanceFrom(month: transaction.month, year: transaction.year)
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
            if transaction.month == currentViewingMonth && transaction.year == currentViewingYear {
                currentMonthTransactions.append(transaction)
            }
            
            _ = db.invalidateMonthBalanceFrom(month: transaction.month, year: transaction.year)
            recalculateAndCacheMonthBalance(month: transaction.month, year: transaction.year)
            
            print("✅ One-time transaction added")
            objectWillChange.send()
        } else {
            print("❌ Failed to add one-time transaction")
        }
    }
    
    // MARK: - Reordering
    
    func reorderTransactions(from source: IndexSet, to destination: Int) {
        print("🔄 Reordering transactions")
        
        let paid = currentMonthTransactions.filter { $0.isPaid }.sorted {
            ($0.actualPaymentDate ?? $0.dueDate) < ($1.actualPaymentDate ?? $1.dueDate)
        }
        let unpaid = currentMonthTransactions.filter { !$0.isPaid }.sorted { $0.displayOrder < $1.displayOrder }
        
        let paidCount = paid.count
        guard source.allSatisfy({ $0 >= paidCount }) && destination >= paidCount else {
            print("⚠️ Cannot reorder paid transactions")
            return
        }
        
        let adjustedSource = source.map { $0 - paidCount }
        let adjustedDestination = destination - paidCount
        
        var reorderedUnpaid = unpaid
        reorderedUnpaid.move(fromOffsets: IndexSet(adjustedSource), toOffset: adjustedDestination)
        
        for (index, var transaction) in reorderedUnpaid.enumerated() {
            transaction.displayOrder = index
            _ = db.updateTransaction(transaction)
        }
        
        currentMonthTransactions = db.loadTransactionsForMonth(month: currentViewingMonth, year: currentViewingYear)
        
        print("✅ Reorder saved to database")
        objectWillChange.send()
    }
    
    // MARK: - Balance Calculations
    
    func balanceUpToMonth(month: Int, year: Int) -> Double {
        print("💰 Calculating balance up to \(month)/\(year)")
        
        if month == 1 {
            if let cachedBalance = db.loadMonthBalance(month: 12, year: year - 1) {
                print("  ✅ Using cached December \(year - 1) balance: \(cachedBalance)")
                return cachedBalance
            }
        } else {
            let prevMonth = month - 1
            if let cachedBalance = db.loadMonthBalance(month: prevMonth, year: year) {
                print("  ✅ Using cached \(prevMonth)/\(year) balance: \(cachedBalance)")
                return cachedBalance
            }
        }
        
        print("  ⚠️ No cache found, calculating from scratch...")
        
        guard let earliestDate = db.getEarliestTransactionDate() else {
            print("  ⚠️ No transactions in database, starting at 0")
            return 0.0
        }
        
        let startYear = earliestDate.year
        let startMonth = earliestDate.month
        
        print("  📅 First transaction found: \(startMonth)/\(startYear)")
        
        let targetYearMonth = year * 12 + month
        let startYearMonth = startYear * 12 + startMonth
        
        if targetYearMonth < startYearMonth {
            print("  ⚠️ Target month (\(month)/\(year)) is BEFORE first transaction (\(startMonth)/\(startYear)), returning 0")
            return 0.0
        }
        
        print("  📅 Calculating from \(startMonth)/\(startYear) to \(month)/\(year)")
        
        var balance = 0.0
        var currentYear = startYear
        var currentMonth = startMonth
        
        while (currentYear * 12 + currentMonth) < targetYearMonth {
            if let cachedBalance = db.loadMonthBalance(month: currentMonth, year: currentYear) {
                print("    ✅ Cache hit for \(currentMonth)/\(currentYear): \(cachedBalance)")
                balance = cachedBalance
                
                currentMonth += 1
                if currentMonth > 12 {
                    currentMonth = 1
                    currentYear += 1
                }
                continue
            }
            
            let transactions = db.loadTransactionsForMonth(month: currentMonth, year: currentYear)
            let paidTransactions = transactions.filter { $0.isPaid }
            
            if !paidTransactions.isEmpty {
                print("    📊 \(currentMonth)/\(currentYear): Processing \(paidTransactions.count) paid transactions (starting: \(balance))")
                
                for transaction in paidTransactions {
                    if transaction.isIncome {
                        balance += transaction.amount
                    } else {
                        balance -= transaction.amount
                    }
                }
                
                _ = db.saveMonthBalance(month: currentMonth, year: currentYear, endingBalance: balance)
                print("    💾 Cached \(currentMonth)/\(currentYear) ending balance: \(balance)")
            } else {
                print("    ⏭️  \(currentMonth)/\(currentYear): No paid transactions, carrying forward: \(balance)")
                _ = db.saveMonthBalance(month: currentMonth, year: currentYear, endingBalance: balance)
            }
            
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
        
        let startingBalance = balanceUpToMonth(month: month, year: year)
        let transactions = db.loadTransactionsForMonth(month: month, year: year)
        let paidTransactions = transactions.filter { $0.isPaid }
        
        var endingBalance = startingBalance
        
        print("  📊 Starting: \(startingBalance), Processing \(paidTransactions.count) paid transactions")
        
        for transaction in paidTransactions {
            if transaction.isIncome {
                endingBalance += transaction.amount
            } else {
                endingBalance -= transaction.amount
            }
        }
        
        _ = db.saveMonthBalance(month: month, year: year, endingBalance: endingBalance)
        print("  ✅ Cached ending balance for \(month)/\(year): \(endingBalance)")
    }
    
    func currentBalance() -> Double {
        print("💰 Calculating current balance")
        
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        var balance = balanceUpToMonth(month: currentMonth, year: currentYear)
        
        let paidTransactions = currentMonthTransactions
            .filter { $0.isPaid }
            .sorted { ($0.actualPaymentDate ?? $0.dueDate) < ($1.actualPaymentDate ?? $1.dueDate) }
        
        print("  📊 Current month (\(currentMonth)/\(currentYear)): \(paidTransactions.count) paid transactions")
        
        for transaction in paidTransactions {
            if transaction.isIncome {
                balance += transaction.amount
            } else {
                balance -= transaction.amount
            }
        }
        
        print("  💰 Final current balance: \(balance)")
        return balance
    }
    
    // MARK: - Monthly Calculations
    
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
    
    // MARK: - Upcoming Transactions
    
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
