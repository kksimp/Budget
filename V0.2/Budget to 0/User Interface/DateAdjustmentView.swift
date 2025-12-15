//
//  DateAdjustmentView.swift
//  Budget to 0
//
//  Custom date picker for adjusting transaction dates
//

import SwiftUI

struct DateAdjustmentView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @Environment(\.dismiss) var dismiss
    
    let transaction: Transaction
    let isRecurringInstance: Bool
    
    @State private var newDate: Date
    @State private var markAsPaid = false
    @State private var showingConfirmation = false
    
    init(transaction: Transaction, isRecurringInstance: Bool) {
        self.transaction = transaction
        self.isRecurringInstance = isRecurringInstance
        _newDate = State(initialValue: transaction.dueDate)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transaction.title)
                            .font(.headline)
                        
                        Text(formatCurrency(transaction.amount))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(transaction.isIncome ? .green : .red)
                        
                        if transaction.isRecurring {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                Text(transaction.recurrenceFrequency.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Transaction")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Original Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatFullDate(transaction.dueDate))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $newDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                    
                    // Quick date buttons
                    VStack(spacing: 8) {
                        Button(action: {
                            newDate = Date()
                        }) {
                            HStack {
                                Image(systemName: "calendar.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Today")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        
                        Button(action: {
                            newDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Tomorrow")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        
                        Button(action: {
                            newDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.blue)
                                Text("Next Week")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("Date Adjustment")
                }
                
                Section {
                    Toggle(isOn: $markAsPaid) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Mark as Paid")
                        }
                    }
                    .tint(.green)
                } header: {
                    Text("Payment Status")
                } footer: {
                    if isRecurringInstance {
                        Text("This will create a one-time override for this date only. The recurring schedule will continue normally.")
                    } else {
                        Text("This will update the transaction date. If it's recurring, all future instances will shift to the new date.")
                    }
                }
                
                if isRecurringInstance {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Recurring Instance")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            Text("You're adjusting a generated instance. This will create a one-time transaction for the new date. The original recurring schedule remains unchanged.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Adjust Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showingConfirmation = true
                    }
                    .disabled(Calendar.current.isDate(newDate, inSameDayAs: transaction.dueDate) && markAsPaid == transaction.isPaid)
                }
            }
            .alert("Confirm Date Change", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm") {
                    saveDateAdjustment()
                }
            } message: {
                if isRecurringInstance {
                    Text("This will create a one-time transaction on \(formatFullDate(newDate))\(markAsPaid ? " and mark it as paid" : ""). The recurring schedule will continue unchanged.")
                } else {
                    Text("This will change the transaction date to \(formatFullDate(newDate))\(markAsPaid ? " and mark it as paid" : "").")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveDateAdjustment() {
        if isRecurringInstance {
            // This is a generated instance - create an override
            let override = Transaction(
                title: transaction.title,
                amount: transaction.amount,
                isIncome: transaction.isIncome,
                isPaid: markAsPaid,
                dueDate: newDate,
                isRecurring: false,
                recurrenceFrequency: .oneTime,
                customRecurrenceDays: [],
                category: transaction.category,
                notes: transaction.notes + "\n[Adjusted from \(formatFullDate(transaction.dueDate))]"
            )
            
            dataManager.addTransaction(override)
        } else {
            // This is a stored transaction - update it
            var updated = transaction
            updated.dueDate = newDate
            updated.isPaid = markAsPaid
            
            dataManager.updateTransaction(updated)
        }
        
        dismiss()
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
