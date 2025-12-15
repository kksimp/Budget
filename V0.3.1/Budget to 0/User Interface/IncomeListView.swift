//
//  IncomeListView.swift
//  Budget to 0
//
//  Shows recurring income templates (user sees them as "income sources")
//

import SwiftUI

struct IncomeListView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var showingAddIncome = false
    @State private var selectedTemplate: BillTemplate?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List {
                // Recurring Income
                if !recurringIncome.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "repeat")
                            .foregroundColor(.green)
                        Text("Recurring Income")
                    }) {
                        ForEach(recurringIncome) { template in
                            IncomeTemplateRowView(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTemplate = template
                                }
                        }
                        .onDelete { indexSet in
                            deleteRecurringIncome(at: indexSet)
                        }
                    }
                }
                
                // Empty State
                if recurringIncome.isEmpty {
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
                AddBillTemplateView(isIncome: true)
                    .environmentObject(dataManager)
            }
            .sheet(item: $selectedTemplate) { template in
                EditBillTemplateView(template: template)
                    .environmentObject(dataManager)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recurringIncome: [BillTemplate] {
        let filtered = dataManager.templates.filter { $0.isIncome }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteRecurringIncome(at offsets: IndexSet) {
        for index in offsets {
            let template = recurringIncome[index]
            dataManager.deleteTemplate(template)
        }
    }
}

// MARK: - Income Template Row View

struct IncomeTemplateRowView: View {
    let template: BillTemplate
    
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
                Text(template.title)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                            .font(.caption2)
                        Text(template.recurrenceFrequency.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Amount
            Text(formatCurrency(template.amount))
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
}
