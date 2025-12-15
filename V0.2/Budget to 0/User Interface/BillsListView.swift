//
//  BillsListView.swift
//  Budget to 0
//
//  Master list of all bills with Unpaid/Paid sections
//

import SwiftUI

struct BillsListView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var showingAddBill = false
    @State private var selectedBill: Transaction?
    @State private var searchText = ""
    @State private var billToAdjust: Transaction?
    
    var body: some View {
        NavigationView {
            List {
                // UNPAID BILLS - Recurring
                if !unpaidRecurringBills.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Unpaid - Recurring")
                    }) {
                        ForEach(unpaidRecurringBills) { bill in
                            BillRowView(transaction: bill)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedBill = bill
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        dataManager.togglePaidStatus(bill)
                                    } label: {
                                        Label("Paid", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.green)
                                }
                        }
                        .onDelete { indexSet in
                            deleteUnpaidRecurringBills(at: indexSet)
                        }
                    }
                }
                
                // UNPAID BILLS - One-Time
                if !unpaidOneTimeBills.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Unpaid - One-Time")
                    }) {
                        ForEach(unpaidOneTimeBills) { bill in
                            BillRowView(transaction: bill)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedBill = bill
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        dataManager.togglePaidStatus(bill)
                                    } label: {
                                        Label("Paid", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.green)
                                }
                        }
                        .onDelete { indexSet in
                            deleteUnpaidOneTimeBills(at: indexSet)
                        }
                    }
                }
                
                // PAID BILLS - Recurring
                if !paidRecurringBills.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Paid - Recurring")
                    }) {
                        ForEach(paidRecurringBills) { bill in
                            BillRowView(transaction: bill)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedBill = bill
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        dataManager.togglePaidStatus(bill)
                                    } label: {
                                        Label("Unpaid", systemImage: "xmark.circle.fill")
                                    }
                                    .tint(.orange)
                                }
                        }
                        .onDelete { indexSet in
                            deletePaidRecurringBills(at: indexSet)
                        }
                    }
                }
                
                // PAID BILLS - One-Time
                if !paidOneTimeBills.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Paid - One-Time")
                    }) {
                        ForEach(paidOneTimeBills) { bill in
                            BillRowView(transaction: bill)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedBill = bill
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        dataManager.togglePaidStatus(bill)
                                    } label: {
                                        Label("Unpaid", systemImage: "xmark.circle.fill")
                                    }
                                    .tint(.orange)
                                }
                        }
                        .onDelete { indexSet in
                            deletePaidOneTimeBills(at: indexSet)
                        }
                    }
                }
                
                // Empty State
                if unpaidRecurringBills.isEmpty && unpaidOneTimeBills.isEmpty &&
                   paidRecurringBills.isEmpty && paidOneTimeBills.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Bills Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap + to add your first bill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Bills")
            .searchable(text: $searchText, prompt: "Search bills")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddBill = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddBill) {
                AddTransactionView(isIncome: false)
                    .environmentObject(dataManager)
            }
            .sheet(item: $selectedBill) { bill in
                TransactionDetailView(transaction: bill, isRecurringInstance: false)
                    .environmentObject(dataManager)
                
                    .sheet(item: $billToAdjust) { bill in
                        DateAdjustmentView(transaction: bill, isRecurringInstance: false)
                            .environmentObject(dataManager)
                    }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var unpaidRecurringBills: [Transaction] {
        let filtered = dataManager.transactions.filter { !$0.isIncome && $0.isRecurring && !$0.isPaid }
        
        if searchText.isEmpty {
            return filtered.sorted { $0.dueDate < $1.dueDate }
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.dueDate < $1.dueDate }
        }
    }
    
    private var unpaidOneTimeBills: [Transaction] {
        let filtered = dataManager.transactions.filter { !$0.isIncome && !$0.isRecurring && !$0.isPaid }
        
        if searchText.isEmpty {
            return filtered.sorted { $0.dueDate < $1.dueDate }
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.dueDate < $1.dueDate }
        }
    }
    
    private var paidRecurringBills: [Transaction] {
        let filtered = dataManager.transactions.filter { !$0.isIncome && $0.isRecurring && $0.isPaid }
        
        if searchText.isEmpty {
            return filtered.sorted { $0.dueDate < $1.dueDate }
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.dueDate < $1.dueDate }
        }
    }
    
    private var paidOneTimeBills: [Transaction] {
        let filtered = dataManager.transactions.filter { !$0.isIncome && !$0.isRecurring && $0.isPaid }
        
        if searchText.isEmpty {
            return filtered.sorted { $0.dueDate < $1.dueDate }
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.dueDate < $1.dueDate }
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteUnpaidRecurringBills(at offsets: IndexSet) {
        for index in offsets {
            let bill = unpaidRecurringBills[index]
            dataManager.deleteTransaction(bill)
        }
    }
    
    private func deleteUnpaidOneTimeBills(at offsets: IndexSet) {
        for index in offsets {
            let bill = unpaidOneTimeBills[index]
            dataManager.deleteTransaction(bill)
        }
    }
    
    private func deletePaidRecurringBills(at offsets: IndexSet) {
        for index in offsets {
            let bill = paidRecurringBills[index]
            dataManager.deleteTransaction(bill)
        }
    }
    
    private func deletePaidOneTimeBills(at offsets: IndexSet) {
        for index in offsets {
            let bill = paidOneTimeBills[index]
            dataManager.deleteTransaction(bill)
        }
    }
}

// MARK: - Bill Row View

struct BillRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: transaction.category.icon)
                .font(.title3)
                .foregroundColor(colorForCategory(transaction.category.color))
                .opacity(transaction.isPaid ? 0.5 : 1.0)
                .frame(width: 36, height: 36)
                .background(colorForCategory(transaction.category.color).opacity(transaction.isPaid ? 0.05 : 0.1))
                .clipShape(Circle())
            
            // Title & Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.headline)
                    .strikethrough(transaction.isPaid)
                    .foregroundColor(transaction.isPaid ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    if transaction.isRecurring {
                        HStack(spacing: 3) {
                            Image(systemName: "repeat")
                                .font(.caption2)
                            Text(transaction.recurrenceFrequency.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Text(formatDate(transaction.dueDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            Text(formatCurrency(transaction.amount))
                .font(.headline)
                .foregroundColor(transaction.isPaid ? .secondary : .red)
                .opacity(transaction.isPaid ? 0.6 : 1.0)
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
