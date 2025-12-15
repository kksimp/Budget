//
//  BillsListView.swift
//  Budget to 0
//
//  Shows recurring bill templates (user sees them as "bills")
//

import SwiftUI

struct BillsListView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @State private var showingAddBill = false
    @State private var selectedTemplate: BillTemplate?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List {
                // Recurring Bills
                if !recurringBills.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "repeat")
                            .foregroundColor(.blue)
                        Text("Recurring Bills")
                    }) {
                        ForEach(recurringBills) { template in
                            BillTemplateRowView(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTemplate = template
                                }
                        }
                        .onDelete { indexSet in
                            deleteRecurringBills(at: indexSet)
                        }
                    }
                }
                
                // Empty State
                if recurringBills.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Bills Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap + to add your first recurring bill")
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
                AddBillTemplateView(isIncome: false)
                    .environmentObject(dataManager)
            }
            .sheet(item: $selectedTemplate) { template in
                EditBillTemplateView(template: template)
                    .environmentObject(dataManager)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recurringBills: [BillTemplate] {
        let filtered = dataManager.templates.filter { !$0.isIncome }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteRecurringBills(at offsets: IndexSet) {
        for index in offsets {
            let template = recurringBills[index]
            dataManager.deleteTemplate(template)
        }
    }
}

// MARK: - Bill Template Row View

struct BillTemplateRowView: View {
    let template: BillTemplate
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: template.category.icon)
                .font(.title3)
                .foregroundColor(colorForCategory(template.category.color))
                .frame(width: 36, height: 36)
                .background(colorForCategory(template.category.color).opacity(0.1))
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
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
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
