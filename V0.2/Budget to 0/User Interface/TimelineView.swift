//
//  TimelineView.swift
//  Budget to 0
//
//  Excel-style timeline with drag-to-reorder and projected balance
//

import SwiftUI

enum TimelineViewMode: String, CaseIterable {
    case weekly = "Week"
    case monthly = "Month"
    case yearly = "Year"
}

struct TimelineView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var selectedDate = Date()
    @State private var selectedTransaction: Transaction?
    @State private var viewMode: TimelineViewMode = .monthly
    @State private var unpaidTransactionsOrder: [UUID] = [] // Track manual order
    @State private var isReorderMode = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View mode picker & navigation
                headerSection
                
                // Excel-style header row (only if we have transactions)
                if !sortedFilteredTransactions.isEmpty {
                    excelHeader
                }
                
                // Scrollable transaction list
                List {
                    ForEach(Array(sortedFilteredTransactions.enumerated()), id: \.element.id) { index, transaction in
                        ExcelTransactionRow(
                            transaction: transaction,
                            projectedBalance: calculateProjectedBalance(atIndex: index),
                            isLast: index == sortedFilteredTransactions.count - 1,
                            showDragHandle: !transaction.isPaid && isReorderMode
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isReorderMode {
                                selectedTransaction = transaction
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !isReorderMode {
                                Button {
                                    if transaction.isPaid {
                                        togglePaid(transaction, newDate: nil)
                                    } else {
                                        // Default to today
                                        togglePaid(transaction, newDate: Date())
                                    }
                                } label: {
                                    if transaction.isPaid {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Unpaid")
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Paid")
                                    }
                                }
                                .tint(transaction.isPaid ? .orange : .green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !isReorderMode {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Image(systemName: "trash.fill")
                                    Text("Delete")
                                }
                            }
                        }
                    }
                    .onMove { from, to in
                        if isReorderMode {
                            reorderUnpaidTransactions(from: from, to: to)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            isReorderMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isReorderMode ? "Done" : "Reorder")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: isReorderMode ? "checkmark" : "pencil")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                let isGenerated = !dataManager.transactions.contains(where: { $0.id == transaction.id })
                TransactionDetailView(transaction: transaction, isRecurringInstance: isGenerated)
                    .environmentObject(dataManager)
            }
            .onAppear {
                // Initialize unpaid order on first load
                if unpaidTransactionsOrder.isEmpty {
                    unpaidTransactionsOrder = filteredTransactions
                        .filter { !$0.isPaid }
                        .sorted { $0.dueDate < $1.dueDate }
                        .map { $0.id }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // View mode picker
            Picker("View Mode", selection: $viewMode) {
                ForEach(TimelineViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Navigation
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        adjustDate(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(dateRangeString())
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(sortedFilteredTransactions.count) transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        adjustDate(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Excel Header (Projected Balance Only)
    
    private var excelHeader: some View {
        HStack(spacing: 4) {
            // Drag handle space
            Color.clear
                .frame(width: 20)
            
            Text("Date")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text("Description")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Amount")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            VStack(spacing: 2) {
                Text("Projected")
                    .font(.system(size: 9))
                    .fontWeight(.bold)
                Text("Balance")
                    .font(.system(size: 9))
                    .fontWeight(.bold)
            }
            .foregroundColor(.secondary)
            .frame(width: 85, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Computed Properties
    
    private var sortedFilteredTransactions: [Transaction] {
        let filtered = filteredTransactions
        
        // Separate paid and unpaid
        let paid = filtered.filter { $0.isPaid }.sorted { $0.dueDate < $1.dueDate }
        let unpaid = filtered.filter { !$0.isPaid }
        
        // Apply manual ordering to unpaid
        let sortedUnpaid: [Transaction]
        if unpaidTransactionsOrder.isEmpty {
            sortedUnpaid = unpaid.sorted { $0.dueDate < $1.dueDate }
        } else {
            sortedUnpaid = unpaid.sorted { t1, t2 in
                guard let index1 = unpaidTransactionsOrder.firstIndex(of: t1.id),
                      let index2 = unpaidTransactionsOrder.firstIndex(of: t2.id) else {
                    return t1.dueDate < t2.dueDate
                }
                return index1 < index2
            }
        }
        
        // Paid first, then unpaid
        return paid + sortedUnpaid
    }
    
    private var filteredTransactions: [Transaction] {
        let (startDate, endDate) = getDateRange()
        
        var allTransactions: [Transaction] = []
        var processedDates: Set<String> = []
        
        func dateKey(for date: Date, title: String) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(formatter.string(from: date))_\(title)"
        }
        
        // First: Add all one-time transactions (including overrides)
        for transaction in dataManager.transactions {
            if !transaction.isRecurring && transaction.dueDate >= startDate && transaction.dueDate <= endDate {
                allTransactions.append(transaction)
                processedDates.insert(dateKey(for: transaction.dueDate, title: transaction.title))
            }
        }
        
        // Second: Generate recurring instances (skip if override exists)
        for transaction in dataManager.transactions {
            if transaction.isRecurring {
                let instances = generateRecurringInstances(
                    for: transaction,
                    startDate: startDate,
                    endDate: endDate
                )
                
                for instance in instances {
                    let key = dateKey(for: instance.dueDate, title: instance.title)
                    if !processedDates.contains(key) {
                        allTransactions.append(instance)
                    }
                }
            }
        }
        
        return allTransactions
    }
    
    private func getDateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        
        switch viewMode {
        case .weekly:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            return (startOfWeek, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek)!)
            
        case .monthly:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (startOfMonth, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth)!)
            
        case .yearly:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: selectedDate))!
            let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
            return (startOfYear, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfYear)!)
        }
    }
    
    private func generateRecurringInstances(for transaction: Transaction, startDate: Date, endDate: Date) -> [Transaction] {
        var instances: [Transaction] = []
        var currentDate = transaction.dueDate
        let calendar = Calendar.current
        
        let maxInstances: Int
        switch viewMode {
        case .weekly:
            maxInstances = 20
        case .monthly:
            maxInstances = 35
        case .yearly:
            maxInstances = 366
        }
        
        var count = 0
        
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
    
    // MARK: - Helper Methods
    
    private func calculateProjectedBalance(atIndex index: Int) -> Double {
        var balance = dataManager.startingBalance
        
        guard index >= 0 && index < sortedFilteredTransactions.count else {
            return balance
        }
        
        // Process transactions from 0 to index (inclusive)
        for i in 0...index {
            let t = sortedFilteredTransactions[i]
            
            if t.isIncome {
                balance += t.amount
            } else {
                balance -= t.amount
            }
        }
        
        return balance
    }
    
    private func reorderUnpaidTransactions(from source: IndexSet, to destination: Int) {
        let paid = sortedFilteredTransactions.filter { $0.isPaid }
        let unpaid = sortedFilteredTransactions.filter { !$0.isPaid }
        
        // Adjust indices to account for paid transactions
        let paidCount = paid.count
        
        // Only process if we're in the unpaid section
        guard source.allSatisfy({ $0 >= paidCount }) && destination >= paidCount else {
            return
        }
        
        let adjustedSource = source.map { $0 - paidCount }
        let adjustedDestination = destination - paidCount
        
        var newOrder = unpaid.map { $0.id }
        newOrder.move(fromOffsets: IndexSet(adjustedSource), toOffset: adjustedDestination)
        unpaidTransactionsOrder = newOrder
    }
    
    private func togglePaid(_ transaction: Transaction, newDate: Date?) {
        print("🔄 Toggle paid called for: \(transaction.title)")
        
        let paymentDate = newDate ?? Date() // Default to today
        
        if let storedIndex = dataManager.transactions.firstIndex(where: { $0.id == transaction.id }) {
            print("✅ Found stored transaction, toggling")
            
            if transaction.isPaid {
                // Mark as unpaid
                dataManager.togglePaidStatus(dataManager.transactions[storedIndex])
            } else {
                // Mark as paid with date
                if let newDate = newDate, !Calendar.current.isDate(newDate, inSameDayAs: transaction.dueDate) {
                    var updated = dataManager.transactions[storedIndex]
                    updated.dueDate = newDate
                    updated.isPaid = true
                    updated.notes = transaction.notes + "\n[Paid on \(formatDate(newDate)), originally due \(formatDate(transaction.dueDate))]"
                    dataManager.updateTransaction(updated)
                } else {
                    dataManager.togglePaidStatus(dataManager.transactions[storedIndex])
                }
            }
        } else {
            print("⚠️ Generated instance - creating override")
            
            let calendar = Calendar.current
            let existingOverride = dataManager.transactions.first { stored in
                !stored.isRecurring &&
                stored.title == transaction.title &&
                calendar.isDate(stored.dueDate, inSameDayAs: paymentDate)
            }
            
            if let existing = existingOverride {
                print("✅ Found existing override, toggling")
                dataManager.togglePaidStatus(existing)
            } else {
                print("✅ Creating new override")
                let overrideTransaction = Transaction(
                    title: transaction.title,
                    amount: transaction.amount,
                    isIncome: transaction.isIncome,
                    isPaid: true,
                    dueDate: paymentDate,
                    isRecurring: false,
                    recurrenceFrequency: .oneTime,
                    customRecurrenceDays: [],
                    category: transaction.category,
                    notes: transaction.notes + (newDate != nil && !Calendar.current.isDate(newDate!, inSameDayAs: transaction.dueDate) ? "\n[Paid on \(formatDate(paymentDate)), originally due \(formatDate(transaction.dueDate))]" : "")
                )
                dataManager.addTransaction(overrideTransaction)
            }
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        if dataManager.transactions.contains(where: { $0.id == transaction.id }) {
            dataManager.deleteTransaction(transaction)
        }
    }
    
    private func adjustDate(by value: Int) {
        let calendar = Calendar.current
        switch viewMode {
        case .weekly:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDate) ?? selectedDate
        case .monthly:
            selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
        case .yearly:
            selectedDate = calendar.date(byAdding: .year, value: value, to: selectedDate) ?? selectedDate
        }
    }
    
    private func dateRangeString() -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        switch viewMode {
        case .weekly:
            formatter.dateFormat = "MMM d"
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? selectedDate
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: selectedDate)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Excel Transaction Row (No changes needed)

struct ExcelTransactionRow: View {
    let transaction: Transaction
    let projectedBalance: Double
    let isLast: Bool
    let showDragHandle: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                // Drag handle (only for unpaid in reorder mode)
                if showDragHandle {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                } else {
                    Color.clear.frame(width: 20)
                }
                
                // Paid status indicator (left edge)
                Rectangle()
                    .fill(transaction.isPaid ? Color.green.opacity(0.3) : Color.clear)
                    .frame(width: 3)
                
                // Date
                Text(dayString(transaction.dueDate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(transaction.isPaid ? .secondary.opacity(0.6) : .primary)
                    .frame(width: 50, alignment: .leading)
                
                // Description with icon
                HStack(spacing: 6) {
                    Image(systemName: transaction.category.icon)
                        .font(.caption)
                        .foregroundColor(colorForCategory(transaction.category.color))
                        .opacity(transaction.isPaid ? 0.5 : 1.0)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            if transaction.isRecurring {
                                HStack(spacing: 3) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 8))
                                    Text(transaction.recurrenceFrequency.rawValue)
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.blue)
                            }
                            
                            if transaction.isPaid {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8))
                                    Text("Paid!")
                                        .font(.system(size: 9))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.green)
                            }
                        }
                    }
                }
                .foregroundColor(transaction.isPaid ? .secondary.opacity(0.6) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Amount
                Text(formatCurrency(transaction.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.isIncome ? .green : .red)
                    .opacity(transaction.isPaid ? 0.6 : 1.0)
                    .frame(width: 80, alignment: .trailing)
                
                // Projected Balance only
                Text(formatCurrency(projectedBalance))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(balanceColor(projectedBalance))
                    .frame(width: 85, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                transaction.isPaid ?
                    Color(.systemBackground).opacity(0.5) :
                    Color(.systemBackground)
            )
            
            if !isLast {
                Divider()
                    .padding(.leading, 70)
            }
        }
    }
    
    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func balanceColor(_ balance: Double) -> Color {
        if balance > 1000 {
            return .green
        } else if balance > 0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func colorForCategory(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "yellow": return .yellow
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        case "indigo": return .indigo
        case "mint": return .mint
        default: return .gray
        }
    }
}
