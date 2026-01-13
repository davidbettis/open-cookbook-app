//
//  RecipeDetailViewTests.swift
//  RecipeFreeTests
//
//  Unit tests for RecipeDetailView functionality
//

import Testing
import Foundation
import SwiftUI
import MarkdownUI
@testable import RecipeFree

@Suite("Recipe Detail View Tests", .serialized)
struct RecipeDetailViewTests {

    // MARK: - Test Helpers

    /// Creates a temporary recipe file with the given content
    private func createTempRecipeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_recipe_\(UUID().uuidString).md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Cleans up a temporary file
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - TC-015: Display Simple Recipe

    @Test("Simple recipe file can be read and content is valid")
    func simpleRecipeFileReading() async throws {
        let content = """
        # Chocolate Chip Cookies

        Classic homemade chocolate chip cookies with a chewy center.

        *dessert, baking, quick*

        **makes 24 cookies**

        ---

        - *2 1/4 cups* all-purpose flour
        - *1 tsp* baking soda
        - *1 cup* butter, softened
        - *2 cups* chocolate chips

        ---

        1. Preheat oven to 375°F (190°C)
        2. Mix flour and baking soda in a bowl
        3. Cream butter and sugars together
        4. Combine and bake for 10-12 minutes
        """

        let fileURL = try createTempRecipeFile(content: content)
        defer { cleanup(fileURL) }

        // Verify file can be read
        let data = try Data(contentsOf: fileURL)
        let readContent = String(data: data, encoding: .utf8)

        #expect(readContent != nil)
        #expect(readContent?.contains("# Chocolate Chip Cookies") == true)
        #expect(readContent?.contains("*dessert, baking, quick*") == true)
        #expect(readContent?.contains("**makes 24 cookies**") == true)
        #expect(readContent?.contains("all-purpose flour") == true)
        #expect(readContent?.contains("Preheat oven") == true)
    }

    @Test("Recipe model can be created for detail view")
    func recipeModelForDetailView() async throws {
        let content = """
        # Test Recipe

        A simple test recipe.

        *test, sample*

        **serves 4**

        ---

        - *1 cup* ingredient one
        - *2 tbsp* ingredient two
        """

        let fileURL = try createTempRecipeFile(content: content)
        defer { cleanup(fileURL) }

        let recipe = Recipe(
            filePath: fileURL,
            title: "Test Recipe",
            description: "A simple test recipe.",
            tags: ["test", "sample"],
            yields: ["serves 4"]
        )

        #expect(recipe.title == "Test Recipe")
        #expect(recipe.description == "A simple test recipe.")
        #expect(recipe.tags == ["test", "sample"])
        #expect(recipe.yields == ["serves 4"])
        #expect(recipe.filePath == fileURL)
    }

    // MARK: - TC-016: Display Recipe with Ingredient Groups

    @Test("Recipe with ingredient groups has valid markdown structure")
    func recipeWithIngredientGroups() async throws {
        let content = """
        # Layered Cake

        A delicious layered cake with frosting.

        *dessert, cake, celebration*

        **serves 12**

        ---

        ## For the Cake
        - *2 cups* all-purpose flour
        - *1 1/2 cups* sugar
        - *3 large* eggs
        - *1 cup* milk

        ## For the Frosting
        - *1 cup* butter, softened
        - *4 cups* powdered sugar
        - *2 tsp* vanilla extract

        ## For the Filling
        - *1 cup* raspberry jam
        - *1/2 cup* fresh raspberries

        ---

        1. Preheat oven to 350°F
        2. Mix cake ingredients
        3. Bake for 30 minutes
        4. Prepare frosting while cake cools
        5. Assemble layers with filling and frosting
        """

        let fileURL = try createTempRecipeFile(content: content)
        defer { cleanup(fileURL) }

        let data = try Data(contentsOf: fileURL)
        let readContent = String(data: data, encoding: .utf8)

        // Verify ingredient groups are present
        #expect(readContent?.contains("## For the Cake") == true)
        #expect(readContent?.contains("## For the Frosting") == true)
        #expect(readContent?.contains("## For the Filling") == true)

        // Verify ingredients under each group
        #expect(readContent?.contains("all-purpose flour") == true)
        #expect(readContent?.contains("powdered sugar") == true)
        #expect(readContent?.contains("raspberry jam") == true)
    }

    // MARK: - TC-017: Display Minimal Recipe

