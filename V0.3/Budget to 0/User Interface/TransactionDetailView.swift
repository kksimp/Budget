//
//  TransactionDetailView.swift
//  Budget to 0
//
//  View and edit individual transaction from Timeline
//

import SwiftUI

struct TransactionDetailView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @Environment(\.dismiss) var dismiss
    
    let transaction: Transaction
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedAmount = ""
    @State private var editedDueDate = Date()
    @State private var editedCategory: TransactionCategory = .other
    @State private var editedNotes = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Status Section
                statusSection
                
                if isEditing {
                    // Editing Mode
                    editingSections
                } else {
                    // View Mode
                    viewSections
                }
            }
            .navigationTitle(transaction.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            startEditing()
                        }
                    }
                }
                
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isEditing = false
                            loadTransactionData()
                        }
                    }
                }
            }
            .alert("Delete Transaction?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    dataManager.deleteTransaction(transaction)
                    dismiss()
                }
            } message: {
                Text("This will remove this transaction from \(monthYearString(transaction.dueDate)). This change only affects this month.")
            }
            .onAppear {
                loadTransactionData()
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section {
            HStack {
                Text("Status")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    dataManager.togglePaidStatus(transaction)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: transaction.isPaid ? "checkmark.circle.fill" : "circle")
                        Text(transaction.isPaid ? "Paid" : "Unpaid")
                    }
                    .foregroundColor(transaction.isPaid ? .green : .orange)
                    .fontWeight(.semibold)
                }
            }
            
            if transaction.isPaid, let paymentDate = transaction.actualPaymentDate {
                HStack {
                    Text("Paid On")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(paymentDate))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var viewSections: some View {
        Group {
            Section(header: Text("Details")) {
                LabeledContent("Type", value: transaction.isIncome ? "Income" : "Expense")
                LabeledContent("Amount", value: formatCurrency(transaction.amount))
                LabeledContent("Category", value: transaction.category.rawValue)
                LabeledContent("Due Date", value: formatDate(transaction.dueDate))
            }
            
            Section(header: Text("Info")) {
                if transaction.templateId != nil {
                    HStack {
                        Text("Source")
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.caption)
                            Text("Recurring")
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    HStack {
                        Text("Source")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("One-time")
                            .foregroundColor(.secondary)
                    }
                }
                
                LabeledContent("Month", value: monthYearString(transaction.dueDate))
            }
            
            if !transaction.notes.isEmpty {
                Section(header: Text("Notes")) {
                    Text(transaction.notes)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete Transaction")
                    }
                }
            }
        }
    }
    
    // MARK: - Editing Sections
    
    private var editingSections: some View {
        Group {
            Section(header: Text("Details")) {
                TextField("Title", text: $editedTitle)
                
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("Amount", text: $editedAmount)
                        .keyboardType(.decimalPad)
                }
                
                Picker("Category", selection: $editedCategory) {
                    ForEach(TransactionCategory.allCases, id: \.self) { cat in
                        HStack {
                            Image(systemName: cat.icon)
                            Text(cat.rawValue)
                        }
                        .tag(cat)
                    }
                }
                
                DatePicker("Due Date", selection: $editedDueDate, displayedComponents: .date)
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $editedNotes)
                    .frame(height: 100)
            }
            
            if transaction.templateId != nil {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Editing This Month Only")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Changes only affect this transaction in \(monthYearString(transaction.dueDate)). To change all future months, edit the bill/income in the Bills or Income tab.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTransactionData() {
        editedTitle = transaction.title
        editedAmount = String(format: "%.2f", transaction.amount)
        editedDueDate = transaction.dueDate
        editedCategory = transaction.category
        editedNotes = transaction.notes
    }
    
    private func startEditing() {
        isEditing = true
    }
    
    private func saveChanges() {
        guard let amountValue = Double(editedAmount) else { return }
        
        var updated = transaction
        updated.title = editedTitle
        updated.amount = amountValue
        updated.dueDate = editedDueDate
        updated.category = editedCategory
        updated.notes = editedNotes
        
        dataManager.updateTransaction(updated)
        isEditing = false
        dismiss()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
