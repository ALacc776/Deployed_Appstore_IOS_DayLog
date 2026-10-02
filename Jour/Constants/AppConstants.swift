//
//  AppConstants.swift
//  Jour
//
//  Created by andapple on 16/9/2025.
//

import SwiftUI

/// Centralized constants for the Jour app
/// This file contains all app-wide constants including colors, spacing, and configuration values
enum AppConstants {
    
    // MARK: - App Information
    
    static let appName = "DayLog"
    static let appTagline = "Quick daily logging, simple and fast"
    
    // MARK: - Colors
    
    /// Professional minimalist color palette
    /// ✨ Now supports dark mode automatically
    enum Colors {
        // Background colors (adapt to light/dark mode)
        static let primaryBackground = Color(UIColor.systemGroupedBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemGroupedBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemGroupedBackground)
        
        // Primary gradient (subtle and professional)
        static let primaryGradient = [
            Color(red: 0.98, green: 0.98, blue: 0.99),
            Color(red: 0.95, green: 0.95, blue: 0.96)
        ]
        
        static let secondaryGradient = [
            Color(red: 0.97, green: 0.97, blue: 0.98),
            Color(red: 0.94, green: 0.94, blue: 0.95)
        ]
        
        // Button colors
        static let primaryButton = Color(red: 0.2, green: 0.2, blue: 0.25) // Dark gray for primary actions
        static let secondaryButton = Color(red: 0.9, green: 0.9, blue: 0.92) // Light gray for secondary actions
        static let accentButton = Color(red: 0.95, green: 0.6, blue: 0.3) // Warm orange accent
        
        // Button gradients
        static let buttonGradient = [
            Color(red: 0.2, green: 0.2, blue: 0.25),
            Color(red: 0.15, green: 0.15, blue: 0.2)
        ]
        
        static let streakGradient = [
            Color(red: 0.95, green: 0.6, blue: 0.3),
            Color(red: 0.9, green: 0.55, blue: 0.25)
        ]
        
        // Text colors (adapt to light/dark mode)
        static let primaryText = Color(UIColor.label)
        static let secondaryText = Color(UIColor.secondaryLabel)
        static let tertiaryText = Color(UIColor.tertiaryLabel)
        static let placeholderText = Color(UIColor.placeholderText)
        static let accentText = Color(red: 0.95, green: 0.6, blue: 0.3) // Orange for highlights
        
        // Card colors (adapt to light/dark mode)
        static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
        static let cardBorder = Color(UIColor.separator)
        static let cardShadow = Color(UIColor.systemGray).opacity(0.1)
        
        // Status colors (adapt to light/dark mode)
        static let successColor = Color(UIColor.systemGreen)
        static let warningColor = Color(UIColor.systemOrange)
        static let errorColor = Color(UIColor.systemRed)
        
        // MARK: - Playful Palette (Duolingo-inspired)
        static let duoGreen = Color(red: 0.35, green: 0.8, blue: 0.1) // Vibrant green
        static let duoGreenDark = Color(red: 0.25, green: 0.65, blue: 0.05) // Darker green for shadow
        
        static let duoBlue = Color(red: 0.1, green: 0.7, blue: 0.95) // Vibrant cyan/blue
        static let duoBlueDark = Color(red: 0.0, green: 0.55, blue: 0.8) // Darker blue for shadow
        
        static let duoYellow = Color(red: 1.0, green: 0.8, blue: 0.1) // Vibrant yellow
        static let duoYellowDark = Color(red: 0.9, green: 0.65, blue: 0.0) // Darker yellow for shadow
        
        static let duoPurple = Color(red: 0.6, green: 0.4, blue: 0.9) // Vibrant purple
        static let duoPurpleDark = Color(red: 0.45, green: 0.3, blue: 0.75) // Darker purple for shadow
        
        static let duoRed = Color(red: 0.95, green: 0.3, blue: 0.35) // Vibrant red/pink
        static let duoRedDark = Color(red: 0.8, green: 0.15, blue: 0.2) // Darker red for shadow
    }
    
    // MARK: - Spacing
    
    /// Consistent spacing values throughout the app
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let xxxxl: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    
    /// Consistent corner radius values
    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    // MARK: - Shadows
    
    /// Professional shadow configurations
    enum Shadows {
        static let card = (color: Color.black.opacity(0.04), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
        static let button = (color: Color.black.opacity(0.08), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
        static let streak = (color: Color.black.opacity(0.06), radius: CGFloat(10), x: CGFloat(0), y: CGFloat(3))
        static let elevated = (color: Color.black.opacity(0.1), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
    
    // MARK: - Animation
    
    /// Animation durations and configurations
    enum Animation {
        static let short: Double = 0.2
        static let medium: Double = 0.3
        static let long: Double = 0.5
        
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: medium)
    }
    
    // MARK: - Layout
    
    /// Layout configuration values
    enum Layout {
        static let categoryGridColumns = 2
        static let categoryGridSpacing: CGFloat = 12
        static let categoryButtonPadding: CGFloat = 16
        static let maxContentWidth: CGFloat = 600
    }
    
    // MARK: - UserDefaults Keys
    
    /// Keys for UserDefaults storage
    enum UserDefaultsKeys {
        static let journalEntries = "journal_entries"
        static let journalStreak = "journal_streak"
        static let copyNewestFirst = "copy_newest_first"
        static let iCloudBackupEnabled = "icloud_backup_enabled"
        static let iCloudLastBackupDate = "icloud_last_backup_date"
    }
    
    // MARK: - Date Formatting
    
    /// Date format strings
    enum DateFormats {
        static let storage = "yyyy-MM-dd"
        static let display = "EEEE, MMMM d, yyyy"
        static let time = "h:mm a"
    }
    
    // MARK: - Accessibility
    
    /// Accessibility identifiers and labels
    enum Accessibility {
        static let logDayButton = "Log Day Button"
        static let streakDisplay = "Streak Display"
        static let timelineView = "Timeline View"
        static let calendarView = "Calendar View"
        static let newEntryView = "New Entry View"
        static let categoryButton = "Category Button"
        static let entryRow = "Journal Entry Row"
    }
}
