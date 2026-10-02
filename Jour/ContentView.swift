//
//  ContentView.swift
//  Jour
//
//  Created by andapple on 16/9/2025.
//

import SwiftUI

/// Main view of the app with simplified 3-tab navigation
/// Provides instant access to today's log, calendar, and settings
struct ContentView: View {
    // MARK: - State Properties
    
    /// Manages all journal data and business logic
    @StateObject private var journalManager = JournalManager()
    
    /// Controls which tab is selected
    @State private var selectedTab = 0

    /// Tracks foreground/background so pending iCloud backups finish before the app suspends
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Today Tab (Main screen)
            TodayView(journalManager: journalManager)
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)
            
            // MARK: - Calendar Tab
            CalendarView(journalManager: journalManager)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                ICloudBackupManager.shared.flushPendingBackup()
            }
        }
    }
}

#Preview {
    ContentView()
}
