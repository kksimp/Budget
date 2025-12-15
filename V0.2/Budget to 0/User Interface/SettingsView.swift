//
//  SettingsView.swift
//  Budget to 0
//
//  Settings with database management
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var showingResetAlert = false
    @State private var showingResetSuccess = false
    @State private var showingBalanceEditor = false
    @State private var newBalanceString = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Balance Section
                Section {
                    HStack {
                        Text("Starting Balance")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            newBalanceString = String(format: "%.2f", dataManager.startingBalance)
                            showingBalanceEditor = true
                        }) {
                            Text(formatCurrency(dataManager.startingBalance))
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Account")
                }
                
                // Database Info Section
                Section {
                    HStack {
                        Text("Total Transactions")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(dataManager.transactions.count)")
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Recurring Bills")
                        Spacer()
                        Text("\(recurringBillsCount)")
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Recurring Income")
                        Spacer()
                        Text("\(recurringIncomeCount)")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Statistics")
                }
                
                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Database")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("SQLite")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("About")
                }
                
                // Danger Zone Section
                Section {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                            Text("Reset All Data")
                        }
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This will permanently delete all transactions and reset your starting balance to $0. This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .alert("Edit Starting Balance", isPresented: $showingBalanceEditor) {
                TextField("Amount", text: $newBalanceString)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let newBalance = Double(newBalanceString) {
                        dataManager.updateStartingBalance(newBalance)
                    }
                }
            } message: {
                Text("Enter your account's starting balance")
            }
            .alert("Reset All Data?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetDatabase()
                }
            } message: {
                Text("This will permanently delete all \(dataManager.transactions.count) transactions and reset your starting balance. This cannot be undone.")
            }
            .alert("Database Reset", isPresented: $showingResetSuccess) {
                Button("OK") { }
            } message: {
                Text("All data has been deleted and the database has been reset.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recurringBillsCount: Int {
        dataManager.transactions.filter { !$0.isIncome && $0.isRecurring }.count
    }
    
    private var recurringIncomeCount: Int {
        dataManager.transactions.filter { $0.isIncome && $0.isRecurring }.count
    }
    
    // MARK: - Helper Methods
    
    private func resetDatabase() {
        DatabaseManager.shared.resetDatabase()
        dataManager.loadData()
        showingResetSuccess = true
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
