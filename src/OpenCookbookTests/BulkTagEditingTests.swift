//
//  BulkTagEditingTests.swift
//  OpenCookbookTests
//
//  Unit tests for bulk tag editing operations
//

import Testing
import Foundation
import RecipeMD
@testable import OpenCookbook

@Suite("Bulk Tag Editing Tests", .serialized)
@MainActor
struct BulkTagEditingTests {

    // MARK: - Helper Methods

    func createTestDirectory(with recipes: [String: String]) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BulkTagTests_\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for (filename, content) in recipes {
            let fileURL = tempDir.appendingPathComponent(filename)
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return tempDir
    }

    func cleanupTestDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func makeRecipeFile(title: String, tags: [String], filePath: URL? = nil) -> RecipeFile {
        RecipeFile(
            filePath: filePath ?? URL(fileURLWithPath: "/tmp/\(title.lowercased().replacingOccurrences(of: " ", with: "-")).md"),
            recipe: Recipe(
                title: title,
                tags: tags,
                ingredientGroups: [IngredientGroup(ingredients: [Ingredient(name: "ingredient")])]
            )
        )
    }

    // MARK: - RecipeStore Bulk Add Tests

    @Test("Bulk add tags to multiple recipes")
    func bulkAddTags() async throws {
        let recipes = [
            "pasta.md": "# Pasta\n\n*italian*\n\n---\n\n- pasta\n\n---\n",
            "soup.md": "# Soup\n\n*comfort*\n\n---\n\n- broth\n\n---\n",
            "salad.md": "# Salad\n\n*healthy*\n\n---\n\n- lettuce\n\n---\n"
        ]

        let testDir = createTestDirectory(with: recipes)
        let store = RecipeStore()
        defer {
            store.reset()
            cleanupTestDirectory(testDir)
        }

        await store.loadRecipes(from: testDir)
        #expect(store.recipes.count == 3)

        let allIDs = Set(store.recipes.map(\.id))
        let result = store.bulkAddTags(["dinner", "quick"], to: allIDs)

        #expect(result.successCount == 3)
        #expect(result.failureCount == 0)

        for recipe in store.recipes {
            #expect(recipe.tags.contains("dinner"))
            #expect(recipe.tags.contains("quick"))
        }
    }

    @Test("Bulk add preserves existing tags")
    func bulkAddPreservesExistingTags() async throws {
        let recipes = [
            "pasta.md": "# Pasta\n\n*italian, dinner*\n\n---\n\n- pasta\n\n---\n"
        ]

        let testDir = createTestDirectory(with: recipes)
        let store = RecipeStore()
        defer {
            store.reset()
            cleanupTestDirectory(testDir)
        }

        await store.loadRecipes(from: testDir)
        let recipeID = store.recipes[0].id

        let result = store.bulkAddTags(["vegetarian"], to: [recipeID])

        #expect(result.successCount == 1)
        let updatedTags = store.recipes[0].tags
        #expect(updatedTags.contains("italian"))
        #expect(updatedTags.contains("dinner"))
        #expect(updatedTags.contains("vegetarian"))
    }

    @Test("Bulk add does not duplicate existing tags")
    func bulkAddNoDuplicates() async throws {
        let recipes = [
            "pasta.md": "# Pasta\n\n*italian, dinner*\n\n---\n\n- pasta\n\n---\n"
        ]

        let testDir = createTestDirectory(with: recipes)
        let store = RecipeStore()
        defer {
            store.reset()
            cleanupTestDirectory(testDir)
        }

        await store.loadRecipes(from: testDir)
        let recipeID = store.recipes[0].id

        let result = store.bulkAddTags(["italian", "quick"], to: [recipeID])

        #expect(result.successCount == 1)
        let tags = store.recipes[0].tags
        #expect(tags.filter { $0 == "italian" }.count == 1)
        #expect(tags.contains("quick"))
    }

    // MARK: - RecipeStore Bulk Remove Tests

    @Test("Bulk remove tags from multiple recipes")
    func bulkRemoveTags() async throws {
        let recipes = [
            "pasta.md": "# Pasta\n\n*italian, dinner*\n\n---\n\n- pasta\n\n---\n",
            "pizza.md": "# Pizza\n\n*italian, dinner, baked*\n\n---\n\n- dough\n\n---\n"
        ]

        let testDir = createTestDirectory(with: recipes)
        let store = RecipeStore()
        defer {
            store.reset()
            cleanupTestDirectory(testDir)
        }

        await store.loadRecipes(from: testDir)
        let allIDs = Set(store.recipes.map(\.id))

        let result = store.bulkRemoveTags(["dinner"], from: allIDs)

        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)

