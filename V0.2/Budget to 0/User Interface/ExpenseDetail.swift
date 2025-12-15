//
//  ExpenseDetail.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/4/24.
//

import SwiftUI

struct ExpenseDetail: View {
    var dataManager: DataManager
    @ObservedObject var expense: Expense
    var updateBalance: () -> Void  // Callback for updating the balance

    
    var body: some View {
        VStack {
            Text(expense.title)
                .font(.title)
            
            Text("Amount: \(expense.amount)")
            
            Text("Due Date: \(dateFormatter.string(from: expense.dueDate))")
            
            Text("Recurring: \(expense.recurring ? "Yes" : "No")")
            
            // Add more details as needed
            
            Spacer()
            
            Button("Mark as Paid") {
                        expense.paid = true
                        updateBalance()
                    }
                }
            
        
        
        .padding()
        .navigationBarTitle("Expense Detail")
    }
    
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
}

