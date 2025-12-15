//
//  AddTransactionView.swift
//  Budget to 0
//
//  Beautiful modern UI for adding transactions with NO date restrictions
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
    @State private var isRecurring = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var selectedCategory: TransactionCategory = .other
    @State private var notes = ""
    @State private var showingSavedAlert = false
    @State private var customDays: [Int] = [1, 15] // Default for semi-monthly
    @State private var showingCustomDaysPicker = false
    
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
                            recurringSection
                            notesField
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
                        )
                        .padding(.horizontal)
                        
                        // Save Button
                        saveButton
                            .padding(.bottom, 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isIncome ? "Add Income" : "Add Bill")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Transaction Saved!", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your \(isIncome ? "income" : "bill") has been added successfully.")
            }
            .sheet(isPresented: $showingCustomDaysPicker) {
                CustomDaysPickerView(selectedDays: $customDays)
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
                    
                    Text("Bill/Expense")
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
            
            TextField("e.g., Mortgage, Salary, Netflix", text: $title)
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
    
    // MARK: - Date Picker (NO RESTRICTIONS!)
    
    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Due Date")
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
            
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                Text("You can select ANY date - past, present, or future!")
                    .font(.caption)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 4)
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
    
    // MARK: - Recurring Section (WITH MENU PICKER & DESCRIPTIONS!)
    
    private var recurringSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $isRecurring) {
                Label {
                    Text("Recurring Transaction")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "repeat.circle.fill")
                        .foregroundColor(isIncome ? .green : .red)
                }
            }
            .tint(isIncome ? .green : .red)
            
            if isRecurring {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Frequency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    // MENU-STYLE PICKER WITH DESCRIPTIONS
                    Menu {
                        ForEach(RecurrenceFrequency.allCases.filter { $0 != .oneTime }, id: \.self) { frequency in
                            Button {
                                recurrenceFrequency = frequency
                                // Auto-populate for semi-monthly
                                if frequency == .semiMonthly {
                                    customDays = [1, 15]
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(frequency.rawValue)
                                        if recurrenceFrequency == frequency {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                    
                                    // Add helpful descriptions
                                    if let description = frequencyDescription(frequency) {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recurrenceFrequency.rawValue)
                                    .foregroundColor(.primary)
                                
                                // Show description for current selection
                                if let description = frequencyDescription(recurrenceFrequency) {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
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
                    
                    // Show custom days picker for semi-monthly or custom
                    if recurrenceFrequency == .semiMonthly || recurrenceFrequency == .customDays {
                        Button {
                            showingCustomDaysPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(isIncome ? .green : .red)
                                
                                Text("Select Days: \(customDays.sorted().map(String.init).joined(separator: ", "))")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.tertiarySystemBackground))
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isRecurring ?
                     (isIncome ? Color.green.opacity(0.1) : Color.red.opacity(0.1)) :
                     Color(.secondarySystemBackground))
        )
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
        
        // Dismiss keyboard first
        hideKeyboard()
        
        let transaction = Transaction(
            title: title,
            amount: amountValue,
            isIncome: isIncome,
            isPaid: false,
            dueDate: dueDate,
            isRecurring: isRecurring,
            recurrenceFrequency: isRecurring ? recurrenceFrequency : .oneTime,
            customRecurrenceDays: customDays,
            category: selectedCategory,
            notes: notes
        )
        
        dataManager.addTransaction(transaction)
        
        // Show success alert
        showingSavedAlert = true
        
        // Clear the form
        clearForm()
    }
    
    private func clearForm() {
        title = ""
        amount = ""
        notes = ""
        dueDate = Date()
        isRecurring = false
        recurrenceFrequency = .monthly
        customDays = [1, 15]
        // Keep isIncome and selectedCategory so user can add multiple similar transactions
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                         to: nil, from: nil, for: nil)
    }
    
    private func frequencyDescription(_ frequency: RecurrenceFrequency) -> String? {
        switch frequency {
        case .daily:
            return "Every day"
        case .weekly:
            return "Once a week (7 days)"
        case .biweekly:
            return "Every 2 weeks (14 days)"
        case .monthly:
            return "Once a month"
        case .bimonthly:
            return "Every 2 months (not twice per month)"
        case .semiMonthly:
            return "Twice a month (e.g., 1st & 15th)"
        case .customDays:
            return "Choose specific days each month"
        case .yearly:
            return "Once a year"
        case .oneTime:
            return nil
        }
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

// MARK: - Custom Days Picker Sheet

struct CustomDaysPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDays: [Int]
    @State private var tempSelectedDays: Set<Int> = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60))
                ], spacing: 12) {
                    ForEach(1...31, id: \.self) { day in
                        Button {
                            if tempSelectedDays.contains(day) {
                                tempSelectedDays.remove(day)
                            } else {
                                tempSelectedDays.insert(day)
                            }
                        } label: {
                            Text("\(day)")
                                .font(.headline)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(tempSelectedDays.contains(day) ? Color.blue : Color(.secondarySystemBackground))
                                )
                                .foregroundColor(tempSelectedDays.contains(day) ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Days of Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDays = Array(tempSelectedDays).sorted()
                        dismiss()
                    }
                    .disabled(tempSelectedDays.isEmpty)
                }
            }
            .onAppear {
                tempSelectedDays = Set(selectedDays)
            }
        }
    }
}
