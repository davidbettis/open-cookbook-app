//
//  RecipeMDSerializerTests.swift
//  RecipeFreeTests
//
//  Tests for RecipeFileSerializer (wrapper around RecipeMD library generator)
//

import Foundation
import Testing
import RecipeMD
@testable import RecipeFree

struct RecipeMDSerializerTests {

    let serializer = RecipeFileSerializer()

    // MARK: - Basic Serialization

    @Test("Serializes recipe with all fields")
    func serializesCompleteRecipe() throws {
        let recipe = Recipe(
            title: "Chocolate Chip Cookies",
            description: "Classic homemade cookies with a chewy center.",
            tags: ["dessert", "baking", "quick"],
            yield: Yield(amount: [Amount(24, unit: "cookies")]),
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "flour", amount: Amount(2, unit: "cups")),
                Ingredient(name: "sugar", amount: Amount(1, unit: "cup")),
                Ingredient(name: "eggs", amount: Amount(2, unit: nil))
            ])],
            instructions: "1. Mix dry ingredients\n2. Add wet ingredients\n3. Bake at 350F"
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("# Chocolate Chip Cookies"))
        #expect(markdown.contains("Classic homemade cookies with a chewy center."))
        #expect(markdown.contains("dessert"))
        #expect(markdown.contains("baking"))
        #expect(markdown.contains("---"))
        #expect(markdown.contains("flour"))
        #expect(markdown.contains("sugar"))
        #expect(markdown.contains("eggs"))
        #expect(markdown.contains("Mix dry ingredients"))
    }

    @Test("Serializes minimal recipe")
    func serializesMinimalRecipe() throws {
        let recipe = Recipe(
            title: "Simple Recipe",
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "salt")
            ])]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("# Simple Recipe"))
        #expect(markdown.contains("---"))
        #expect(markdown.contains("salt"))
    }

    @Test("Serializes recipe with ingredient groups")
    func serializesIngredientGroups() throws {
        let recipe = Recipe(
            title: "Layered Recipe",
            ingredientGroups: [
                IngredientGroup(
                    title: "For the Dough",
                    ingredients: [
                        Ingredient(name: "flour", amount: Amount(2, unit: "cups")),
                        Ingredient(name: "salt", amount: Amount(1, unit: "tsp"))
                    ]
                ),
                IngredientGroup(
                    title: "For the Filling",
                    ingredients: [
                        Ingredient(name: "cream cheese", amount: Amount(1, unit: "cup"))
                    ]
                )
            ]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("For the Dough"))
        #expect(markdown.contains("flour"))
        #expect(markdown.contains("For the Filling"))
        #expect(markdown.contains("cream cheese"))
    }

    @Test("Handles ingredient with only quantity")
    func serializesIngredientWithOnlyQuantity() throws {
        let recipe = Recipe(
            title: "Test",
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "eggs", amount: Amount(2, unit: nil))
            ])]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("eggs"))
        #expect(markdown.contains("2"))
    }

    @Test("Handles ingredient with name only")
    func serializesIngredientWithNameOnly() throws {
        let recipe = Recipe(
            title: "Test",
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "salt")
            ])]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("salt"))
    }

    // MARK: - RecipeFile Serialization

    @Test("Serializes RecipeFile")
    func serializesRecipeFile() throws {
        let recipe = Recipe(
            title: "Test Recipe",
            description: "A test",
            tags: ["test"],
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "ingredient")
            ])]
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        let markdown = serializer.serialize(recipeFile)

        #expect(markdown.contains("# Test Recipe"))
        #expect(markdown.contains("A test"))
        #expect(markdown.contains("test"))
        #expect(markdown.contains("ingredient"))
    }

    // MARK: - Round Trip Tests

    @Test("Round trip: serialize then parse maintains data")
    func roundTripMaintainsData() throws {
        let parser = RecipeFileParser()

        let original = Recipe(
            title: "Round Trip Test",
            description: "Testing round trip conversion",
            tags: ["test", "validation"],
            yield: Yield(amount: [Amount(2, unit: "servings")]),
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "flour", amount: Amount(1, unit: "cup"))
            ])],
            instructions: "Mix and serve"
        )

        let markdown = serializer.serialize(original)

        // Write to temp file and parse
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("round-trip-test-\(UUID().uuidString).md")
        try markdown.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let parsed = try parser.parse(from: tempFile)

        #expect(parsed.title == original.title)
        #expect(parsed.description == original.description)
        #expect(parsed.tags == original.tags)
    }
}
