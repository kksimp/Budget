//
//  EditBillTemplateView.swift
//  Budget to 0
//
//  Edit recurring bill/income template with date pickers
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
    
    // Date fields
    @State private var selectedDay = 1
    @State private var startDate = Date()
    @State private var semiMonthlyDay1 = 1
    @State private var semiMonthlyDay2 = 15
    
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
                    .onChange(of: recurrenceFrequency) { oldValue, newValue in
                        // Reset defaults when frequency changes
                        if newValue == .monthly || newValue == .bimonthly || newValue == .yearly {
                            selectedDay = template.dueDay ?? 1
                        } else if newValue == .weekly || newValue == .biweekly {
                            startDate = template.startDate ?? Date()
                        } else if newValue == .semiMonthly {
                            semiMonthlyDay1 = template.semiMonthlyDay1 ?? 1
                            semiMonthlyDay2 = template.semiMonthlyDay2 ?? 15
                        }
                    }
                }
                
                // Show appropriate date pickers based on frequency
                datePickerSection
                
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
                loadTemplateData()
            }
        }
    }
    
    // MARK: - Date Picker Section
    
    @ViewBuilder
    private var datePickerSection: some View {
        switch recurrenceFrequency {
        case .monthly, .bimonthly, .yearly:
            Section(header: Text("Due Day")) {
                Picker("Day of Month", selection: $selectedDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                
                Text("This \(template.isIncome ? "income" : "bill") will occur on day \(selectedDay) of each month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .weekly, .biweekly:
            Section(header: Text("Start Date")) {
                DatePicker(
                    "First Occurrence",
                    selection: $startDate,
                    displayedComponents: [.date]
                )
                
                Text("This \(template.isIncome ? "income" : "bill") will occur every \(recurrenceFrequency == .weekly ? "week" : "2 weeks") on \(dayOfWeekString(startDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .semiMonthly:
            Section(header: Text("Payment Days")) {
                Picker("First Day", selection: $semiMonthlyDay1) {
                    ForEach(1...28, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                
                Picker("Second Day", selection: $semiMonthlyDay2) {
                    ForEach(1...28, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                
                Text("This \(template.isIncome ? "income" : "bill") will occur on the \(ordinal(semiMonthlyDay1)) and \(ordinal(semiMonthlyDay2)) of each month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTemplateData() {
        title = template.title
        amount = String(format: "%.2f", template.amount)
        recurrenceFrequency = template.recurrenceFrequency
        selectedCategory = template.category
        notes = template.notes
        
        // Load date fields
        selectedDay = template.dueDay ?? 1
        startDate = template.startDate ?? Date()
        semiMonthlyDay1 = template.semiMonthlyDay1 ?? 1
        semiMonthlyDay2 = template.semiMonthlyDay2 ?? 15
    }
    
    private func saveChanges() {
        guard let amountValue = Double(amount) else { return }
        
        var dueDay: Int? = nil
        var startDateValue: Date? = nil
        var semiDay1: Int? = nil
        var semiDay2: Int? = nil
        
        switch recurrenceFrequency {
        case .monthly, .bimonthly, .yearly:
            dueDay = selectedDay
            
        case .weekly, .biweekly:
            startDateValue = startDate
            
        case .semiMonthly:
            semiDay1 = semiMonthlyDay1
            semiDay2 = semiMonthlyDay2
            
        default:
            break
        }
        
        let updated = BillTemplate(
            id: template.id,
            title: title,
            amount: amountValue,
            isIncome: template.isIncome,
            recurrenceFrequency: recurrenceFrequency,
            category: selectedCategory,
            notes: notes,
            createdAt: template.createdAt,
            dueDay: dueDay,
            startDate: startDateValue,
            semiMonthlyDay1: semiDay1,
            semiMonthlyDay2: semiDay2
        )
        
        dataManager.updateTemplate(updated)
        dismiss()
    }
    
    private func dayOfWeekString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func ordinal(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
