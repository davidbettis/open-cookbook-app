//
//  RecipeStoreTests.swift
//  DoctorRecipeTests
//
//  Unit tests for RecipeStore
//

import Testing
import Foundation
@testable import DoctorRecipe

@Suite("RecipeStore Tests")
@MainActor
struct RecipeStoreTests {

    // MARK: - Helper Methods

    /// Create a temporary test directory with recipe files
    func createTestDirectory(with recipes: [String: String]) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecipeStoreTests_\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for (filename, content) in recipes {
            let fileURL = tempDir.appendingPathComponent(filename)
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return tempDir
    }

    /// Clean up test directory
    func cleanupTestDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Loading Tests

    @Test("Load recipes from folder")
    func loadRecipesFromFolder() async throws {
        let recipes = [
            "cookies.md": """
            # Chocolate Chip Cookies

            Delicious cookies.

            *dessert, baking*

            **yields: 24 cookies**
            """,
            "pasta.md": """
            # Pasta Carbonara

            Classic Italian dish.

            *dinner, italian*
            """
        ]

        let testDir = createTestDirectory(with: recipes)
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()
        store.loadRecipes(from: testDir)

        // Verify recipes were loaded
        #expect(store.recipes.count == 2)
        #expect(store.parseErrors.isEmpty)

        // Verify recipes are sorted by title
        #expect(store.recipes[0].title == "Chocolate Chip Cookies")
        #expect(store.recipes[1].title == "Pasta Carbonara")

        // Verify metadata was parsed correctly
        let cookies = store.recipes[0]
        #expect(cookies.tags == ["dessert", "baking"])
        #expect(cookies.yields == ["24 cookies"])
        #expect(cookies.description == "Delicious cookies.")
    }

    @Test("Handle empty folder")
    func handleEmptyFolder() async throws {
        let testDir = createTestDirectory(with: [:])
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()
        store.loadRecipes(from: testDir)

        #expect(store.recipes.isEmpty)
        #expect(store.parseErrors.isEmpty)
    }

    @Test("Handle invalid recipe files")
    func handleInvalidRecipeFiles() async throws {
        let recipes = [
            "valid.md": """
            # Valid Recipe

            This is valid.
            """,
            "invalid.md": """
            This file has no title!

            Just some content.
            """
        ]

        let testDir = createTestDirectory(with: recipes)
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()
        store.loadRecipes(from: testDir)

        // Verify valid recipe was loaded
        #expect(store.recipes.count == 1)
        #expect(store.recipes[0].title == "Valid Recipe")

        // Verify invalid recipe is in errors
        #expect(store.parseErrors.count == 1)
    }

    // MARK: - Refresh Tests

    @Test("Refresh recipes updates list")
    func refreshRecipesUpdatesList() async throws {
        let recipes = [
            "recipe1.md": """
            # Recipe One

            First recipe.
            """
        ]

        let testDir = createTestDirectory(with: recipes)
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()
        store.loadRecipes(from: testDir)

        #expect(store.recipes.count == 1)

        // Add another recipe
        let newRecipe = """
        # Recipe Two

        Second recipe.
        """
        let newFileURL = testDir.appendingPathComponent("recipe2.md")
        try newRecipe.write(to: newFileURL, atomically: true, encoding: .utf8)

        // Refresh
        store.refreshRecipes()

        // Verify both recipes are now loaded
        #expect(store.recipes.count == 2)
    }

    // MARK: - Caching Tests

    @Test("Caching prevents re-parsing unchanged files")
    func cachingPreventsReparsing() async throws {
        let recipes = [
            "recipe.md": """
            # Test Recipe

            A test recipe for caching.
            """
        ]

        let testDir = createTestDirectory(with: recipes)
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()

        // First load
        store.loadRecipes(from: testDir)
        let firstLoad = store.recipes[0]

        // Second load without changes
        store.refreshRecipes()
        let secondLoad = store.recipes[0]

        // Verify same recipe instance (from cache)
        #expect(firstLoad.id == secondLoad.id)
        #expect(firstLoad.fileModifiedDate == secondLoad.fileModifiedDate)
    }

    @Test("Cache invalidates when file modified")
    func cacheInvalidatesWhenModified() async throws {
        let recipes = [
            "recipe.md": """
            # Original Title

            Original content.
            """
        ]

        let testDir = createTestDirectory(with: recipes)
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()

        // First load
        store.loadRecipes(from: testDir)
        #expect(store.recipes[0].title == "Original Title")

        // Wait a bit to ensure modification date changes
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Modify the file
        let modifiedContent = """
        # Modified Title

        Modified content.
        """
        let fileURL = testDir.appendingPathComponent("recipe.md")
        try modifiedContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Refresh
         store.refreshRecipes()

        // Verify new content was parsed
        #expect(store.recipes[0].title == "Modified Title")
        #expect(store.recipes[0].description == "Modified content.")
    }

    // MARK: - Reset Tests

    @Test("Reset clears all data")
    func resetClearsAllData() async throws {
        let recipes = [
            "recipe.md": """
            # Test Recipe

            Content.
            """
        ]

        let testDir = createTestDirectory(with: recipes)
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()
        store.loadRecipes(from: testDir)

        #expect(!store.recipes.isEmpty)

        // Reset
        store.reset()

        // Verify everything is cleared
        #expect(store.recipes.isEmpty)
        #expect(store.parseErrors.isEmpty)
    }

    // MARK: - Loading State Tests

    @Test("Loading state updates correctly")
    func loadingStateUpdates() async throws {
        let recipes = [
            "recipe.md": """
            # Test Recipe

            Content.
            """
        ]

        let testDir = createTestDirectory(with: recipes)
        defer { cleanupTestDirectory(testDir) }

        let store = RecipeStore()

        #expect(store.isLoading == false)

        // Start loading (run in task to capture loading state)
        let loadingTask = Task {
            store.loadRecipes(from: testDir)
        }

        // Loading state might be true briefly, but we can't reliably test this
        // due to async timing. Just verify it's false after completion.

        await loadingTask.value

        #expect(store.isLoading == false)
        #expect(!store.recipes.isEmpty)
    }
}
