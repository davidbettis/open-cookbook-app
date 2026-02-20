//
//  RecipeFileMonitor.swift
//  OpenCookbook
//
//  Monitors a folder for recipe file changes using DispatchSource
//

import Foundation

/// Monitors a folder for .md recipe files and notifies on changes
@MainActor
@Observable
class RecipeFileMonitor {

    // MARK: - Properties

    /// List of .md file URLs in the monitored folder
    private(set) var fileURLs: [URL] = []

    /// Currently monitored folder URL
    private(set) var monitoredFolder: URL?

    /// Callback for file changes
    var onFilesChanged: (() -> Void)?

    /// File descriptor for the monitored folder
    private var folderDescriptor: Int32 = -1

    /// DispatchSource for folder monitoring
    private var folderSource: DispatchSourceFileSystemObject?

    /// Debounce task for batching file system events
    private var debounceTask: Task<Void, Never>?

    /// Debounce interval in milliseconds
    private let debounceInterval: UInt64 = 500

    // MARK: - Public Methods

    /// Start monitoring a folder for changes
    /// - Parameter folder: The folder URL to monitor
    func startMonitoring(folder: URL) {
        // Stop any existing monitoring
        stopMonitoring()

        monitoredFolder = folder
        scanFolder()

        // Set up file system monitoring
        setupFolderMonitoring(folder: folder)
    }

    /// Stop monitoring the current folder
    func stopMonitoring() {
        // Cancel any pending debounce
        debounceTask?.cancel()
        debounceTask = nil

        // Stop the dispatch source
        folderSource?.cancel()
        folderSource = nil

        // Close the file descriptor
        if folderDescriptor >= 0 {
            close(folderDescriptor)
            folderDescriptor = -1
        }

        monitoredFolder = nil
        fileURLs = []
    }

    /// Manually scan the folder for .md files
    /// - Returns: Array of .md file URLs
    @discardableResult
    func scanFolder() -> [URL] {
        guard let folder = monitoredFolder else {
            fileURLs = []
            return []
        }

        return folder.withSecurityScopedAccess {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )

                // Filter for .md files and sort by name
                fileURLs = contents
                    .filter { $0.pathExtension.lowercased() == "md" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }

                return fileURLs
            } catch {
                #if DEBUG
                print("[RecipeFileMonitor] Error scanning folder: \(error.localizedDescription)")
                #endif
                fileURLs = []
                return []
            }
        }
    }

    // MARK: - Private Methods

    /// Set up DispatchSource monitoring for the folder
    private func setupFolderMonitoring(folder: URL) {
        // Start accessing security-scoped resource for monitoring
        let didStartAccess = folder.startAccessingSecurityScopedResource()

        // Open the folder for monitoring
        folderDescriptor = open(folder.path, O_EVTONLY)

        if didStartAccess {
            folder.stopAccessingSecurityScopedResource()
        }

        guard folderDescriptor >= 0 else {
            #if DEBUG
            print("[RecipeFileMonitor] Failed to open folder for monitoring")
            #endif
            return
        }

        // Create dispatch source for file system events
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: folderDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.handleFolderChange()
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.folderDescriptor >= 0 {
                close(self.folderDescriptor)
                self.folderDescriptor = -1
            }
        }

        source.resume()
        folderSource = source
    }

    /// Handle folder change events with debouncing
    private func handleFolderChange() {
        // Cancel any existing debounce task
        debounceTask?.cancel()

        // Create new debounce task
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: (self?.debounceInterval ?? 500) * 1_000_000)
            } catch {
                // Task was cancelled
                return
            }

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                self?.onFilesChanged?()
            }
        }
    }

}
