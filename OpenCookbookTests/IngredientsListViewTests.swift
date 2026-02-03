//
//  IngredientsListViewTests.swift
//  OpenCookbookTests
//
//  Unit tests for IngredientsListView component
//

import Testing
import Foundation
import SwiftUI
import RecipeMD
@testable import OpenCookbook

@Suite("Ingredients List View Tests")
struct IngredientsListViewTests {

    // MARK: - Single Group Tests

    @Test("Single group with ingredients renders correctly")
    func singleGroupWithIngredients() async throws {
        let ingredients = [
            Ingredient(name: "all-purpose flour", amount: Amount(2, unit: "cups")),
            Ingredient(name: "sugar", amount: Amount(1, unit: "cup")),
            Ingredient(name: "salt", amount: Amount(1, unit: "tsp"))
        ]
        let group = IngredientGroup(ingredients: ingredients)

        #expect(group.ingredients.count == 3)
        #expect(group.ingredients[0].name == "all-purpose flour")
        #expect(group.ingredients[0].amount?.formatted == "2 cups")
        #expect(group.title == nil)
    }

    @Test("Single group with title renders correctly")
    func singleGroupWithTitle() async throws {
        let ingredients = [
            Ingredient(name: "flour", amount: Amount(2, unit: "cups"))
        ]
        let group = IngredientGroup(title: "For the Dough", ingredients: ingredients)

        #expect(group.title == "For the Dough")
        #expect(group.ingredients.count == 1)
    }

    // MARK: - Multiple Groups Tests

    @Test("Multiple groups maintain order")
    func multipleGroupsOrder() async throws {
        let groups = [
            IngredientGroup(
                title: "For the Dough",
                ingredients: [Ingredient(name: "flour", amount: Amount(2, unit: "cups"))]
            ),
            IngredientGroup(
                title: "For the Filling",
                ingredients: [Ingredient(name: "cream cheese", amount: Amount(1, unit: "cup"))]
            ),
            IngredientGroup(
                title: "For the Topping",
                ingredients: [Ingredient(name: "powdered sugar", amount: Amount(0.5, unit: "cup"))]
            )
        ]

        #expect(groups.count == 3)
        #expect(groups[0].title == "For the Dough")
        #expect(groups[1].title == "For the Filling")
        #expect(groups[2].title == "For the Topping")
    }

    // MARK: - Empty Groups Tests

    @Test("Empty group handled gracefully")
    func emptyGroupHandled() async throws {
        let group = IngredientGroup(ingredients: [])

        #expect(group.ingredients.isEmpty)
        #expect(group.title == nil)
    }

    @Test("Group with empty title treated as untitled")
    func emptyTitleGroup() async throws {
        let group = IngredientGroup(
            title: "",
            ingredients: [Ingredient(name: "ingredient")]
        )

        #expect(group.title == "")
        #expect(group.ingredients.count == 1)
    }

    // MARK: - Ingredient Amount Tests

    @Test("Ingredients with amounts format correctly")
    func ingredientWithAmount() async throws {
        let ingredient = Ingredient(name: "flour", amount: Amount(2.5, unit: "cups"))

        #expect(ingredient.name == "flour")
        #expect(ingredient.amount != nil)
        #expect(ingredient.amount?.formatted.contains("2") == true)
        #expect(ingredient.amount?.formatted.contains("cups") == true)
    }

    @Test("Ingredients without amounts handled")
    func ingredientWithoutAmount() async throws {
        let ingredient = Ingredient(name: "salt to taste")

        #expect(ingredient.name == "salt to taste")
        #expect(ingredient.amount == nil)
    }

    @Test("Ingredient with fractional amount")
    func ingredientWithFraction() async throws {
        let ingredient = Ingredient(name: "butter", amount: Amount(0.5, unit: "cup"))

        #expect(ingredient.name == "butter")
        #expect(ingredient.amount != nil)
    }

    // MARK: - RecipeFile Integration Tests

    @Test("RecipeFile ingredientGroups accessor works")
    func recipeFileIngredientGroups() async throws {
        let groups = [
            IngredientGroup(ingredients: [
                Ingredient(name: "flour", amount: Amount(2, unit: "cups")),
                Ingredient(name: "sugar", amount: Amount(1, unit: "cup"))
            ])
        ]

        let recipe = Recipe(
            title: "Test Recipe",
            ingredientGroups: groups
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        #expect(recipeFile.ingredientGroups.count == 1)
        #expect(recipeFile.ingredientGroups[0].ingredients.count == 2)
    }

    @Test("RecipeFile allIngredients flattens all groups")
    func recipeFileAllIngredients() async throws {
        let groups = [
            IngredientGroup(
                title: "Group 1",
                ingredients: [Ingredient(name: "item1")]
            ),
            IngredientGroup(
                title: "Group 2",
                ingredients: [Ingredient(name: "item2"), Ingredient(name: "item3")]
            )
        ]

        let recipe = Recipe(
            title: "Test Recipe",
            ingredientGroups: groups
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        #expect(recipeFile.allIngredients.count == 3)
    }
}