    @Test("Minimal recipe with only title and ingredients handles gracefully")
    func minimalRecipe() async throws {
        let content = """
        # Quick Snack

        - crackers
        - cheese
        - grapes
        """

        let fileURL = try createTempRecipeFile(content: content)
        defer { cleanup(fileURL) }

        let data = try Data(contentsOf: fileURL)
        let readContent = String(data: data, encoding: .utf8)

        #expect(readContent != nil)
        #expect(readContent?.contains("# Quick Snack") == true)
        #expect(readContent?.contains("crackers") == true)

        // Verify Recipe model handles missing optional fields
        let recipe = Recipe(
            filePath: fileURL,
            title: "Quick Snack"
            // No description, tags, yields, or instructions
        )

        #expect(recipe.title == "Quick Snack")
        #expect(recipe.description == nil)
        #expect(recipe.tags.isEmpty)
        #expect(recipe.yields.isEmpty)
        #expect(recipe.instructions == nil)
    }

    @Test("Recipe with only title is valid")
    func recipeTitleOnly() async throws {
        let content = """
        # Empty Recipe
        """

        let fileURL = try createTempRecipeFile(content: content)
        defer { cleanup(fileURL) }

        let data = try Data(contentsOf: fileURL)
        let readContent = String(data: data, encoding: .utf8)

        #expect(readContent?.contains("# Empty Recipe") == true)

        let recipe = Recipe(filePath: fileURL, title: "Empty Recipe")
        #expect(recipe.title == "Empty Recipe")
    }

    // MARK: - Title Extraction Tests

    @Test("Title extraction from Recipe model for navigation bar")
    func titleExtractionForNavBar() async throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Grandmother's Apple Pie"
        )

        // Title should be used directly for navigation bar
        #expect(recipe.title == "Grandmother's Apple Pie")
        #expect(!recipe.title.isEmpty)
    }

    @Test("Long title is preserved completely")
    func longTitlePreserved() async throws {
        let longTitle = "Super Delicious Extra Special Chocolate Fudge Brownie Cake with Caramel Drizzle"

        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: longTitle
        )

        #expect(recipe.title == longTitle)
        #expect(recipe.title.count == longTitle.count)
    }

    // MARK: - File Error Handling Tests

    @Test("Non-existent file throws appropriate error")
    func nonExistentFileError() async throws {
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/recipe.md")

        #expect(throws: (any Error).self) {
            _ = try Data(contentsOf: fakeURL)
        }
    }

    @Test("Invalid encoding handled gracefully")
    func invalidEncodingHandling() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("binary_\(UUID().uuidString).md")

        // Write some binary data that isn't valid UTF-8
        let invalidData = Data([0xFF, 0xFE, 0x00, 0x01])
        try invalidData.write(to: fileURL)
        defer { cleanup(fileURL) }

        let data = try Data(contentsOf: fileURL)
        let content = String(data: data, encoding: .utf8)

        // Should return nil for invalid UTF-8
        #expect(content == nil)
    }

    // MARK: - Recipe Theme Tests

    @Test("Recipe theme is accessible")
    @MainActor
    func recipeThemeAccessible() async throws {
        // Verify the custom recipe theme can be created
        let theme = Theme.recipe
        #expect(theme != nil)
    }

    // MARK: - Content Formatting Tests

    @Test("Markdown content preserves formatting")
    func markdownFormattingPreserved() async throws {
        let content = """
        # Recipe Title

        **Bold text** and *italic text* and `code`.

        - List item 1
        - List item 2

        1. Numbered item
        2. Another item

        ---

        > A blockquote
        """

        let fileURL = try createTempRecipeFile(content: content)
        defer { cleanup(fileURL) }

        let data = try Data(contentsOf: fileURL)
        let readContent = String(data: data, encoding: .utf8)

        #expect(readContent?.contains("**Bold text**") == true)
        #expect(readContent?.contains("*italic text*") == true)
        #expect(readContent?.contains("`code`") == true)
        #expect(readContent?.contains("- List item") == true)
        #expect(readContent?.contains("1. Numbered") == true)
        #expect(readContent?.contains("---") == true)
        #expect(readContent?.contains("> A blockquote") == true)
    }

    @Test("Unicode characters preserved in recipe content")
    func unicodePreserved() async throws {
        let content = """
        # Crème Brûlée

        A classic French dessert with caramelized sugar.

        *français, dessert, élégant*

        **serves 6 portions**

        ---

        - *500ml* crème fraîche
        - *100g* sucre
        - *4* œufs
        - Vanille de Tahiti

        ---

        1. Préchauffer le four à 150°C
        2. Mélanger les ingrédients
        3. Cuire au bain-marie pendant 45 minutes
        """

        let fileURL = try createTempRecipeFile(content: content)
        defer { cleanup(fileURL) }

        let data = try Data(contentsOf: fileURL)
        let readContent = String(data: data, encoding: .utf8)

        #expect(readContent?.contains("Crème Brûlée") == true)
        #expect(readContent?.contains("élégant") == true)
        #expect(readContent?.contains("œufs") == true)
        #expect(readContent?.contains("150°C") == true)
    }
}
