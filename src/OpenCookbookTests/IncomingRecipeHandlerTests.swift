//
//  IncomingRecipeHandlerTests.swift
//  OpenCookbookTests
//
//  Unit tests for IncomingRecipeHandler
//

import Testing
import Foundation
import RecipeMD
@testable import OpenCookbook

@Suite("IncomingRecipeHandler Tests")
struct IncomingRecipeHandlerTests {

    // MARK: - Markdown Parsing

    @Test("Parse valid RecipeMD markdown")
    func parseValidMarkdown() throws {
        let markdown = """
        # Chocolate Chip Cookies

        Classic cookies.

        *dessert, baking*

        ---

        - *2 cups* flour
        - *1 cup* sugar

        ---

        1. Mix ingredients
        2. Bake at 350F
        """

        let incoming = try IncomingRecipeHandler.handleIncomingMarkdown(markdown)

        #expect(incoming.recipe.title == "Chocolate Chip Cookies")
        #expect(incoming.recipe.tags.contains("dessert"))
        #expect(!incoming.recipe.ingredientGroups.isEmpty)
        #expect(incoming.markdown == markdown)
    }

    @Test("Reject plain text that is not a recipe")
    func rejectNonRecipeText() {
        let plainText = "This is just a regular paragraph of text with no recipe structure."

        #expect(throws: IncomingRecipeError.self) {
            _ = try IncomingRecipeHandler.handleIncomingMarkdown(plainText)
        }
    }

    @Test("Reject empty string")
    func rejectEmptyString() {
        #expect(throws: IncomingRecipeError.self) {
            _ = try IncomingRecipeHandler.handleIncomingMarkdown("")
        }
    }

    @Test("Parse minimal recipe with just title and ingredients")
    func parseMinimalRecipe() throws {
        let markdown = """
        # Simple Recipe

        ---

        - *1 cup* water

        ---

        Boil the water.
        """

        let incoming = try IncomingRecipeHandler.handleIncomingMarkdown(markdown)
        #expect(incoming.recipe.title == "Simple Recipe")
    }

    // MARK: - File Handling

    @Test("Parse valid recipe from file URL")
    func parseValidFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_import_\(UUID().uuidString).recipemd")

        let markdown = """
        # Test Recipe

        ---

        - *1 cup* flour

        ---

        Mix and bake.
        """

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let incoming = try IncomingRecipeHandler.handleIncomingFile(at: fileURL)
        #expect(incoming.recipe.title == "Test Recipe")
    }

    @Test("Reject non-existent file")
    func rejectMissingFile() {
        let fakeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).recipemd")

        #expect(throws: IncomingRecipeError.self) {
            _ = try IncomingRecipeHandler.handleIncomingFile(at: fakeURL)
        }
    }

    @Test("Reject file with non-recipe content")
    func rejectNonRecipeFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_readme_\(UUID().uuidString).md")

        let content = "Just a plain README file with no recipe structure."
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: IncomingRecipeError.self) {
            _ = try IncomingRecipeHandler.handleIncomingFile(at: fileURL)
        }
    }
}
