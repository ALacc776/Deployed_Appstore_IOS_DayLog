//
//  JournalManager.swift
//  Jour
//
//  Created by andapple on 16/9/2025.
//

import Foundation
import SwiftUI

/// Manages all journal entries and streak data for the app
/// This class handles data persistence, streak calculations, and provides methods for CRUD operations
class JournalManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Array of all journal entries, sorted by date (newest first)
    @Published var entries: [JournalEntry] = []
    
    /// Current streak information including current and longest streaks
    @Published var streak: JournalStreak = JournalStreak()
    
    /// Loading state for initial data fetch
    @Published var isLoading = true
    
    /// Whether to copy entries to clipboard with newest first (default: true)
    @Published var copyNewestFirst: Bool = true {
        didSet {
            userDefaults.set(copyNewestFirst, forKey: AppConstants.UserDefaultsKeys.copyNewestFirst)
        }
    }
    
    // MARK: - Private Properties
    
    /// UserDefaults instance for data persistence
    private let userDefaults = UserDefaults.standard
    
    /// Privacy manager for encryption and privacy controls
    private let privacyManager = PrivacyManager()
    
    /// Background queue for persistence operations to prevent UI freezing
    private let persistenceQueue = DispatchQueue(label: "com.jour.persistence", qos: .background)    
    // MARK: - Constants
    
    /// Key for storing journal entries in UserDefaults
    private let entriesKey = AppConstants.UserDefaultsKeys.journalEntries
    
    /// Key for storing streak data in UserDefaults
    private let streakKey = AppConstants.UserDefaultsKeys.journalStreak
    
    // MARK: - Initialization
    
    /// Initializes the JournalManager and loads existing data
    init() {
        // Load copy order preference (default to newest first)
        if userDefaults.object(forKey: AppConstants.UserDefaultsKeys.copyNewestFirst) == nil {
            // First launch - set default to true
            self.copyNewestFirst = true
            userDefaults.set(true, forKey: AppConstants.UserDefaultsKeys.copyNewestFirst)
        } else {
            // Load saved preference
            self.copyNewestFirst = userDefaults.bool(forKey: AppConstants.UserDefaultsKeys.copyNewestFirst)
        }
        
        // Load data asynchronously to prevent blocking app launch
        persistenceQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Core data load
            self.loadEntries()
            self.loadStreak()
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.updateStreak()
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Saves a new journal entry and updates the streak
    /// - Parameter entry: The journal entry to save
    func saveEntry(_ entry: JournalEntry) {
        entries.append(entry)
        entries.sort { $0.date > $1.date } // Sort by date, newest first
        saveEntries()
        updateStreak()
        
        // Add haptic feedback for successful save
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    /// Adds entries from a backup, skipping any that already exist (matched by ID)
    /// - Parameter newEntries: Entries to import
    /// - Returns: Number of entries actually added
    @discardableResult
    func importEntries(_ newEntries: [JournalEntry]) -> Int {
        let existingIDs = Set(entries.map(\.id))
        let additions = newEntries.filter { !existingIDs.contains($0.id) }
        guard !additions.isEmpty else { return 0 }

        entries.append(contentsOf: additions)
        entries.sort { $0.date > $1.date }
        saveEntries()
        updateStreak()
        return additions.count
    }

    /// Updates an existing journal entry
    /// - Parameters:
    ///   - entry: The entry to update (matched by ID)
    ///   - content: The new content text
    ///   - category: The new category (optional)
    ///   - time: The new time string (optional)
    func updateEntry(_ entry: JournalEntry, content: String, category: String?, time: String?) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            // Create updated entry with the same ID, date, photo, and location preserved
            let updatedEntry = JournalEntry(
                content: content,
                category: category,
                date: entry.date,
                time: time,
                photoFilename: entry.photoFilename,
                location: entry.location,
                id: entry.id
            )
            entries[index] = updatedEntry
            saveEntries()
            
            // Add haptic feedback for update
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
    
    /// Deletes a journal entry and updates the streak
    /// - Parameter entry: The journal entry to delete
    func deleteEntry(_ entry: JournalEntry) {
        // Delete associated photo if exists
        if let photoFilename = entry.photoFilename {
            PhotoManager.shared.deletePhoto(filename: photoFilename)
        }
        
        entries.removeAll { $0.id == entry.id }
        saveEntries()
        updateStreak()
        
        // Add haptic feedback for deletion
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Returns all journal entries for a specific date
    /// - Parameter date: The date to filter entries by
    /// - Returns: Array of journal entries for the specified date
    func getEntriesForDate(_ date: Date) -> [JournalEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Checks if there is any entry for a specific date
    /// - Parameter date: The date to check
    /// - Returns: True if an entry exists, false otherwise
    func hasEntry(on date: Date) -> Bool {
        !getEntriesForDate(date).isEmpty
    }
    
    /// Returns all entries for the current week
    /// - Returns: Array of journal entries from start of week to now
    func getEntriesForWeek() -> [JournalEntry] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }
        
        return entries.filter { $0.date >= weekStart }
            .sorted { $0.date < $1.date }
    }
    
    /// Returns all entries for the current month
    /// - Returns: Array of journal entries from start of month to now
    func getEntriesForMonth() -> [JournalEntry] {
        let calendar = Calendar.current
        let today = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return []
        }
        
        return entries.filter { $0.date >= monthStart }
            .sorted { $0.date < $1.date }
    }
    
    /// Returns all entries within a custom date range
    /// - Parameters:
    ///   - startDate: Start of the range
    ///   - endDate: End of the range
    /// - Returns: Array of journal entries within the range
    func getEntriesInRange(from startDate: Date, to endDate: Date) -> [JournalEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate).addingTimeInterval(86400) // End of day
        
        return entries.filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }
    
    /// Formats entries for clipboard export in bullet-list format
    /// - Parameter entries: Entries to format
    /// - Returns: Formatted string ready for clipboard
    func formatEntriesForClipboard(_ entries: [JournalEntry]) -> String {
        guard !entries.isEmpty else { return "" }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        
        // Sort dates based on user preference
        let sortedDates = copyNewestFirst ? grouped.keys.sorted(by: >) : grouped.keys.sorted()
        var output = ""
        
        for date in sortedDates {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let dateString = dateFormatter.string(from: date)
            
            output += "\(dateString):\n"
            
            // Sort entries within each day based on user preference
            if let dayEntries = grouped[date]?.sorted(by: { copyNewestFirst ? $0.date > $1.date : $0.date < $1.date }) {
                for entry in dayEntries {
                    let text = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.isEmpty, entry.photoFilename != nil {
                        output += "- 📷 [Photo]\n"
                    } else {
                        output += "- \(entry.content)\n"
                    }
                }
            }
            
            output += "\n"
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Private Methods
    
    /// Updates the current streak based on journal entries
    /// Calculates consecutive days of journaling and updates both current and longest streaks
    func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get all unique dates with entries, sorted by date (optimized)
        let entryDates = Set(entries.map { calendar.startOfDay(for: $0.date) })
        
        // If no entries exist, reset streak
        guard !entryDates.isEmpty else {
            streak.current = 0
            saveStreak()
            return
        }
        
        // Check if we have an entry today or yesterday
        let hasEntryToday = entryDates.contains(today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            streak.current = 0
            saveStreak()
            return
        }
        let hasEntryYesterday = entryDates.contains(yesterday)
        
        if hasEntryToday {
            // Calculate current streak from today backwards (optimized)
            var currentStreak = 0
            var checkDate = today
            
            while entryDates.contains(checkDate) {
                currentStreak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDate
            }
            
            streak.current = currentStreak
            streak.longest = max(streak.longest, currentStreak)
            streak.lastEntryDate = formatDate(today)
        } else if hasEntryYesterday {
            // If no entry today but had entry yesterday, streak continues
            // Recalculate to ensure accuracy (don't rely on cache)
            var currentStreak = 0
            var checkDate = yesterday
            
            while entryDates.contains(checkDate) {
                currentStreak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDate
            }
            streak.current = currentStreak
        } else {
            // No entry today or yesterday, streak resets
            streak.current = 0
        }
        
        saveStreak()
    }
    
    /// Formats a date to a string for storage
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string in "yyyy-MM-dd" format
    private func formatDate(_ date: Date) -> String {
        date.storageFormat
    }
    
    /// Saves journal entries to UserDefaults with encryption
    /// Encodes the entries array to JSON and stores it persistently
    /// Saves journal entries to UserDefaults with encryption
    /// Encodes the entries array to JSON and stores it persistently
    func saveEntries() {
        // Create a snapshot of entries to save
        let entriesSnapshot = entries

        // Mirror the change to iCloud Drive (debounced, no-op when backup is off)
        ICloudBackupManager.shared.scheduleBackup(for: self)

        persistenceQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let encoded = try encoder.encode(entriesSnapshot)
                
                // Encrypt the data if privacy manager is enabled
                if let encryptedData = self.privacyManager.encryptText(String(data: encoded, encoding: .utf8) ?? "") {
                    self.userDefaults.set(encryptedData, forKey: self.entriesKey)
                } else {
                    // Fallback to unencrypted storage
                    self.userDefaults.set(encoded, forKey: self.entriesKey)
                }
            } catch {
                print("Failed to save journal entries: \(error.localizedDescription)")
            }
        }
    }
    
    /// Loads journal entries from UserDefaults with decryption
    /// Decodes the stored JSON data back into the entries array
    /// Loads journal entries from UserDefaults with decryption
    /// Decodes the stored JSON data back into the entries array
    /// Loads journal entries from UserDefaults with decryption
    /// Decodes the stored JSON data back into the entries array
    private func loadEntries() {
        guard let data = userDefaults.data(forKey: entriesKey) else { return }
        
        do {
            var jsonData: Data
            
            // Try to decrypt first
            if let decryptedText = self.privacyManager.decryptText(data),
               let decryptedData = decryptedText.data(using: .utf8) {
                jsonData = decryptedData
            } else {
                // Fallback to unencrypted data
                jsonData = data
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([JournalEntry].self, from: jsonData)
            
            DispatchQueue.main.async {
                self.entries = decoded
            }
        } catch {
            print("Failed to load journal entries: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.entries = []
            }
        }
    }
    
    /// Saves streak data to UserDefaults
    /// Encodes the streak object to JSON and stores it persistently
    private func saveStreak() {
        do {
            let encoded = try JSONEncoder().encode(streak)
            userDefaults.set(encoded, forKey: streakKey)
        } catch {
            print("Failed to save streak data: \(error.localizedDescription)")
        }
    }
    
    /// Loads streak data from UserDefaults
    /// Decodes the stored JSON data back into the streak object
    private func loadStreak() {
        guard let data = userDefaults.data(forKey: streakKey) else { return }
        
        do {
            let decoded = try JSONDecoder().decode(JournalStreak.self, from: data)
            DispatchQueue.main.async {
                self.streak = decoded
            }
        } catch {
            print("Failed to load streak data: \(error.localizedDescription)")
        }
    }
}
