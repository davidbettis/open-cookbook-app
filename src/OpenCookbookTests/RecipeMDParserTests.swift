//
//  RecipeMDParserTests.swift
//  OpenCookbookTests
//
//  Unit tests for RecipeFileParser (wrapper around RecipeMD library parser)
//

import Testing
import Foundation
import RecipeMD
@testable import OpenCookbook

@Suite("RecipeFileParser Tests", .serialized)
struct RecipeMDParserTests {

    // Create parser as computed property so each test gets a fresh instance
    var parser: RecipeFileParser { RecipeFileParser() }

    // MARK: - Full Parse Tests

    @Test("Parse complete valid RecipeMD file")
    func parseCompleteRecipe() async throws {
        // Create temporary file with unique name to avoid parallel test conflicts
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_recipe_\(UUID().uuidString).md")

        let content = """
        # Chocolate Chip Cookies

        Classic homemade chocolate chip cookies that are crispy on the outside and chewy on the inside.

        *dessert, baking, cookies*

        **24 cookies**

        ---

        - *2 cups* flour
        - *1 cup* sugar

        ---

        1. Mix dry ingredients
        2. Add wet ingredients
        3. Bake at 350F
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Parse the file
        let recipeFile = try parser.parse(from: fileURL)

        // Verify parsed data
        #expect(recipeFile.title == "Chocolate Chip Cookies")
        #expect(recipeFile.description?.contains("Classic homemade") == true)
        #expect(recipeFile.tags == ["dessert", "baking", "cookies"])
        #expect(recipeFile.filePath == fileURL)
        #expect(recipeFile.fileModifiedDate != nil)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Handle minimal recipe with title only")
    func parseMinimalRecipe() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("minimal_recipe_\(UUID().uuidString).md")

        let content = """
        # Simple Recipe

        ---

        - ingredient

        ---
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipeFile = try parser.parse(from: fileURL)

        #expect(recipeFile.title == "Simple Recipe")
        #expect(recipeFile.description == nil)
        #expect(recipeFile.tags.isEmpty)

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Throw error for missing title")
    func parseRecipeWithoutTitle() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("no_title_\(UUID().uuidString).md")

        let content = """
        This is some content without a title.

        *tag1, tag2*
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try parser.parse(from: fileURL)
        }

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Throw error for non-existent file")
    func parseNonExistentFile() async throws {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_recipe.md")

        #expect(throws: (any Error).self) {
            try parser.parse(from: fakeURL)
        }
    }

    @Test("Handle malformed markdown gracefully")
    func parseMalformedMarkdown() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("malformed_\(UUID().uuidString).md")

        let content = """
        # Valid Title

        *unclosed italic

        **unclosed bold

        ---

        - ingredient

        ---

        Some random text.
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipeFile = try parser.parse(from: fileURL)

        // Should still parse the title successfully
        #expect(recipeFile.title == "Valid Title")

        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Ingredient Parsing Tests

    @Test("Parse recipe with ingredients")
    func parseRecipeWithIngredients() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("ingredients_\(UUID().uuidString).md")

        let content = """
        # Test Recipe

        ---

        - *2 cups* flour
        - *1 tsp* salt
        - butter

        ---

        Mix and bake.
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipeFile = try parser.parse(from: fileURL)

        #expect(recipeFile.allIngredients.count >= 1)
        #expect(recipeFile.allIngredients.contains { $0.name.contains("flour") })

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Parse ingredient with parenthetical metric conversion extracts supplemental amount")
    func parseIngredientWithParentheticalConversion() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("supplemental_\(UUID().uuidString).md")

        let content = """
        # Test Recipe

        ---

        - *1 oz (28 g)* water
        - *2 T (30 ml)* peanut oil
        - *1 tsp (3 g)* red Sichuan peppercorns

        ---

        Mix together.
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipeFile = try parser.parse(from: fileURL)
        let ingredients = recipeFile.allIngredients

        #expect(ingredients[0].amount?.amount == 1.0)
        #expect(ingredients[0].amount?.unit == "oz")
        #expect(ingredients[0].supplementalAmount?.amount == 28.0)
        #expect(ingredients[0].supplementalAmount?.unit == "g")
        #expect(ingredients[0].name == "water")

        #expect(ingredients[1].amount?.amount == 2.0)
        #expect(ingredients[1].amount?.unit == "T")
        #expect(ingredients[1].supplementalAmount?.amount == 30.0)
        #expect(ingredients[1].supplementalAmount?.unit == "ml")
        #expect(ingredients[1].name == "peanut oil")

        #expect(ingredients[2].amount?.amount == 1.0)
        #expect(ingredients[2].amount?.unit == "tsp")
        #expect(ingredients[2].supplementalAmount?.amount == 3.0)
        #expect(ingredients[2].supplementalAmount?.unit == "g")
        #expect(ingredients[2].name == "red Sichuan peppercorns")

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Parse normal ingredients still work with supplemental amounts enabled")
    func parseNormalIngredientsUnaffected() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("normal_\(UUID().uuidString).md")

        let content = """
        # Test Recipe

        ---

        - *2 cups* flour
        - *500 g* sugar
        - *3* eggs
        - butter

        ---

        Mix together.
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipeFile = try parser.parse(from: fileURL)
        let ingredients = recipeFile.allIngredients

        #expect(ingredients[0].amount?.unit == "cups")
        #expect(ingredients[0].name == "flour")
        #expect(ingredients[1].amount?.unit == "g")
        #expect(ingredients[1].name == "sugar")
        #expect(ingredients[2].amount?.amount == 3.0)
        #expect(ingredients[2].amount?.unit == nil)
        #expect(ingredients[2].name == "eggs")
        #expect(ingredients[3].amount == nil)
        #expect(ingredients[3].name == "butter")

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Parse recipe with ingredient groups")
    func parseRecipeWithIngredientGroups() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("groups_\(UUID().uuidString).md")

        let content = """
        # Layered Recipe

        ---

        ## For the Dough
        - *2 cups* flour
        - *1 tsp* salt

        ## For the Filling
        - *1 cup* cream cheese

        ---

        Combine and serve.
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipeFile = try parser.parse(from: fileURL)

        #expect(recipeFile.ingredientGroups.count >= 2)

        try? FileManager.default.removeItem(at: fileURL)
    }
}
