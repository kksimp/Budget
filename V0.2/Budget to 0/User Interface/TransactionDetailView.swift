//
//  TransactionDetailView.swift
//  Budget to 0
//
//  View and edit transaction details with support for editing single vs all recurring instances
//

import SwiftUI

struct TransactionDetailView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @Environment(\.dismiss) var dismiss
    
    let transaction: Transaction
    let isRecurringInstance: Bool // TRUE if this is a generated instance, FALSE if it's the original
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedAmount = ""
    @State private var editedDueDate = Date()
    @State private var editedIsRecurring = false
    @State private var editedRecurrence: RecurrenceFrequency = .monthly
    @State private var editedCategory: TransactionCategory = .other
    @State private var editedNotes = ""
    @State private var showingUpdateChoice = false
    @State private var updateChoice: RecurringUpdateChoice = .thisInstanceOnly
    
    init(transaction: Transaction, isRecurringInstance: Bool = false) {
        self.transaction = transaction
        self.isRecurringInstance = isRecurringInstance
    }
    
    var body: some View {
        Form {
            // Status Section
            statusSection
            
            if isEditing {
                // Editing Mode
                editingSections
                
                // Update choice for recurring transactions
                if transaction.isRecurring && isRecurringInstance {
                    recurringUpdateSection
                }
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
        .onAppear {
            loadTransactionData()
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
            
            Section(header: Text("Recurrence")) {
                LabeledContent("Recurring", value: transaction.isRecurring ? "Yes" : "No")
                
                if transaction.isRecurring {
                    LabeledContent("Frequency", value: transaction.recurrenceFrequency.rawValue)
                    
                    if isRecurringInstance {
                        Text("This is an auto-generated instance of a recurring transaction")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if !transaction.notes.isEmpty {
                Section(header: Text("Notes")) {
                    Text(transaction.notes)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Metadata")) {
                LabeledContent("Created", value: formatDateTime(transaction.createdAt))
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
            
            Section(header: Text("Recurrence")) {
                Toggle("Recurring", isOn: $editedIsRecurring)
                
                if editedIsRecurring {
                    Picker("Frequency", selection: $editedRecurrence) {
                        ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                            if frequency != .oneTime {
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $editedNotes)
                    .frame(height: 100)
            }
        }
    }
    
    // MARK: - Recurring Update Choice Section
    
    private var recurringUpdateSection: some View {
        Section(header: Text("Update Options")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("How would you like to update this recurring transaction?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    updateChoice = .thisInstanceOnly
                }) {
                    HStack {
                        Image(systemName: updateChoice == .thisInstanceOnly ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("This Instance Only")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Create a one-time override for this date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    updateChoice = .allFutureInstances
                }) {
                    HStack {
                        Image(systemName: updateChoice == .allFutureInstances ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Future Instances")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Update the recurring transaction permanently")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTransactionData() {
        editedTitle = transaction.title
        editedAmount = String(format: "%.2f", transaction.amount)
        editedDueDate = transaction.dueDate
        editedIsRecurring = transaction.isRecurring
        editedRecurrence = transaction.recurrenceFrequency
        editedCategory = transaction.category
        editedNotes = transaction.notes
    }
    
    private func startEditing() {
        isEditing = true
    }
    
    private func saveChanges() {
        guard let amountValue = Double(editedAmount) else { return }
        
        if transaction.isRecurring && isRecurringInstance {
            // This is a recurring instance - handle based on user choice
            switch updateChoice {
            case .thisInstanceOnly:
                // Create a one-time override transaction for this specific date
                let overrideTransaction = Transaction(
                    title: editedTitle,
                    amount: amountValue,
                    isIncome: transaction.isIncome,
                    isPaid: transaction.isPaid,
                    dueDate: editedDueDate,
                    isRecurring: false,
                    recurrenceFrequency: .oneTime,
                    category: editedCategory,
                    notes: editedNotes + "\n[Override for \(formatDate(transaction.dueDate))]"
                )
                dataManager.addTransaction(overrideTransaction)
                
            case .allFutureInstances:
                // Find and update the original recurring transaction
                if let originalTransaction = findOriginalRecurringTransaction() {
                    let updatedTransaction = Transaction(
                        id: originalTransaction.id,
                        title: editedTitle,
                        amount: amountValue,
                        isIncome: originalTransaction.isIncome,
                        isPaid: originalTransaction.isPaid,
                        dueDate: originalTransaction.dueDate,
                        isRecurring: true,
                        recurrenceFrequency: editedRecurrence,
                        category: editedCategory,
                        notes: editedNotes,
                        createdAt: originalTransaction.createdAt
                    )
                    dataManager.updateTransaction(updatedTransaction)
                }
            }
        } else {
            // This is either a one-time transaction or the original recurring transaction
            let updatedTransaction = Transaction(
                id: transaction.id,
                title: editedTitle,
                amount: amountValue,
                isIncome: transaction.isIncome,
                isPaid: transaction.isPaid,
                dueDate: editedDueDate,
                isRecurring: editedIsRecurring,
                recurrenceFrequency: editedIsRecurring ? editedRecurrence : .oneTime,
                category: editedCategory,
                notes: editedNotes,
                createdAt: transaction.createdAt
            )
            
            dataManager.updateTransaction(updatedTransaction)
        }
        
        isEditing = false
        dismiss()
    }
    
    private func findOriginalRecurringTransaction() -> Transaction? {
        // Find the original recurring transaction by matching title, amount, and recurrence
        return dataManager.transactions.first { stored in
            stored.isRecurring &&
            stored.title == transaction.title &&
            stored.recurrenceFrequency == transaction.recurrenceFrequency
        }
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
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum RecurringUpdateChoice {
    case thisInstanceOnly
    case allFutureInstances
}


