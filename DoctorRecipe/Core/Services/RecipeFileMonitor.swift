//
//  RecipeFileMonitor.swift
//  DoctorRecipe
//
//  Scans a folder for recipe files
//

import Foundation

/// Scans a folder for .md recipe files
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

    // MARK: - Public Methods

    /// Start monitoring a folder (just does initial scan)
    /// - Parameter folder: The folder URL to scan
    func startMonitoring(folder: URL) {
        monitoredFolder = folder
        scanFolder()
    }

    /// Stop monitoring the current folder
    func stopMonitoring() {
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
            print("Error scanning folder: \(error.localizedDescription)")
            fileURLs = []
            return []
        }
    }
}
