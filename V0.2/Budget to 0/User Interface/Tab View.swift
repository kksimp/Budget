//
//  Tab View.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 1/5/24.
//

import SwiftUI

struct Tab_View: View {
    
    @ObservedObject var dataManager = DataManager()
    
    var body: some View {
        
        
        
        TabView {
            BillsView(dataManager: dataManager)
                .tag(1)
                .tabItem {
                    Image(systemName: "list.bullet.below.rectangle")
                    Text("Bills")
                }
            
            CalendarView(dataManager: dataManager)
                .tag(2)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            
            IncomeView(dataManager: dataManager)
                .tag(3)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Income")
                }
        }
        
        
    }
}

