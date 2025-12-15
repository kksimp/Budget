//
//  Budget_to_0App.swift
//  Budget to 0
//
//  Created by Kaleb Simpson on 1/4/24.
//

import SwiftUI

@main
struct Budget_to_0App: App {
    @StateObject private var dataManager = EnhancedDataManager()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
        }
    }
}
