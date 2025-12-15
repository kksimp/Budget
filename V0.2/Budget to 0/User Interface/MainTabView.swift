//
//  MainTabView.swift
//  Budget to 0
//
//  Main tab navigation with 5 tabs
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var dataManager = EnhancedDataManager()
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Overview", systemImage: "chart.pie.fill")
                }
                .environmentObject(dataManager)
            
            BillsListView()
                .tabItem {
                    Label("Bills", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .environmentObject(dataManager)
            
            IncomeListView()
                .tabItem {
                    Label("Income", systemImage: "dollarsign.circle.fill")
                }
                .environmentObject(dataManager)
            
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .environmentObject(dataManager)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .environmentObject(dataManager)
        }
    }
}
