//
//  EditBillTemplateView.swift
//  Budget to 0
//
//  Edit recurring bill/income template (user sees it as "Edit Bill/Income")
//

import SwiftUI

struct EditBillTemplateView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @Environment(\.dismiss) var dismiss
    
    let template: BillTemplate
    
    @State private var title = ""
    @State private var amount = ""
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var selectedCategory: TransactionCategory = .other
    @State private var notes = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $title)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TransactionCategory.allCases, id: \.self) { cat in
                            if template.isIncome && cat == .income {
                                HStack {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .tag(cat)
                            } else if !template.isIncome && cat != .income {
                                HStack {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .tag(cat)
                            }
                        }
                    }
                }
                
                Section(header: Text("Frequency")) {
                    Picker("Repeats", selection: $recurrenceFrequency) {
                        ForEach(RecurrenceFrequency.allCases.filter { $0 != .oneTime }, id: \.self) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete \(template.isIncome ? "Income" : "Bill")")
                        }
                    }
                }
            }
            .navigationTitle("Edit \(template.isIncome ? "Income" : "Bill")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty || amount.isEmpty || Double(amount) == nil)
                }
            }
            .alert("Delete \(template.isIncome ? "Income" : "Bill")?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    dataManager.deleteTemplate(template)
                    dismiss()
                }
            } message: {
                Text("This will remove this \(template.isIncome ? "income source" : "bill") from all future months. Past months will not be affected.")
            }
            .onAppear {
                title = template.title
                amount = String(format: "%.2f", template.amount)
                recurrenceFrequency = template.recurrenceFrequency
                selectedCategory = template.category
                notes = template.notes
            }
        }
    }
    
    private func saveChanges() {
        guard let amountValue = Double(amount) else { return }
        
        let updated = BillTemplate(
            id: template.id,
            title: title,
            amount: amountValue,
            isIncome: template.isIncome,
            recurrenceFrequency: recurrenceFrequency,
            category: selectedCategory,
            notes: notes,
            createdAt: template.createdAt
        )
        
        dataManager.updateTemplate(updated)
        dismiss()
    }
}
