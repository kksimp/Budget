//
//  CalendarGridView.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 2/3/24.
//

// CalendarGridView.swift
import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var dataManager: DataManager

    var body: some View {
        VStack {
            ForEach(getCalendarData(), id: \.self) { week in
                HStack {
                    ForEach(week, id: \.self) { day in
                        CalendarDayView(day: day, dataManager: dataManager)
                            .padding(8)
                    }
                }
            }
        }
        .padding()
    }

    private func getCalendarData() -> [[Date]] {
        // Your logic to generate the calendar data (weeks and days) goes here
        return [[]]
    }
}






