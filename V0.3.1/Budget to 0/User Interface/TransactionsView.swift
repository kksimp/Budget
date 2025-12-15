//
//  TransactionsView.swift
//  Budget to 0
//
//  All transactions list - shows current month's transactions
//

import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all
    @State private var showingAddSheet = false
    @State private var selectedTransaction: Transaction?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Pills
                filterPills
                
                // Transactions List
                transactionsList
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTransactionView()
                    .environmentObject(dataManager)
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
                    .environmentObject(dataManager)
            }
        }
    }
    
    // MARK: - Filter Pills
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .overlay(
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .background(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Transactions List
    
    private var transactionsList: some View {
        List {
            if filteredTransactions().isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No transactions found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Try adjusting your filters or search")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredTransactions()) { transaction in
                    TransactionListRow(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTransaction = transaction
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                dataManager.deleteTransaction(transaction)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                dataManager.togglePaidStatus(transaction)
                            } label: {
                                Label(transaction.isPaid ? "Unpaid" : "Paid", systemImage: transaction.isPaid ? "xmark.circle" : "checkmark.circle")
                            }
                            .tint(transaction.isPaid ? .orange : .green)
                        }
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Filtering
    
    private func filteredTransactions() -> [Transaction] {
        var transactions = dataManager.currentMonthTransactions
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .bills:
            transactions = transactions.filter { !$0.isIncome }
        case .income:
            transactions = transactions.filter { $0.isIncome }
        case .recurring:
            transactions = transactions.filter { $0.templateId != nil }
        case .oneTime:
            transactions = transactions.filter { $0.templateId == nil }
        case .paid:
            transactions = transactions.filter { $0.isPaid }
        case .unpaid:
            transactions = transactions.filter { !$0.isPaid }
        }
        
        // Apply search
        if !searchText.isEmpty {
            transactions = transactions.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return transactions.sorted { $0.dueDate > $1.dueDate }
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct TransactionListRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: transaction.category.icon)
                .font(.title3)
                .foregroundColor(colorForCategory(transaction.category.color))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(colorForCategory(transaction.category.color).opacity(0.15))
                )
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 6) {
                    Text(formatDate(transaction.dueDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if transaction.templateId != nil {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if transaction.isPaid {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // Amount
            Text(formatCurrency(transaction.amount))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isIncome ? .green : .red)
        }
        .padding(.vertical, 4)
        .opacity(transaction.isPaid ? 0.6 : 1.0)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
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

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case bills = "Bills"
    case income = "Income"
    case recurring = "Recurring"
    case oneTime = "One Time"
    case paid = "Paid"
    case unpaid = "Unpaid"
}

#Preview {
    TransactionsView()
        .environmentObject(EnhancedDataManager())
}
