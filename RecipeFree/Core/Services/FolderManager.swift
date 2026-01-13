//
//  FolderManager.swift
//  RecipeFree
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
        }
    }
}

/// Manages the user's selected iCloud Drive folder for recipe storage
@Observable
final class FolderManager {

    // MARK: - Properties

    /// The currently selected folder URL
    var selectedFolderURL: URL?

    /// Bookmark data for security-scoped resource access
    var folderBookmark: Data?

    /// Whether this is the user's first launch (no folder selected yet)
    var isFirstLaunch: Bool {
        !hasSelectedFolder()
    }

    // MARK: - Initialization

    init() {
        // Load saved folder on initialization
        try? loadSavedFolder()
    }

    // MARK: - Public Methods

    /// Presents folder picker and returns selected folder URL
    /// - Returns: The selected folder URL
    /// - Throws: Error if folder selection fails or is cancelled
    func selectFolder() async throws -> URL {
        // TODO: Implement folder picker presentation
        // Will be implemented in Task 2.2
        fatalError("selectFolder() not yet implemented")
    }

    /// Saves the selected folder URL with security-scoped bookmark
    /// - Parameter url: The folder URL to save
    /// - Throws: Error if bookmark creation or save fails
    func saveFolder(_ url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: "selectedFolderBookmark")
        self.selectedFolderURL = url
        self.folderBookmark = bookmarkData
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
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Verify the folder still exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                // Folder no longer exists, clear the bookmark
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
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        selectedFolderURL = nil
        folderBookmark = nil
    }

    /// Checks if iCloud Drive is available
    /// - Returns: True if iCloud is available and user is signed in
    func checkiCloudAvailability() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
}
