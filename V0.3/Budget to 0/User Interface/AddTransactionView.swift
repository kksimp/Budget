//
//  AddTransactionView.swift
//  Budget to 0
//
//  Add one-time transaction (not a template)
//

import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject var dataManager: EnhancedDataManager
    @Environment(\.dismiss) var dismiss
    
    let defaultIsIncome: Bool
    
    @State private var title = ""
    @State private var amount = ""
    @State private var isIncome = false
    @State private var dueDate = Date()
    @State private var selectedCategory: TransactionCategory = .other
    @State private var notes = ""
    @State private var showingSavedAlert = false
    
    init(isIncome: Bool = false) {
        self.defaultIsIncome = isIncome
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        isIncome ? Color.green.opacity(0.05) : Color.red.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Type Selector Card
                        typeSelector
                            .padding(.top, 8)
                        
                        // Main Form Card
                        VStack(spacing: 20) {
                            titleField
                            amountField
                            datePicker
                            categoryPicker
                            notesField
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
                        )
                        .padding(.horizontal)
                        
                        // Info Box
                        infoBox
                        
                        // Save Button
                        saveButton
                            .padding(.bottom, 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("One-Time Transaction")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Transaction Saved!", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Your one-time \(isIncome ? "income" : "expense") has been added to \(monthYearString(dueDate)).")
            }
            .onAppear {
                isIncome = defaultIsIncome
                selectedCategory = defaultIsIncome ? .income : .other
            }
        }
    }
    
    // MARK: - Type Selector
    
    private var typeSelector: some View {
        HStack(spacing: 12) {
            // Expense Button
            Button {
                isIncome = false
                if selectedCategory == .income {
                    selectedCategory = .other
                }
            } label: {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isIncome ? Color(.secondarySystemBackground) : Color.red)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(isIncome ? .red.opacity(0.5) : .white)
                    }
                    
                    Text("Expense")
                        .font(.subheadline)
                        .fontWeight(isIncome ? .regular : .bold)
                        .foregroundColor(isIncome ? .secondary : .red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isIncome ? Color(.tertiarySystemBackground) : Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isIncome ? Color.clear : Color.red, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)
            
            // Income Button
            Button {
                isIncome = true
                selectedCategory = .income
            } label: {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isIncome ? Color.green : Color(.secondarySystemBackground))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(isIncome ? .white : .green.opacity(0.5))
                    }
                    
                    Text("Income")
                        .font(.subheadline)
                        .fontWeight(isIncome ? .bold : .regular)
                        .foregroundColor(isIncome ? .green : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isIncome ? Color.green.opacity(0.1) : Color(.tertiarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isIncome ? Color.green : Color.clear, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Title Field
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Title")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "text.alignleft")
                    .foregroundColor(isIncome ? .green : .red)
            }
            
            TextField("e.g., Birthday Gift, Bonus", text: $title)
                .font(.body)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
    
    // MARK: - Amount Field
    
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Amount")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(isIncome ? .green : .red)
            }
            
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(isIncome ? .green : .red)
                
                TextField("0.00", text: $amount)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .foregroundColor(.primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Date Picker
    
    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Date")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "calendar")
                    .foregroundColor(isIncome ? .green : .red)
            }
            
            DatePicker(
                "",
                selection: $dueDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Category Picker
    
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Category")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "tag.fill")
                    .foregroundColor(isIncome ? .green : .red)
            }
            
            Menu {
                ForEach(TransactionCategory.allCases, id: \.self) { category in
                    if isIncome && category == .income {
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    } else if !isIncome && category != .income {
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .foregroundColor(colorForCategory(selectedCategory.color))
                    
                    Text(selectedCategory.rawValue)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }
    
    // MARK: - Notes Field
    
    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Notes (Optional)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "note.text")
                    .foregroundColor(isIncome ? .green : .red)
            }
            
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add any additional details...")
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                }
                
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Info Box
    
    private var infoBox: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("One-Time Transaction")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("This will be added to \(monthYearString(dueDate)) only. For recurring bills/income, use the Bills or Income tabs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveTransaction) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                
                Text("Save Transaction")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isIncome ?
                        [Color.green, Color.green.opacity(0.8)] :
                        [Color.red, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(
                color: (isIncome ? Color.green : Color.red).opacity(0.4),
                radius: 12,
                y: 6
            )
        }
        .padding(.horizontal)
        .disabled(title.isEmpty || amount.isEmpty || Double(amount) == nil)
        .opacity((title.isEmpty || amount.isEmpty || Double(amount) == nil) ? 0.5 : 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
        let calendar = Calendar.current
        let month = calendar.component(.month, from: dueDate)
        let year = calendar.component(.year, from: dueDate)
        
        let transaction = Transaction(
            templateId: nil, // This is a one-time transaction
            month: month,
            year: year,
            title: title,
            amount: amountValue,
            isIncome: isIncome,
            isPaid: false,
            dueDate: dueDate,
            actualPaymentDate: nil,
            displayOrder: 9999, // Will sort to end
            category: selectedCategory,
            notes: notes
        )
        
        dataManager.addOneTimeTransaction(transaction)
        showingSavedAlert = true
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
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
