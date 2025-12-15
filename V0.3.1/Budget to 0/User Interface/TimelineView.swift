//
//  TimelineView.swift
//  Budget to 0
//
//  Excel-style timeline with drag-to-reorder and projected balance
//

import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var selectedDate = Date()
    @State private var selectedTransaction: Transaction?
    @State private var isReorderMode = false
    @State private var earliestAllowedDate: Date?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month navigation header
                monthNavigationHeader
                
                // Balance summary card
                balanceSummaryCard
                
                // Excel-style header row (only if we have transactions)
                if !currentMonthTransactions.isEmpty {
                    excelHeader
                }
                
                // Scrollable transaction list
                transactionList
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    reorderButton
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
    
    // MARK: - Month Navigation Header
    
    private var monthNavigationHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        adjustMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canNavigateBackward() ? .blue : .gray)
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(!canNavigateBackward())
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(monthYearString())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(currentMonthTransactions.count) transactions")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        adjustMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Balance Summary Card

    private var balanceSummaryCard: some View {
        let projectedEndingBalance = calculateProjectedEndingBalance()
        
        return VStack(spacing: 12) {
            Text("Projected Ending")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        
            HStack {
                
                Text(formatCurrency(projectedEndingBalance))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(balanceColor(projectedEndingBalance))
                    
                    Image(systemName: projectedEndingBalance > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.title)
                        .foregroundColor(balanceColor(projectedEndingBalance))
                        .symbolRenderingMode(.hierarchical)
                }
            
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Reorder Button
    
    private var reorderButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isReorderMode.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(isReorderMode ? "Done" : "Reorder")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isReorderMode ? .green : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((isReorderMode ? Color.green : Color.blue).opacity(0.12))
            )
        }
    }
    
    // MARK: - Excel Header

    private var excelHeader: some View {
        HStack(spacing: 0) {
            Text("Date")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .frame(width: 70, alignment: .center)
            
            Text("Description")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            
            Text("Amount")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .frame(width: 100, alignment: .center)

            Text("Balance")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(.secondarySystemGroupedBackground)
                .overlay(
                    Rectangle()
                        .fill(Color(.separator).opacity(0.5))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
    
    // MARK: - Transaction List
    
    private var transactionList: some View {
        Group {
            if currentMonthTransactions.isEmpty {
                emptyStateView
            } else {
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
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No Transactions")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Add bills or income to see them here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
        
        print("📥 Loading transactions for \(prevMonth)/\(prevYear)...")
        let prevMonthTransactions = dataManager.db.loadTransactionsForMonth(month: prevMonth, year: prevYear)
        print("📊 Found \(prevMonthTransactions.count) transactions in \(prevMonth)/\(prevYear)")
        
        print("💰 Getting balance UP TO (but not including) \(prevMonth)/\(prevYear)...")
        var balance = dataManager.balanceUpToMonth(month: prevMonth, year: prevYear)
        print("💰 Balance before \(prevMonth)/\(prevYear) transactions: \(formatCurrency(balance))")
        
        if !prevMonthTransactions.isEmpty {
            let sorted = prevMonthTransactions.sorted { t1, t2 in
                if t1.isPaid != t2.isPaid {
                    return t1.isPaid
                }
                if t1.isPaid {
                    return (t1.actualPaymentDate ?? t1.dueDate) < (t2.actualPaymentDate ?? t2.dueDate)
                } else {
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
        
        let startingBalance = calculatePreviousMonthProjectedBalance(for: month, year: year)
        var balance = startingBalance
        
        let transactions = dataManager.db.loadTransactionsForMonth(month: month, year: year)
        let paid = transactions.filter { $0.isPaid }.sorted {
            ($0.actualPaymentDate ?? $0.dueDate) < ($1.actualPaymentDate ?? $1.dueDate)
        }
        let unpaid = transactions.filter { !$0.isPaid }.sorted { $0.displayOrder < $1.displayOrder }
        let sorted = paid + unpaid
        
        guard index >= 0 && index < sorted.count else {
            return balance
        }
        
        for i in 0...index {
            let t = sorted[i]
            if t.isIncome {
                balance += t.amount
            } else {
                balance -= t.amount
            }
        }
        
        return balance
    }
    
    private func calculateProjectedEndingBalance() -> Double {
        if currentMonthTransactions.isEmpty {
            return 0.0
        }
        return calculateProjectedBalance(atIndex: currentMonthTransactions.count - 1)
    }
    
    private func reorderUnpaidTransactions(from source: IndexSet, to destination: Int) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        let transactions = currentMonthTransactions
        let paid = transactions.filter { $0.isPaid }
        let unpaid = transactions.filter { !$0.isPaid }
        
        let paidCount = paid.count
        
        guard source.allSatisfy({ $0 >= paidCount }) && destination >= paidCount else {
            return
        }
        
        let adjustedSource = source.map { $0 - paidCount }
        let adjustedDestination = destination - paidCount
        
        var reorderedUnpaid = unpaid
        reorderedUnpaid.move(fromOffsets: IndexSet(adjustedSource), toOffset: adjustedDestination)
        
        for (index, transaction) in reorderedUnpaid.enumerated() {
            dataManager.db.updateTransactionDisplayOrder(id: transaction.id, displayOrder: index)
        }
        
        dataManager.loadOrGenerateMonth(month: month, year: year)
    }
    
    private func togglePaid(_ transaction: Transaction) {
        print("🔄 Toggle paid called for: \(transaction.title)")
        
        let newStatus = !transaction.isPaid
        var updated = transaction
        updated.isPaid = newStatus
        
        if newStatus {
            updated.actualPaymentDate = Date()
        } else {
            updated.actualPaymentDate = nil
        }
        
        if dataManager.db.updateTransaction(updated) {
            print("✅ Toggled paid status")
            
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
            let calendar = Calendar.current
            let month = calendar.component(.month, from: selectedDate)
            let year = calendar.component(.year, from: selectedDate)
            dataManager.loadOrGenerateMonth(month: month, year: year)
        }
    }
    
    private func adjustMonth(by value: Int) {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
    }
    
    private func monthYearString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
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
            HStack(spacing: 0) {
                // Visual indicator for reorder mode (left edge)
                if showDragHandle {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 4)
                }
                
                // Date column (70px)
                VStack(spacing: 3) {
                    Text(dayString(transaction.dueDate))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.isPaid ? .secondary.opacity(0.7) : .primary)
                    
                    // Status indicator
                    if transaction.isPaid {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: 70, alignment: .center)
                
                // Description column (flexible)
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(colorForCategory(transaction.category.color).opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: transaction.category.icon)
                            .font(.callout)
                            .foregroundColor(colorForCategory(transaction.category.color))
                            .opacity(transaction.isPaid ? 0.6 : 1.0)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        
                        HStack(spacing: 6) {
                            if transaction.templateId != nil {
                                HStack(spacing: 2) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 9))
                                    Text("Monthly")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                            
                            if transaction.isPaid {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 9))
                                    Text("Paid")
                                        .font(.system(size: 10))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.1))
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundColor(transaction.isPaid ? .secondary.opacity(0.7) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                
                // Amount column (100px)
                Text(formatCurrency(transaction.amount))
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.isIncome ? .green : .red)
                    .opacity(transaction.isPaid ? 0.6 : 1.0)
                    .frame(width: 100, alignment: .center)
                
                // Balance column (100px)
                Text(formatCurrency(projectedBalance))
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(balanceColor(projectedBalance))
                    .frame(width: 100, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                showDragHandle ?
                    Color.blue.opacity(0.05) :
                    Color(.systemBackground)
            )
            
            if !isLast {
                Divider()
                    .padding(.leading, 90)
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
