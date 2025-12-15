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
    @State private var isReorderMode = false
    @State private var earliestAllowedDate: Date?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View mode picker & navigation
                headerSection
                
                // Excel-style header row (only if we have transactions)
                if !currentMonthTransactions.isEmpty {
                    excelHeader
                }
                
                // Scrollable transaction list
                List {
                    ForEach(Array(currentMonthTransactions.enumerated()), id: \.element.id) { index, transaction in
                        ExcelTransactionRow(
                            transaction: transaction,
                            projectedBalance: calculateProjectedBalance(atIndex: index),
                            isLast: index == currentMonthTransactions.count - 1,
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
                            leadingSwipeButton(for: transaction)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            trailingSwipeButton(for: transaction)
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
                TransactionDetailView(transaction: transaction)
                    .environmentObject(dataManager)
            }
            .onAppear {
                print("📅 Timeline: View appeared")
                setEarliestAllowedDate()
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                let calendar = Calendar.current
                let oldMonth = calendar.component(.month, from: oldValue)
                let oldYear = calendar.component(.year, from: oldValue)
                let newMonth = calendar.component(.month, from: newValue)
                let newYear = calendar.component(.year, from: newValue)
                
                if oldMonth != newMonth || oldYear != newYear {
                    print("📅 Timeline: Date changed from \(monthName(oldMonth)) \(oldYear) to \(monthName(newMonth)) \(newYear)")
                    print("📅 Timeline: Loading month \(newMonth)/\(newYear)")
                    dataManager.loadOrGenerateMonth(month: newMonth, year: newYear)
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
                        .foregroundColor(canNavigateBackward() ? .blue : .gray)
                }
                .disabled(!canNavigateBackward())
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(dateRangeString())
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(currentMonthTransactions.count) transactions")
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
    
    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        let transactions = dataManager.db.loadTransactionsForMonth(month: month, year: year)
        
        // Sort: paid first (by payment date), then unpaid (by display order)
        let paid = transactions.filter { $0.isPaid }.sorted {
            ($0.actualPaymentDate ?? $0.dueDate) < ($1.actualPaymentDate ?? $1.dueDate)
        }
        let unpaid = transactions.filter { !$0.isPaid }.sorted { $0.displayOrder < $1.displayOrder }
        
        return paid + unpaid
    }
    
    // MARK: - Swipe Action Buttons
        
    @ViewBuilder
    private func leadingSwipeButton(for transaction: Transaction) -> some View {
        if !isReorderMode {
            Button {
                togglePaid(transaction)
            } label: {
                if transaction.isPaid {
                    Label("Unpaid", systemImage: "xmark.circle.fill")
                } else {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                }
            }
            .tint(transaction.isPaid ? .orange : .green)
        }
    }

    @ViewBuilder
    private func trailingSwipeButton(for transaction: Transaction) -> some View {
        if !isReorderMode {
            Button(role: .destructive) {
                deleteTransaction(transaction)
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setEarliestAllowedDate() {
        if let earliest = dataManager.db.getEarliestTransactionDate() {
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = earliest.year
            components.month = earliest.month
            components.day = 1
            earliestAllowedDate = calendar.date(from: components)
            print("✅ Earliest transaction: \(earliest.month)/\(earliest.year)")
            print("📅 Timeline: Earliest allowed date set to \(earliest.month)/\(earliest.year)")
        }
    }
    
    private func canNavigateBackward() -> Bool {
        guard let earliest = earliestAllowedDate else { return true }
        
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: selectedDate)
        let currentYear = calendar.component(.year, from: selectedDate)
        let earliestMonth = calendar.component(.month, from: earliest)
        let earliestYear = calendar.component(.year, from: earliest)
        
        let currentValue = currentYear * 12 + currentMonth
        let earliestValue = earliestYear * 12 + earliestMonth
        
        return currentValue > earliestValue
    }
    
    private func calculatePreviousMonthProjectedBalance(for month: Int, year: Int) -> Double {
        print("🔍 ============ CALCULATING STARTING BALANCE FOR \(month)/\(year) ============")
        
        // Get previous month
        var prevMonth = month - 1
        var prevYear = year
        if prevMonth == 0 {
            prevMonth = 12
            prevYear -= 1
        }
        
        print("📅 Previous month: \(prevMonth)/\(prevYear)")
        
        // Check if this IS the first month with transactions
        if let earliest = dataManager.db.getEarliestTransactionDate() {
            print("✅ Earliest transaction: \(earliest.month)/\(earliest.year)")
            
            let currentMonthValue = year * 12 + month
            let earliestMonthValue = earliest.year * 12 + earliest.month
            
            print("📊 Current month value: \(currentMonthValue)")
            print("📊 Earliest month value: \(earliestMonthValue)")
            
            if currentMonthValue == earliestMonthValue {
                print("✅ This IS the first month with transactions (\(month)/\(year))")
                print("💰 STARTING BALANCE = $0.00")
                print("🔍 ============ END ============\n")
                return 0.0
            }
            
            if currentMonthValue < earliestMonthValue {
                print("⚠️ This is BEFORE the first month with transactions")
                print("💰 STARTING BALANCE = $0.00")
                print("🔍 ============ END ============\n")
                return 0.0
            }
        }
        
        // CRITICAL FIX: Get the PROJECTED ending balance of previous month
        // This means: paid balance UP TO previous month + ALL transactions IN previous month
        
        print("📥 Loading transactions for \(prevMonth)/\(prevYear)...")
        let prevMonthTransactions = dataManager.db.loadTransactionsForMonth(month: prevMonth, year: prevYear)
        print("📊 Found \(prevMonthTransactions.count) transactions in \(prevMonth)/\(prevYear)")
        
        // Get balance UP TO (but not including) previous month
        print("💰 Getting balance UP TO (but not including) \(prevMonth)/\(prevYear)...")
        var balance = dataManager.balanceUpToMonth(month: prevMonth, year: prevYear)
        print("💰 Balance before \(prevMonth)/\(prevYear) transactions: \(formatCurrency(balance))")
        
        // Now add ALL transactions from previous month (paid + unpaid) to get projected ending
        if !prevMonthTransactions.isEmpty {
            // Sort: paid first (by actual payment date), then unpaid (by display order)
            let sorted = prevMonthTransactions.sorted { t1, t2 in
                if t1.isPaid != t2.isPaid {
                    return t1.isPaid  // Paid first
                }
                if t1.isPaid {
                    // Both paid - sort by payment date
                    return (t1.actualPaymentDate ?? t1.dueDate) < (t2.actualPaymentDate ?? t2.dueDate)
                } else {
                    // Both unpaid - sort by display order
                    return t1.displayOrder < t2.displayOrder
                }
            }
            
            print("📋 Processing \(sorted.count) transactions from \(prevMonth)/\(prevYear):")
            for (index, transaction) in sorted.enumerated() {
                let before = balance
                if transaction.isIncome {
                    balance += transaction.amount
                } else {
                    balance -= transaction.amount
                }
                let paidIcon = transaction.isPaid ? "✅" : "❌"
                let typeIcon = transaction.isIncome ? "INCOME" : "EXPENSE"
                let sign = transaction.isIncome ? "+" : "-"
                print("  [\(index)] \(paidIcon) \(typeIcon): \(sign)\(formatCurrency(transaction.amount)) (\(transaction.title)) | \(formatCurrency(before)) → \(formatCurrency(balance))")
            }
        }
        
        // 🔥 CACHE THE PROJECTED ENDING BALANCE FOR PREVIOUS MONTH
        print("💾 Caching projected balance for \(prevMonth)/\(prevYear): \(formatCurrency(balance))")
        dataManager.db.cacheMonthBalance(month: prevMonth, year: prevYear, balance: balance)
        
        print("💰 FINAL STARTING BALANCE FOR \(month)/\(year) = \(formatCurrency(balance))")
        print("🔍 ============ END ============\n")
        
        return balance
    }
    
    private func calculateProjectedBalance(atIndex index: Int) -> Double {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        print("🧮 Calculating projected balance at index \(index) for \(month)/\(year)")
        
        // Get starting balance from previous month's PROJECTED ending
        let startingBalance = calculatePreviousMonthProjectedBalance(for: month, year: year)
        print("   Starting with: \(formatCurrency(startingBalance))")
        
        var balance = startingBalance
        
        // Get current month's transactions
        let transactions = dataManager.db.loadTransactionsForMonth(month: month, year: year)
        
        // Sort them the same way as the view does
        let paid = transactions.filter { $0.isPaid }.sorted {
            ($0.actualPaymentDate ?? $0.dueDate) < ($1.actualPaymentDate ?? $1.dueDate)
        }
        let unpaid = transactions.filter { !$0.isPaid }.sorted { $0.displayOrder < $1.displayOrder }
        let sorted = paid + unpaid
        
        guard index >= 0 && index < sorted.count else {
            return balance
        }
        
        print("   Processing transactions 0 to \(index):")
        
        // Process transactions from 0 to index (inclusive)
        for i in 0...index {
            let t = sorted[i]
            let before = balance
            
            if t.isIncome {
                balance += t.amount
            } else {
                balance -= t.amount
            }
            
            let sign = t.isIncome ? "+" : "-"
            print("     [\(i)] \(sign)\(formatCurrency(t.amount)) (\(t.title)) | \(formatCurrency(before)) → \(formatCurrency(balance))")
        }
        
        print("   💰 Final projected balance at index \(index): \(formatCurrency(balance))\n")
        
        return balance
    }
    
    private func reorderUnpaidTransactions(from source: IndexSet, to destination: Int) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        let transactions = currentMonthTransactions
        let paid = transactions.filter { $0.isPaid }
        let unpaid = transactions.filter { !$0.isPaid }
        
        // Adjust indices to account for paid transactions
        let paidCount = paid.count
        
        // Only process if we're in the unpaid section
        guard source.allSatisfy({ $0 >= paidCount }) && destination >= paidCount else {
            return
        }
        
        let adjustedSource = source.map { $0 - paidCount }
        let adjustedDestination = destination - paidCount
        
        var reorderedUnpaid = unpaid
        reorderedUnpaid.move(fromOffsets: IndexSet(adjustedSource), toOffset: adjustedDestination)
        
        // Update display_order in database
        for (index, transaction) in reorderedUnpaid.enumerated() {
            dataManager.db.updateTransactionDisplayOrder(id: transaction.id, displayOrder: index)
        }
        
        // Reload the month
        dataManager.loadOrGenerateMonth(month: month, year: year)
    }
    
    private func togglePaid(_ transaction: Transaction) {
        print("🔄 Toggle paid called for: \(transaction.title)")
        
        let newStatus = !transaction.isPaid
        var updated = transaction
        updated.isPaid = newStatus
        
        if newStatus {
            // Mark as paid - set actual payment date to today
            updated.actualPaymentDate = Date()
        } else {
            // Mark as unpaid - clear payment date
            updated.actualPaymentDate = nil
        }
        
        if dataManager.db.updateTransaction(updated) {
            print("✅ Toggled paid status")
            
            // Reload current month
            let calendar = Calendar.current
            let month = calendar.component(.month, from: selectedDate)
            let year = calendar.component(.year, from: selectedDate)
            dataManager.loadOrGenerateMonth(month: month, year: year)
        } else {
            print("❌ Failed to toggle paid status")
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        if dataManager.db.deleteTransaction(id: transaction.id) {
            // Reload current month
            let calendar = Calendar.current
            let month = calendar.component(.month, from: selectedDate)
            let year = calendar.component(.year, from: selectedDate)
            dataManager.loadOrGenerateMonth(month: month, year: year)
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
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        let calendar = Calendar.current
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(month)"
    }
}

// MARK: - Excel Transaction Row

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
                            // Show template indicator if this is from a template
                            if transaction.templateId != nil {
                                HStack(spacing: 3) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 8))
                                    Text("Monthly")
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
