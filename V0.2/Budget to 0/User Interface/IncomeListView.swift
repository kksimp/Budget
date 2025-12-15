//
//  IncomeListView.swift
//  Budget to 0
//
//  Master list of all income sources
//

import SwiftUI

struct IncomeListView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var showingAddIncome = false
    @State private var selectedIncome: Transaction?
    @State private var searchText = ""
    @State private var incomeToAdjust: Transaction?
    
    var body: some View {
        NavigationView {
            List {
                // Recurring Income Section
                if !recurringIncome.isEmpty {
                    Section(header: Text("Recurring Income")) {
                        ForEach(recurringIncome) { income in
                            IncomeRowView(transaction: income)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedIncome = income
                                }
                        }
                        .onDelete { indexSet in
                            deleteRecurringIncome(at: indexSet)
                        }
                    }
                }
                
                // One-Time Income Section
                if !oneTimeIncome.isEmpty {
                    Section(header: Text("One-Time Income")) {
                        ForEach(oneTimeIncome) { income in
                            IncomeRowView(transaction: income)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedIncome = income
                                }
                        }
                        .onDelete { indexSet in
                            deleteOneTimeIncome(at: indexSet)
                        }
                    }
                }
                
                // Empty State
                if recurringIncome.isEmpty && oneTimeIncome.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Income Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap + to add your first income source")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Income")
            .searchable(text: $searchText, prompt: "Search income")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddIncome = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddIncome) {
                AddTransactionView(isIncome: true)
                    .environmentObject(dataManager)
            }
            .sheet(item: $selectedIncome) { income in
                TransactionDetailView(transaction: income, isRecurringInstance: false)
                    .environmentObject(dataManager)
            
                    .sheet(item: $incomeToAdjust) { income in
                        DateAdjustmentView(transaction: income, isRecurringInstance: false)
                            .environmentObject(dataManager)
                    }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recurringIncome: [Transaction] {
        let filtered = dataManager.transactions.filter { $0.isIncome && $0.isRecurring }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var oneTimeIncome: [Transaction] {
        let filtered = dataManager.transactions.filter { $0.isIncome && !$0.isRecurring }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteRecurringIncome(at offsets: IndexSet) {
        for index in offsets {
            let income = recurringIncome[index]
            dataManager.deleteTransaction(income)
        }
    }
    
    private func deleteOneTimeIncome(at offsets: IndexSet) {
        for index in offsets {
            let income = oneTimeIncome[index]
            dataManager.deleteTransaction(income)
        }
    }
}

// MARK: - Income Row View

struct IncomeRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "dollarsign.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.1))
                .clipShape(Circle())
            
            // Title & Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.headline)
                
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
                .foregroundColor(.green)
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
}
