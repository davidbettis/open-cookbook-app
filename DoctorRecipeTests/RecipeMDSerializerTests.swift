//
//  RecipeMDSerializerTests.swift
//  DoctorRecipeTests
//
//  Tests for RecipeMD serialization
//

import Foundation
import Testing
@testable import DoctorRecipe

struct RecipeMDSerializerTests {

    let serializer = RecipeMDSerializer()

    // MARK: - Basic Serialization

    @Test("Serializes recipe with all fields")
    func serializesCompleteRecipe() throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Chocolate Chip Cookies",
            description: "Classic homemade cookies with a chewy center.",
            tags: ["dessert", "baking", "quick"],
            yields: ["makes 24 cookies"],
            ingredients: [
                Ingredient(quantity: "2", unit: "cups", name: "flour"),
                Ingredient(quantity: "1", unit: "cup", name: "sugar"),
                Ingredient(quantity: "2", name: "eggs")
            ],
            instructions: "1. Mix dry ingredients\n2. Add wet ingredients\n3. Bake at 350F"
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("# Chocolate Chip Cookies"))
        #expect(markdown.contains("Classic homemade cookies with a chewy center."))
        #expect(markdown.contains("*dessert, baking, quick*"))
        #expect(markdown.contains("**makes 24 cookies**"))
        #expect(markdown.contains("---"))
        #expect(markdown.contains("- *2 cups* flour"))
        #expect(markdown.contains("- *1 cup* sugar"))
        #expect(markdown.contains("- *2* eggs"))
        #expect(markdown.contains("1. Mix dry ingredients"))
    }

    @Test("Serializes minimal recipe")
    func serializesMinimalRecipe() throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Simple Recipe",
            ingredients: [
                Ingredient(name: "salt")
            ]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("# Simple Recipe"))
        #expect(markdown.contains("---"))
        #expect(markdown.contains("- salt"))
        // Should not contain empty sections
        #expect(!markdown.contains("**"))
        #expect(!markdown.contains("*,"))
    }

    @Test("Serializes recipe with ingredient groups")
    func serializesIngredientGroups() throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Layered Recipe",
            ingredientGroups: [
                IngredientGroup(
                    name: "For the Dough",
                    ingredients: [
                        Ingredient(quantity: "2", unit: "cups", name: "flour"),
                        Ingredient(quantity: "1", unit: "tsp", name: "salt")
                    ]
                ),
                IngredientGroup(
                    name: "For the Filling",
                    ingredients: [
                        Ingredient(quantity: "1", unit: "cup", name: "cream cheese")
                    ]
                )
            ]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("## For the Dough"))
        #expect(markdown.contains("- *2 cups* flour"))
        #expect(markdown.contains("## For the Filling"))
        #expect(markdown.contains("- *1 cup* cream cheese"))
    }

    @Test("Handles ingredient with only quantity")
    func serializesIngredientWithOnlyQuantity() throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Test",
            ingredients: [
                Ingredient(quantity: "2", name: "eggs")
            ]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("- *2* eggs"))
    }

    @Test("Handles ingredient with only unit")
    func serializesIngredientWithOnlyUnit() throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Test",
            ingredients: [
                Ingredient(unit: "pinch", name: "salt")
            ]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("- *pinch* salt"))
    }

    @Test("Handles ingredient with preparation notes")
    func serializesIngredientWithPreparation() throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Test",
            ingredients: [
                Ingredient(quantity: "1", unit: "cup", name: "butter", preparation: "softened")
            ]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("- *1 cup* butter (softened)"))
    }

    @Test("Preserves multiple yields")
    func serializesMultipleYields() throws {
        let recipe = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Test",
            yields: ["serves 4", "makes 2 loaves"],
            ingredients: [Ingredient(name: "flour")]
        )

        let markdown = serializer.serialize(recipe)

        #expect(markdown.contains("**serves 4, makes 2 loaves**"))
    }

    // MARK: - Round Trip Tests

    @Test("Round trip: serialize then parse maintains data")
    func roundTripMaintainsData() throws {
        let parser = RecipeMDParser()

        let original = Recipe(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            title: "Round Trip Test",
            description: "Testing round trip conversion",
            tags: ["test", "validation"],
            yields: ["serves 2"],
            ingredients: [
                Ingredient(quantity: "1", unit: "cup", name: "flour")
            ],
            instructions: "Mix and serve"
        )

        let markdown = serializer.serialize(original)

        // Write to temp file and parse
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("round-trip-test.md")
        try markdown.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let parsed = try parser.parseMetadata(from: tempFile)

        #expect(parsed.title == original.title)
        #expect(parsed.description == original.description)
        #expect(parsed.tags == original.tags)
        #expect(parsed.yields == original.yields)
    }
}
