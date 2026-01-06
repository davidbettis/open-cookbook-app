//
//  FolderManager.swift
//  DoctorRecipe
//
//  Created by Claude Code on 1/6/26.
//

import Foundation
import SwiftUI

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

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        // If bookmark is stale, re-save to refresh it
        if isStale {
            try saveFolder(url)
        }

        self.selectedFolderURL = url
        self.folderBookmark = bookmarkData
        return url
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
}
