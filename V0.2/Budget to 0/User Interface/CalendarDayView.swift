//
//  CalendarDayView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/3/24.
//

import SwiftUI

struct CalendarDayView: View {
    let day: Date
    @ObservedObject var dataManager: DataManager

    var body: some View {
        VStack {
            Text(getDayText())
                .font(.headline)
                .foregroundColor(.primary)

            // Your logic to display bills for the day goes here
            Text("Bills: \(getBillsCount())")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .background(getBackgroundColor())
        .cornerRadius(8)
    }

    private func getDayText() -> String {
        // Your logic to get the day text (e.g., "01", "02", ...) goes here
        return ""
    }

    private func getBackgroundColor() -> Color {
        // Your logic to set the background color based on conditions (e.g., has bills or not) goes here
        return .clear
    }

    private func getBillsCount() -> Int {
        // Your logic to get the number of bills for the day goes here
        return 0
    }
}

