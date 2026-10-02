//
//  ICloudBackupManager.swift
//  Jour
//
//  Created by andapple on 2/10/2026.
//

import Foundation
import UIKit

/// Keeps a readable copy of the journal in the user's iCloud Drive
/// (Files app → iCloud Drive → DayLog) so entries survive losing or resetting the phone.
///
/// Folder layout:
/// - `DayLog Journal.pdf` — the whole journal, readable anywhere
/// - `DayLog Backup.json` — the latest full backup, used by "Restore from iCloud"
/// - `Daily Snapshots/DayLog yyyy-MM-dd.json` — one backup per day, for rolling back
/// - `Photos/` — copies of every attached photo
///
/// Backups are written unencrypted because the app's encryption key never leaves this device;
/// an encrypted backup could not be restored on a new phone.
final class ICloudBackupManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ICloudBackupManager()

    // MARK: - Types

    enum Status: Equatable {
        case off
        case unavailable
        case idle
        case backingUp
        case failed(String)
    }

    enum BackupError: Error, LocalizedError {
        case iCloudUnavailable
        case noBackupFound

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                return "iCloud Drive isn't available. Sign in to iCloud and turn on iCloud Drive in Settings."
            case .noBackupFound:
                return "No DayLog backup was found in iCloud Drive."
            }
        }
    }

    // MARK: - Published Properties

    /// Whether automatic iCloud backup is turned on
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: AppConstants.UserDefaultsKeys.iCloudBackupEnabled)
            refreshStatus()
        }
    }

    /// Current backup state for the UI
    @Published private(set) var status: Status = .off

    /// When the last successful backup finished
    @Published private(set) var lastBackupDate: Date?

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard

    /// Serial queue for all iCloud file work
    private let queue = DispatchQueue(label: "com.jour.icloud-backup", qos: .utility)

    /// Debounced backup waiting to run
    private var pendingBackup: DispatchWorkItem?

    /// Seconds to wait after the last change before backing up
    private let debounceInterval: TimeInterval = 5

    /// How many daily snapshots to keep
    private let snapshotsToKeep = 60

    private let journalPDFName = "DayLog Journal.pdf"
    private let backupJSONName = "DayLog Backup.json"
    private let snapshotsFolderName = "Daily Snapshots"
    private let photosFolderName = "Photos"

    // MARK: - Initialization

    private init() {
        isEnabled = defaults.bool(forKey: AppConstants.UserDefaultsKeys.iCloudBackupEnabled)
        lastBackupDate = defaults.object(forKey: AppConstants.UserDefaultsKeys.iCloudLastBackupDate) as? Date
        refreshStatus()
    }

    // MARK: - Public Methods

    /// Whether the device is signed in to iCloud with iCloud Drive available
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Schedules a backup shortly after the journal changes; repeated calls are coalesced
    /// - Parameter journal: The journal to back up when the timer fires
    func scheduleBackup(for journal: JournalManager) {
        guard isEnabled else { return }

        pendingBackup?.cancel()
        let work = DispatchWorkItem { [weak self, weak journal] in
            guard let self = self, let journal = journal else { return }
            self.pendingBackup = nil
            self.backUp(entries: journal.entries, streak: journal.streak)
        }
        pendingBackup = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Runs a scheduled backup immediately (e.g. when the app moves to the background)
    func flushPendingBackup() {
        guard let work = pendingBackup else { return }
        work.cancel()
        pendingBackup = nil

        // Keep the app alive long enough to finish writing
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "iCloud Backup") {
            UIApplication.shared.endBackgroundTask(taskID)
        }
        work.perform()
        queue.async {
            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
    }

    /// Backs up the journal now
    /// - Parameters:
    ///   - entries: Entries to back up
    ///   - streak: Streak data to include
    ///   - completion: Called on the main thread with the result
    func backUp(entries: [JournalEntry], streak: JournalStreak, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard isEnabled else { return }

        // Never replace a good backup with an empty journal (e.g. after "Delete All Data")
        guard !entries.isEmpty else {
            completion?(.success(()))
            return
        }

        status = .backingUp

        queue.async { [weak self] in
            guard let self = self else { return }
            let result = Result { try self.writeBackup(entries: entries, streak: streak) }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    let now = Date()
                    self.lastBackupDate = now
                    self.defaults.set(now, forKey: AppConstants.UserDefaultsKeys.iCloudLastBackupDate)
                    self.status = self.isEnabled ? .idle : .off
                case .failure(let error):
                    self.status = .failed(error.localizedDescription)
                }
                completion?(result)
            }
        }
    }

    /// Reads the latest backup from iCloud Drive and copies its photos back onto the device
    /// - Parameter completion: Called on the main thread with the decoded backup
    func loadLatestBackup(completion: @escaping (Result<ExportData, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let result = Result<ExportData, Error> {
                guard let folder = self.backupFolderURL() else { throw BackupError.iCloudUnavailable }
                let url = folder.appendingPathComponent(self.backupJSONName)
                guard let data = try self.coordinatedRead(from: url) else { throw BackupError.noBackupFound }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let backup = try decoder.decode(ExportData.self, from: data)
                self.restorePhotos(for: backup.entries, from: folder)
                return backup
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Copies any photos missing on this device back from iCloud Drive
    /// Used after importing a backup file picked manually
    /// - Parameters:
    ///   - entries: Imported entries whose photos should be restored
    ///   - completion: Called on the main thread when finished
    func restorePhotos(for entries: [JournalEntry], completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            if let self = self, let folder = self.backupFolderURL() {
                self.restorePhotos(for: entries, from: folder)
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    // MARK: - Private Methods

    /// Updates `status` to reflect the toggle and iCloud availability
    private func refreshStatus() {
        if !isEnabled {
            status = .off
        } else if !isICloudAvailable {
            status = .unavailable
        } else if status == .off || status == .unavailable {
            status = .idle
        }
    }

    /// The visible `Documents` folder inside the app's iCloud container
    /// Must be called off the main thread; the first lookup can be slow
    private func backupFolderURL() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let folder = container.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Writes the PDF, JSON backup, daily snapshot, and photos to iCloud Drive
    private func writeBackup(entries: [JournalEntry], streak: JournalStreak) throws {
        guard let folder = backupFolderURL() else { throw BackupError.iCloudUnavailable }
        let fileManager = FileManager.default

        // JSON backup (same format as manual JSON export, so either can be imported)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let backup = ExportData(entries: entries, streak: streak, exportDate: Date(), appVersion: Self.appVersion)
        let json = try encoder.encode(backup)
        try coordinatedWrite(json, to: folder.appendingPathComponent(backupJSONName))

        // One snapshot per day; later backups on the same day overwrite it
        let snapshots = folder.appendingPathComponent(snapshotsFolderName, isDirectory: true)
        try fileManager.createDirectory(at: snapshots, withIntermediateDirectories: true)
        let snapshotName = "DayLog \(Date().storageFormat).json"
        try coordinatedWrite(json, to: snapshots.appendingPathComponent(snapshotName))
        pruneSnapshots(in: snapshots)

        // Readable PDF of the whole journal
        let pdf = JournalDocumentRenderer.pdfData(entries: entries, streak: streak)
        try coordinatedWrite(pdf, to: folder.appendingPathComponent(journalPDFName))

        // Photos are copied once; filenames are unique UUIDs so existing copies never change
        let photos = folder.appendingPathComponent(photosFolderName, isDirectory: true)
        try fileManager.createDirectory(at: photos, withIntermediateDirectories: true)
        for filename in entries.compactMap(\.photoFilename) {
            let destination = photos.appendingPathComponent(filename)
            let source = PhotoManager.shared.photoURL(filename: filename)
            guard !fileManager.fileExists(atPath: destination.path),
                  let data = try? Data(contentsOf: source) else { continue }
            try coordinatedWrite(data, to: destination)
        }
    }

    /// Deletes the oldest daily snapshots beyond `snapshotsToKeep`
    private func pruneSnapshots(in folder: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        // Names embed yyyy-MM-dd, so alphabetical order is chronological
        let snapshots = files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in snapshots.dropLast(snapshotsToKeep) {
            var coordinatorError: NSError?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { target in
                try? FileManager.default.removeItem(at: target)
            }
        }
    }

    /// Copies photos referenced by `entries` from the backup folder if they're missing locally
    private func restorePhotos(for entries: [JournalEntry], from folder: URL) {
        let photos = folder.appendingPathComponent(photosFolderName, isDirectory: true)
        for filename in entries.compactMap(\.photoFilename) {
            let destination = PhotoManager.shared.photoURL(filename: filename)
            guard !FileManager.default.fileExists(atPath: destination.path),
                  let data = try? coordinatedRead(from: photos.appendingPathComponent(filename)) else { continue }
            try? data.write(to: destination, options: .atomic)
        }
    }

    /// Writes data through NSFileCoordinator so iCloud sees a consistent file
    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { target in
            do {
                try data.write(to: target, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = coordinatorError ?? writeError { throw error }
    }

    /// Reads data through NSFileCoordinator, which downloads the file from iCloud if needed
    /// - Returns: The file contents, or nil if the file doesn't exist
    private func coordinatedRead(from url: URL) throws -> Data? {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)

        var coordinatorError: NSError?
        var readResult: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { target in
            readResult = Result { try Data(contentsOf: target) }
        }
        if let error = coordinatorError { throw error }

        switch readResult {
        case .success(let data):
            return data
        case .failure(let error as CocoaError) where error.code == .fileReadNoSuchFile:
            return nil
        case .failure(let error):
            throw error
        case nil:
            return nil
        }
    }

    /// The app's marketing version, stored in backups for reference
    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
