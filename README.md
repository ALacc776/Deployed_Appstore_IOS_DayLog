# DayLog

A minimal daily journaling app I built to track my day quickly. Built with SwiftUI, published on the App Store.

## Features

- **Instant Input** - Open the app and start typing, no extra steps
- **Quick Photo Capture** - Add photos from camera or gallery
- **Streak Tracking** - GitHub-style activity heatmap to visualize consistency
- **Search & Calendar** - Find and browse entries by date or content
- **Themes** - Light, Dark, System, and Sepia modes
- **Daily Reminders** - Optional notifications to maintain your streak
- **Local Storage** - All data stays on your device, optional encryption available
- **Data Export** - Export entries to clipboard, JSON, or text

## Design Philosophy

Unlike traditional journal apps, DayLog focuses on **speed and simplicity**:
- No complex forms or mandatory categories
- Just open and type - entries save automatically
- Goal: Log your day in 5 seconds or less

## Tech Stack

- **Language**: Swift
- **Framework**: SwiftUI
- **Architecture**: MVVM with Observer pattern
- **Persistence**: UserDefaults with Codable
- **Encryption**: CryptoKit (optional)
- **Threading**: Grand Central Dispatch for background operations
- **Minimum iOS**: 15.0+

## Project Structure

```
Jour/
├── Models/          # Data structures (JournalEntry, etc.)
├── Views/           # SwiftUI views (TodayView, CalendarView, etc.)
├── Components/      # Reusable UI components (Heatmap, StreakDisplay, etc.)
├── Managers/        # Business logic (JournalManager, ThemeManager, etc.)
├── Constants/       # App-wide constants
└── Extensions/      # Swift extensions
```

## How to Build

1. Clone the repo
2. Open `DayLog.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run (⌘R)

Unit tests and UI tests are included in `JourTests/` and `JourUITests/`.

## Key Features Implemented

**MVVM Architecture**: Separation of UI (Views) and business logic (Managers) using Observable pattern

**Custom Heatmap**: GitHub-style activity visualization with configurable date ranges

**Theme System**: Four themes (Light, Dark, System, Sepia) with persistent user preference

**Performance**: Background threading for I/O operations to keep UI responsive

**Privacy**: Local-only storage, optional encryption, no analytics or third-party services

## Support

Email: support.and@proton.me

---

Built to make daily logging fast enough that you'll actually do it every day.
