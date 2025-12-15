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
    
    var body: some View {
        NavigationView {
            Form {
                // Database Info Section
                Section {
                    HStack {
                        Text("Bill Templates")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(recurringBillsCount)")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Income Templates")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(recurringIncomeCount)")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Current Month Transactions")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(currentMonthTransactionsCount)")
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
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
                        Text("2.0.0")
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Database")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("SQLite")
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("System")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Monthly Blueprints")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("About")
                }
                
                // Danger Zone Section
                Section {
                    Button("Delete Old Transactions") {
                        let calendar = Calendar.current
                        let now = Date()
                        let currentMonth = calendar.component(.month, from: now)
                        let currentYear = calendar.component(.year, from: now)
                        
                        DatabaseManager.shared.deleteTransactionsBeforeMonth(month: currentMonth, year: currentYear)
                        DatabaseManager.shared.clearBalanceCache()
                        
                        dataManager.loadData()
                        
                        print("✅ Cleaned up database")
                    }
                    
                    Button("Clear Balance Cache") {
                        DatabaseManager.shared.clearBalanceCache()
                    }
                } header: {
                    Text("Database Cleanup")
                }
                
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
                    Text("This will permanently delete all templates and transactions. This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetDatabase()
                }
            } message: {
                Text("This will permanently delete:\n• \(recurringBillsCount + recurringIncomeCount) templates\n• All monthly transactions\n\nThis cannot be undone.")
            }
            .alert("Database Reset", isPresented: $showingResetSuccess) {
                Button("OK") {
                    // Reload data after reset
                    dataManager.loadData()
                }
            } message: {
                Text("All data has been deleted and the database has been reset.")
            }
        }
    }
    
    
    // MARK: - Computed Properties
    
    private var recurringBillsCount: Int {
        dataManager.templates.filter { !$0.isIncome }.count
    }
    
    private var recurringIncomeCount: Int {
        dataManager.templates.filter { $0.isIncome }.count
    }
    
    private var currentMonthTransactionsCount: Int {
        dataManager.currentMonthTransactions.count
    }
    
    // MARK: - Helper Methods
    
    private func resetDatabase() {
        DatabaseManager.shared.resetDatabase()
        showingResetSuccess = true
    }
}
