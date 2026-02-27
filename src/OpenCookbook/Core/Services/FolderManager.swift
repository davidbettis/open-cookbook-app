//
//  FolderManager.swift
//  OpenCookbook
//
//  Created by Claude Code on 1/6/26.
//

import Foundation
import SwiftUI

/// Errors that can occur during folder management operations
enum FolderError: LocalizedError {
    case folderNotFound
    case permissionDenied
    case iCloudUnavailable
    case invalidBookmark
    case folderCreationFailed

    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "The selected folder could not be found. It may have been deleted or moved."
        case .permissionDenied:
            return "Permission denied to access the folder. Please check your iCloud Drive settings."
        case .iCloudUnavailable:
            return "iCloud Drive is not available. Please enable iCloud in Settings."
        case .invalidBookmark:
            return "The saved folder reference is invalid. Please select a folder again."
        case .folderCreationFailed:
            return "Could not create folder. Please check available storage and try again."
        }
    }
}

/// Manages the user's selected iCloud Drive folder for recipe storage
@Observable
final class FolderManager {

    // MARK: - Properties

    /// The currently selected folder URL
    var selectedFolderURL: URL?

    /// A user-friendly description of the selected folder location
    var selectedFolderDisplayName: String? {
        guard let url = selectedFolderURL else { return nil }

        let path = url.path

        // Check for iCloud Drive paths
        // iOS: ~/Library/Mobile Documents/com~apple~CloudDocs/
        // macOS: ~/Library/Mobile Documents/com~apple~CloudDocs/
        if path.contains("com~apple~CloudDocs") {
            // Extract the relative path after CloudDocs
            if let range = path.range(of: "com~apple~CloudDocs/") {
                let relativePath = String(path[range.upperBound...])
                if relativePath.isEmpty {
                    return "iCloud Drive"
                }
                return "iCloud Drive › \(relativePath)"
            } else if path.hasSuffix("com~apple~CloudDocs") {
                return "iCloud Drive"
            }
        }

        // Check for other Mobile Documents paths (third-party app containers)
        if path.contains("Mobile Documents") {
            return "iCloud Drive › \(url.lastPathComponent)"
        }

        // Local storage - show just the folder name with device indicator
        #if os(macOS)
        return "On My Mac › \(url.lastPathComponent)"
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "On My iPad › \(url.lastPathComponent)"
        } else {
            return "On My iPhone › \(url.lastPathComponent)"
        }
        #endif
    }

    /// Whether the selected folder is in iCloud Drive
    var isCloudFolder: Bool {
        guard let url = selectedFolderURL else { return false }
        let path = url.path
        return path.contains("com~apple~CloudDocs") || path.contains("Mobile Documents")
    }

    /// Bookmark data for security-scoped resource access
    var folderBookmark: Data?

    /// Whether this is the user's first launch (no folder selected yet)
    var isFirstLaunch: Bool {
        !hasSelectedFolder()
    }

    /// Whether the app is running on macOS (including iOS apps on Mac)
    private var isRunningOnMac: Bool {
        #if os(macOS)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    /// Whether we're currently accessing the security-scoped resource
    private var isAccessingSecurityScopedResource = false

    // MARK: - Initialization

    init() {
        // Load saved folder on initialization
        try? loadSavedFolder()
    }

    // MARK: - Public Methods

    /// Saves the selected folder URL with security-scoped bookmark
    /// - Parameter url: The folder URL to save
    /// - Throws: Error if bookmark creation or save fails
    func saveFolder(_ url: URL) throws {
        let bookmarkData: Data
        #if os(macOS)
        // Native macOS app
        bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        // iOS app - use different options when running on Mac vs iPhone/iPad
        if isRunningOnMac {
            // iOS app running on Mac needs security scope for proper file access
            bookmarkData = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } else {
            bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        #endif
        UserDefaults.standard.set(bookmarkData, forKey: "selectedFolderBookmark")
        self.selectedFolderURL = url
        self.folderBookmark = bookmarkData

        // Start accessing security-scoped resource to maintain access
        // after the document picker's defer block stops its access
        if url.startAccessingSecurityScopedResource() {
            isAccessingSecurityScopedResource = true
        }
    }

    /// Loads the previously saved folder URL from UserDefaults
    /// - Returns: The saved folder URL, or nil if none exists
    /// - Throws: Error if bookmark is invalid or folder is inaccessible
    @discardableResult
    func loadSavedFolder() throws -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "selectedFolderBookmark") else {
            return nil
        }

        do {
            var isStale = false
            let url: URL
            #if os(macOS)
            // Native macOS app
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #else
            // iOS app - use different options when running on Mac vs iPhone/iPad
            if isRunningOnMac {
                url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            } else {
                url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withoutUI,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            }
            #endif

            // Start accessing security-scoped resource (required on macOS)
            if url.startAccessingSecurityScopedResource() {
                isAccessingSecurityScopedResource = true
            }

            // Verify the folder still exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                // Folder no longer exists, clear the bookmark
                stopAccessingFolder()
                clearSavedFolder()
                throw FolderError.folderNotFound
            }

            // If bookmark is stale, re-save to refresh it
            if isStale {
                try saveFolder(url)
            }

            self.selectedFolderURL = url
            self.folderBookmark = bookmarkData
            return url
        } catch let error as FolderError {
            // Re-throw our custom errors
            throw error
        } catch {
            // Invalid bookmark data, clear it
            clearSavedFolder()
            throw FolderError.invalidBookmark
        }
    }

    /// Checks if a folder has been selected and saved
    /// - Returns: True if a folder is currently selected
    func hasSelectedFolder() -> Bool {
        // TODO: Implement check for saved bookmark
        // Will be implemented in Task 2.1
        return UserDefaults.standard.data(forKey: "selectedFolderBookmark") != nil
    }

    /// Clears the saved folder selection
    func clearSavedFolder() {
        stopAccessingFolder()
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        selectedFolderURL = nil
        folderBookmark = nil
    }

    /// Stops accessing the security-scoped resource
    func stopAccessingFolder() {
        if isAccessingSecurityScopedResource, let url = selectedFolderURL {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
        }
    }

    /// Creates a default local folder at Documents/OpenCookbook and persists the selection
    /// - Returns: The URL of the created folder
    /// - Throws: `FolderError.folderCreationFailed` if directory creation fails
    func createDefaultLocalFolder() throws -> URL {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FolderError.folderCreationFailed
        }
        let folderURL = documentsURL.appendingPathComponent("Recipes")
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            throw FolderError.folderCreationFailed
        }
        try saveFolder(folderURL)
        return folderURL
    }

    /// Creates a default iCloud folder at iCloud Drive/Documents/OpenCookbook and persists the selection
    /// - Returns: The URL of the created folder
    /// - Throws: `FolderError.iCloudUnavailable` if iCloud is not available,
    ///           `FolderError.folderCreationFailed` if directory creation fails
    func createDefaultiCloudFolder() throws -> URL {
        guard checkiCloudAvailability() else {
            throw FolderError.iCloudUnavailable
        }
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/Recipes") else {
            throw FolderError.folderCreationFailed
        }
        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        } catch {
            throw FolderError.folderCreationFailed
        }
        try saveFolder(containerURL)
        return containerURL
    }

    /// Checks if iCloud Drive is available
    /// - Returns: True if iCloud is available and user is signed in
    func checkiCloudAvailability() -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--force-icloud-available") {
            return true
        }
        #endif
        return FileManager.default.ubiquityIdentityToken != nil
    }
}