        for recipe in store.recipes {
            #expect(!recipe.tags.contains("dinner"))
        }
    }

    @Test("Bulk remove preserves other tags")
    func bulkRemovePreservesOtherTags() async throws {
        let recipes = [
            "pasta.md": "# Pasta\n\n*italian, dinner, quick*\n\n---\n\n- pasta\n\n---\n"
        ]

        let testDir = createTestDirectory(with: recipes)
        let store = RecipeStore()
        defer {
            store.reset()
            cleanupTestDirectory(testDir)
        }

        await store.loadRecipes(from: testDir)
        let recipeID = store.recipes[0].id

        let result = store.bulkRemoveTags(["dinner"], from: [recipeID])

        #expect(result.successCount == 1)
        let tags = store.recipes[0].tags
        #expect(tags.contains("italian"))
        #expect(tags.contains("quick"))
        #expect(!tags.contains("dinner"))
    }

    @Test("Bulk remove tag not on recipe is no-op")
    func bulkRemoveNonexistentTag() async throws {
        let recipes = [
            "pasta.md": "# Pasta\n\n*italian*\n\n---\n\n- pasta\n\n---\n"
        ]

        let testDir = createTestDirectory(with: recipes)
        let store = RecipeStore()
        defer {
            store.reset()
            cleanupTestDirectory(testDir)
        }

        await store.loadRecipes(from: testDir)
        let recipeID = store.recipes[0].id

        let result = store.bulkRemoveTags(["nonexistent"], from: [recipeID])

        #expect(result.successCount == 1)
        #expect(store.recipes[0].tags.contains("italian"))
    }

    // MARK: - ViewModel Edit Mode Tests

    @Test("Enter and exit edit mode")
    func enterExitEditMode() {
        let store = RecipeStore()
        let viewModel = RecipeListViewModel(recipeStore: store)

        #expect(!viewModel.isEditMode)
        #expect(viewModel.selectedRecipeIDs.isEmpty)

        viewModel.enterEditMode()
        #expect(viewModel.isEditMode)

        viewModel.exitEditMode()
        #expect(!viewModel.isEditMode)
        #expect(viewModel.selectedRecipeIDs.isEmpty)
    }

    @Test("Toggle selection adds and removes IDs")
    func toggleSelection() {
        let store = RecipeStore()
        let viewModel = RecipeListViewModel(recipeStore: store)
        let id1 = UUID()
        let id2 = UUID()

        viewModel.enterEditMode()

        viewModel.toggleSelection(id1)
        #expect(viewModel.selectedRecipeIDs.contains(id1))
        #expect(viewModel.selectedCount == 1)

        viewModel.toggleSelection(id2)
        #expect(viewModel.selectedCount == 2)

        viewModel.toggleSelection(id1)
        #expect(!viewModel.selectedRecipeIDs.contains(id1))
        #expect(viewModel.selectedCount == 1)
    }

    @Test("Exit edit mode clears selection")
    func exitEditModeClearsSelection() {
        let store = RecipeStore()
        let viewModel = RecipeListViewModel(recipeStore: store)

        viewModel.enterEditMode()
        viewModel.toggleSelection(UUID())
        viewModel.toggleSelection(UUID())
        #expect(viewModel.selectedCount == 2)

        viewModel.exitEditMode()
        #expect(viewModel.selectedRecipeIDs.isEmpty)
        #expect(viewModel.selectedCount == 0)
    }

    @Test("Tags on selected recipes returns correct counts")
    func tagsOnSelectedRecipes() {
        let store = RecipeStore()
        store.recipes = [
            makeRecipeFile(title: "Recipe A", tags: ["italian", "dinner"]),
            makeRecipeFile(title: "Recipe B", tags: ["mexican", "dinner"]),
            makeRecipeFile(title: "Recipe C", tags: ["italian", "lunch"])
        ]

        let viewModel = RecipeListViewModel(recipeStore: store)
        viewModel.enterEditMode()

        // Select recipes A and B
        viewModel.toggleSelection(store.recipes[0].id)
        viewModel.toggleSelection(store.recipes[1].id)

        let tagCounts = viewModel.tagsOnSelectedRecipes()
        let tagMap = Dictionary(uniqueKeysWithValues: tagCounts.map { ($0.tag, $0.count) })

        #expect(tagMap["dinner"] == 2)
        #expect(tagMap["italian"] == 1)
        #expect(tagMap["mexican"] == 1)
        #expect(tagMap["lunch"] == nil) // Recipe C not selected
    }

    @Test("Tags on selected recipes with no overlap")
    func tagsOnSelectedRecipesNoOverlap() {
        let store = RecipeStore()
        store.recipes = [
            makeRecipeFile(title: "Recipe A", tags: ["italian"]),
            makeRecipeFile(title: "Recipe B", tags: ["mexican"])
        ]

        let viewModel = RecipeListViewModel(recipeStore: store)
        viewModel.enterEditMode()
        viewModel.toggleSelection(store.recipes[0].id)
        viewModel.toggleSelection(store.recipes[1].id)

        let tagCounts = viewModel.tagsOnSelectedRecipes()
        #expect(tagCounts.count == 2)
        for item in tagCounts {
            #expect(item.count == 1)
        }
    }
}
