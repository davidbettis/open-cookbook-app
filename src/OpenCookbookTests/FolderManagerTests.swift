//
//  FolderManagerTests.swift
//  OpenCookbookTests
//
//  Created by Claude Code on 1/6/26.
//

import Testing
import Foundation
@testable import OpenCookbook

struct FolderManagerTests {

    @Test func initializesWithNoSelectedFolder() async throws {
        // Given: A fresh instance
        let manager = FolderManager()

        // Then: No folder should be selected initially
        #expect(manager.selectedFolderURL == nil)
        #expect(manager.folderBookmark == nil)
    }

    @Test func isFirstLaunchReturnsTrueWhenNoFolderSelected() async throws {
        // Given: A fresh instance with no saved folder
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        let manager = FolderManager()

        // Then: Should be first launch
        #expect(manager.isFirstLaunch == true)
    }

    @Test func hasSelectedFolderReturnsFalseInitially() async throws {
        // Given: A fresh instance with no saved folder
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        let manager = FolderManager()

        // Then: Should return false
        #expect(manager.hasSelectedFolder() == false)
    }

    @Test func clearSavedFolderRemovesBookmark() async throws {
        // Given: A manager instance
        let manager = FolderManager()

        // When: Clearing saved folder
        manager.clearSavedFolder()

        // Then: All folder data should be nil
        #expect(manager.selectedFolderURL == nil)
        #expect(manager.folderBookmark == nil)
        #expect(UserDefaults.standard.data(forKey: "selectedFolderBookmark") == nil)
    }

    @Test func createDefaultLocalFolderReturnsURLWithCorrectLastComponent() async throws {
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        let manager = FolderManager()

        let url = try manager.createDefaultLocalFolder()

        #expect(url.lastPathComponent == "Recipes")
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Cleanup
        manager.clearSavedFolder()
    }

    @Test func createDefaultLocalFolderIsIdempotent() async throws {
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        let manager = FolderManager()

        let url1 = try manager.createDefaultLocalFolder()
        let url2 = try manager.createDefaultLocalFolder()

        #expect(url1 == url2)

        // Cleanup
        manager.clearSavedFolder()
    }

    @Test func createDefaultiCloudFolderThrowsWhenICloudUnavailable() async throws {
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        let manager = FolderManager()

        // In the test/simulator environment, iCloud is typically unavailable
        if !manager.checkiCloudAvailability() {
            #expect(throws: FolderError.iCloudUnavailable) {
                try manager.createDefaultiCloudFolder()
            }
        }
    }
}
