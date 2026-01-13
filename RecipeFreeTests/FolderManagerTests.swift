//
//  FolderManagerTests.swift
//  RecipeFreeTests
//
//  Created by Claude Code on 1/6/26.
//

import Testing
import Foundation
@testable import RecipeFree

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

    // TODO: Add tests for saveFolder() once implemented (Task 2.1)
    // TODO: Add tests for loadSavedFolder() once implemented (Task 2.1)
    // TODO: Add tests for selectFolder() once implemented (Task 2.2)
}
