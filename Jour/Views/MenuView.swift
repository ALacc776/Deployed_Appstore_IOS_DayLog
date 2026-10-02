//
//  MenuView.swift
//  Jour
//
//  Created by andapple on 16/9/2025.
//

import SwiftUI

/// Menu view providing access to settings, stats, and app information
/// Simplified menu structure for better navigation
struct MenuView: View {
    // MARK: - Properties
    
    /// Reference to the journal manager
    @ObservedObject var journalManager: JournalManager
    
    /// Reference to the notification manager
    @StateObject private var notificationManager = NotificationManager()
    
    /// Reference to the theme manager
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - State
    
    /// Controls various sheet presentations
    @State private var showingDataExport = false
    @State private var showingDeleteWarning = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var showingCustomRangeCopy = false
    @State private var showingPrivacyPolicy = false
    @State private var showingSupport = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Reminders Section
                Section {
                    // Enable reminders toggle
                    Toggle(isOn: $notificationManager.notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Daily Reminder", systemImage: "bell.fill")
                                .foregroundColor(AppConstants.Colors.primaryText)
                            Text("Get reminded to log your day")
                                .font(.caption)
                                .foregroundColor(AppConstants.Colors.secondaryText)
                        }
                    }
                    
                    // Reminder time picker
                    if notificationManager.notificationsEnabled {
                        Picker("Reminder Time", selection: $notificationManager.reminderHour) {
                            ForEach(Array(stride(from: 6, through: 23, by: 1)), id: \.self) { hour in
                                Text(formatHour(hour))
                                    .tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if notificationManager.notificationsEnabled {
                        Text("You'll receive a reminder at \(formatHour(notificationManager.reminderHour)) to log your day")
                    }
                }
                
                // MARK: - Appearance Section
                Section {
                    Picker("Theme", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.rawValue)
                                        .foregroundColor(AppConstants.Colors.primaryText)
                                    Text(theme.description)
                                        .font(.caption)
                                        .foregroundColor(AppConstants.Colors.secondaryText)
                                }
                            } icon: {
                                Image(systemName: theme.icon)
                                    .foregroundColor(AppConstants.Colors.accentButton)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how DayLog looks. System matches your device settings.")
                }
                
                // MARK: - App Info Section
                Section {
                    // Version
                    HStack {
                        Label("Version", systemImage: "app.badge")
                            .foregroundColor(AppConstants.Colors.primaryText)
                        Spacer()
                        Text("1.1.0")
                            .foregroundColor(AppConstants.Colors.secondaryText)
                    }
                } header: {
                    Text("App Information")
                }
                
                // MARK: - Privacy & Support Section
                Section {
                    // Privacy Policy
                    Button(action: {
                        showingPrivacyPolicy = true
                    }) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                    
                    // Support
                    Button(action: {
                        showingSupport = true
                    }) {
                        Label("Help & Support", systemImage: "questionmark.circle.fill")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                } header: {
                    Text("Legal & Support")
                }
                
                // MARK: - Export to Clipboard Section
                Section {
                    Button(action: {
                        copyToClipboard(.today)
                    }) {
                        Label("Copy Today", systemImage: "doc.on.clipboard")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                    
                    Button(action: {
                        copyToClipboard(.week)
                    }) {
                        Label("Copy This Week", systemImage: "calendar.badge.clock")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                    
                    Button(action: {
                        copyToClipboard(.month)
                    }) {
                        Label("Copy This Month", systemImage: "calendar")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                    
                    Button(action: {
                        showingCustomRangeCopy = true
                    }) {
                        Label("Copy Custom Range...", systemImage: "calendar.badge.ellipsis")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                    
                    // Copy order toggle
                    Toggle(isOn: $journalManager.copyNewestFirst) {
                        Label("Newest First", systemImage: "arrow.down")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                    .tint(AppConstants.Colors.accentButton)
                } header: {
                    Text("Export to Clipboard")
                } footer: {
                    Text("Copy entries in bullet-list format. Toggle 'Newest First' to change the order.")
                }
                
                // MARK: - Data Management Section
                Section {
                    // Export data
                    Button(action: {
                        showingDataExport = true
                    }) {
                        Label("Backup & Export", systemImage: "icloud.and.arrow.up")
                            .foregroundColor(AppConstants.Colors.primaryText)
                    }
                } header: {
                    Text("Data Management")
                }
                
                // MARK: - Danger Zone (Hidden)
                Section {
                    // Delete all data - requires double confirmation
                    Button(action: {
                        showingDeleteWarning = true
                    }) {
                        Label("Delete All Data", systemImage: "exclamationmark.triangle")
                            .foregroundColor(AppConstants.Colors.errorColor)
                            .font(.footnote)
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("⚠️ This will permanently delete all your journal entries. Export your data first!")
                        .foregroundColor(AppConstants.Colors.errorColor)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppConstants.Colors.primaryBackground)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView(journalManager: journalManager)
        }
        .sheet(isPresented: $showingCustomRangeCopy) {
            CustomRangeCopyView(journalManager: journalManager)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingSupport) {
            SupportView()
        }
        .alert("⚠️ Export First!", isPresented: $showingDeleteWarning) {
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            Button("I Exported My Data", role: .destructive) {
                showingDeleteConfirmation = true
            }
        } message: {
            Text("Have you exported your data? This action will delete ALL \(journalManager.entries.count) entries permanently!")
        }
        .alert("Type DELETE to Confirm", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            TextField("Type DELETE", text: $deleteConfirmationText)
            Button("Delete Forever", role: .destructive) {
                if deleteConfirmationText.uppercased() == "DELETE" {
                    deleteAllData()
                    deleteConfirmationText = ""
                } else {
                    // Wrong text, show error
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    showingDeleteConfirmation = false
                    deleteConfirmationText = ""
                }
            }
        } message: {
            Text("This will permanently delete all \(journalManager.entries.count) journal entries. Type DELETE to confirm.")
        }
        .alert("Success", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Methods
    
    /// Copy range options
    enum CopyRange {
        case today, week, month
    }
    
    /// Copies entries to clipboard based on selected range
    private func copyToClipboard(_ range: CopyRange) {
        let entries: [JournalEntry]
        let rangeDescription: String
        
        switch range {
        case .today:
            entries = journalManager.getEntriesForDate(Date())
            rangeDescription = "today"
        case .week:
            entries = journalManager.getEntriesForWeek()
            rangeDescription = "this week"
        case .month:
            entries = journalManager.getEntriesForMonth()
            rangeDescription = "this month"
        }
        
        guard !entries.isEmpty else {
            alertMessage = "No entries found for \(rangeDescription)"
            showingAlert = true
            return
        }
        
        let formatted = journalManager.formatEntriesForClipboard(entries)
        UIPasteboard.general.string = formatted
        
        // Add haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
        
        // Show confirmation
        alertMessage = "Copied \(entries.count) \(entries.count == 1 ? "entry" : "entries") from \(rangeDescription) to clipboard"
        showingAlert = true
    }
    
    /// Deletes all journal data
    private func deleteAllData() {
        journalManager.entries.removeAll()
        journalManager.saveEntries()
        journalManager.updateStreak()
        
        // Show confirmation
        alertMessage = "All data has been deleted successfully."
        showingAlert = true
    }
    
    /// Formats hour (0-23) into readable 12-hour format
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        
        var components = DateComponents()
        components.hour = hour
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        
        return "\(hour):00"
    }
}

#Preview {
    MenuView(journalManager: JournalManager())
        .environmentObject(ThemeManager())
}

