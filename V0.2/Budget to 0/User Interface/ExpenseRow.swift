//
//  ExpenseRow.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/7/24.
//

import SwiftUI

struct ExpenseRow: View {
    var dataManager: DataManager
    var expense: Expense
    var updateBalance: () -> Void  // Callback for updating the balance

    var body: some View {
        NavigationLink(
            destination: ExpenseDetail(dataManager: dataManager, expense: expense, updateBalance: updateBalance),
            label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(expense.title)
                            .font(.headline)

                        // Format the amount to limit decimal places to 2
                        Text("Amount: \(String(format: "%.2f", expense.amount))")
                    }

                    Spacer()

                    Text(expense.isIncome ? "+$" : "-$")
                        .foregroundColor(expense.isIncome ? .green : .red)
                }
                .padding(8)
            }
        )
    }
}
