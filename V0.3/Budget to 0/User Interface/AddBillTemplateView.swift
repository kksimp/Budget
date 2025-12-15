//
//  AddBillTemplateView.swift
//  Budget to 0
//
//  Add recurring bill/income template (user sees it as "Add Bill/Income")
//

import SwiftUI

struct AddBillTemplateView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @Environment(\.dismiss) var dismiss
    
    let isIncome: Bool
    
    @State private var title = ""
    @State private var amount = ""
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var selectedCategory: TransactionCategory = .other
    @State private var notes = ""
    
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
                            if isIncome && cat == .income {
                                HStack {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .tag(cat)
                            } else if !isIncome && cat != .income {
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
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle(isIncome ? "Add Income" : "Add Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(title.isEmpty || amount.isEmpty || Double(amount) == nil)
                }
            }
            .onAppear {
                selectedCategory = isIncome ? .income : .other
            }
        }
    }
    
    private func saveTemplate() {
        guard let amountValue = Double(amount) else { return }
        
        let template = BillTemplate(
            title: title,
            amount: amountValue,
            isIncome: isIncome,
            recurrenceFrequency: recurrenceFrequency,
            category: selectedCategory,
            notes: notes
        )
        
        dataManager.addTemplate(template)
        dismiss()
    }
}
