//
//  DashboardView.swift
//  Budget to 0
//
//  Overview dashboard with balance and monthly summary
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var selectedMonth = Date()
    @State private var showingBalanceEditor = false
    @State private var showingBalanceCorrectionWarning = false
    @State private var newBalanceString = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Balance Card
                    currentBalanceCard
                    
                    // Month Navigator
                    monthNavigator
                    
                    // Monthly Summary Card
                    monthlySummaryCard
                    
                    // Upcoming Transactions
                    upcomingTransactionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget Overview")
            .alert("Edit Current Balance", isPresented: $showingBalanceEditor) {
                TextField("New Balance", text: $newBalanceString)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    showingBalanceCorrectionWarning = true
                }
            } message: {
                Text("Enter the actual current balance from your bank account.")
            }
            .alert("Create Balance Correction?", isPresented: $showingBalanceCorrectionWarning) {
                Button("Cancel", role: .cancel) { }
                Button("Create Correction") {
                    createBalanceCorrection()
                }
            } message: {
                Text("This will create a balance correction transaction to match your actual bank balance. The correction will appear in your timeline as '\(getCorrectionType())' on today's date.")
            }
        }
    }
    
    // MARK: - Current Balance Card
    
     private var currentBalanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Balance")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    newBalanceString = String(format: "%.2f", abs(dataManager.currentBalance()))
                    showingBalanceEditor = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                        Text("Correct")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Text(formatCurrency(dataManager.currentBalance()))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(balanceColor(dataManager.currentBalance()))
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
        )
    }
    
    // MARK: - Month Navigator
    
    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(monthYearString(selectedMonth))
                .font(.title3)
                .fontWeight(.bold)
            
            Spacer()
            
            Button {
                withAnimation {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Monthly Summary Card

    private var monthlySummaryCard: some View {
        VStack(spacing: 20) {
            // Income and Expenses Row
            HStack(spacing: 40) {
                // Income
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("Income")
                            .font(.headline)
                    }
                    
                    Text(formatCurrency(dataManager.totalIncome(for: selectedMonth)))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                // Expenses
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.red)
                        Text("Expenses")
                            .font(.headline)
                    }
                    
                    Text(formatCurrency(dataManager.totalExpenses(for: selectedMonth)))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            
            Divider()
            
            // Net Row
            VStack(spacing: 8) {
                Text("Net")
                    .font(.headline)
                
                Text(formatCurrency(dataManager.netIncome(for: selectedMonth)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(netColor(dataManager.netIncome(for: selectedMonth)))
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
        )
    }

    
    // MARK: - Upcoming Transactions Section
    
    private var upcomingTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming (Next 7 Days)")
                .font(.headline)
                .padding(.horizontal, 4)
            
            if upcomingTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No upcoming transactions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(upcomingTransactions.prefix(5)) { transaction in
                        UpcomingTransactionRow(transaction: transaction)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var upcomingTransactions: [Transaction] {
        dataManager.getUpcomingTransactions(days: 7)
    }
    
    // MARK: - Helper Methods
    
    private func createBalanceCorrection() {
        guard let newBalance = Double(newBalanceString) else { return }
        
        let currentBalance = dataManager.currentBalance()
        let difference = newBalance - currentBalance
        
        guard difference != 0 else {
            newBalanceString = ""
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        // Create a balance correction transaction - AUTOMATICALLY MARKED AS PAID
        let correction = Transaction(
            templateId: nil,
            month: month,
            year: year,
            title: "Balance Correction",
            amount: abs(difference),
            isIncome: difference > 0,
            isPaid: true,
            dueDate: now,
            actualPaymentDate: now,
            displayOrder: 9999,
            category: .other,
            notes: "Manual balance adjustment from \(formatCurrency(currentBalance)) to \(formatCurrency(newBalance))"
        )
        
        dataManager.addOneTimeTransaction(correction)
        newBalanceString = ""
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func getCorrectionType() -> String {
        guard let newBalance = Double(newBalanceString) else { return "Correction" }
        let currentBalance = dataManager.currentBalance()
        let difference = newBalance - currentBalance
        
        if difference > 0 {
            return "Income of \(formatCurrency(abs(difference)))"
        } else {
            return "Expense of \(formatCurrency(abs(difference)))"
        }
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
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
    
    private func netColor(_ net: Double) -> Color {
        if net > 0 {
            return .green
        } else if net == 0 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Upcoming Transaction Row

struct UpcomingTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(transaction.isIncome ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(transaction.isIncome ? .green : .red)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatDate(transaction.dueDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(formatCurrency(transaction.amount))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(transaction.isIncome ? .green : .red)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
