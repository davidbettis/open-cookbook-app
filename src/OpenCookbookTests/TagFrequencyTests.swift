//
//  TagFrequencyTests.swift
//  OpenCookbookTests
//
//  Tests for TagFrequency computation and prompt formatting
//

import Foundation
import Testing
import RecipeMD
@testable import OpenCookbook

@Suite("TagFrequency")
@MainActor
struct TagFrequencyTests {

    // MARK: - computeTagFrequencies

    @Test("Empty library returns all built-in tags at count 0")
    func emptyLibraryReturnsAllBuiltIn() {
        let frequencies = RecipeSearchService.computeTagFrequencies(from: [])

        #expect(frequencies.count == 43)
        #expect(frequencies.allSatisfy { $0.count == 0 })
        #expect(frequencies.allSatisfy { $0.isBuiltIn })
    }

    @Test("Library with tags returns correct counts")
    func libraryWithTagsReturnsCorrectCounts() {
        let recipes = [
            makeRecipe(tags: ["italian", "chicken"]),
            makeRecipe(tags: ["italian", "one-pot"]),
            makeRecipe(tags: ["italian"]),
        ]

        let frequencies = RecipeSearchService.computeTagFrequencies(from: recipes)

        let italian = frequencies.first { $0.name == "italian" }
        let chicken = frequencies.first { $0.name == "chicken" }
        let onePot = frequencies.first { $0.name == "one-pot" }
        let vegan = frequencies.first { $0.name == "vegan" }

        #expect(italian?.count == 3)
        #expect(chicken?.count == 1)
        #expect(onePot?.count == 1)
        #expect(vegan?.count == 0)
    }

    @Test("Custom tags are included with nil category")
    func customTagsIncluded() {
        let recipes = [
            makeRecipe(tags: ["date-night", "italian"]),
            makeRecipe(tags: ["date-night"]),
        ]

        let frequencies = RecipeSearchService.computeTagFrequencies(from: recipes)

        let dateNight = frequencies.first { $0.name == "date-night" }
        #expect(dateNight != nil)
        #expect(dateNight?.count == 2)
        #expect(dateNight?.isBuiltIn == false)
        #expect(dateNight?.category == nil)
    }

    @Test("Sorted by count descending then alphabetical")
    func sortedByCountThenAlpha() {
        let recipes = [
            makeRecipe(tags: ["chicken", "italian"]),
            makeRecipe(tags: ["italian"]),
        ]

        let frequencies = RecipeSearchService.computeTagFrequencies(from: recipes)

        // Italian (2) should come before chicken (1)
        let italianIdx = frequencies.firstIndex { $0.name == "italian" }!
        let chickenIdx = frequencies.firstIndex { $0.name == "chicken" }!
        #expect(italianIdx < chickenIdx)

        // All 0-count tags should be sorted alphabetically
        let zeroes = frequencies.filter { $0.count == 0 }
        let zeroNames = zeroes.map(\.name)
        #expect(zeroNames == zeroNames.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        })
    }

    @Test("Tags are normalized to lowercase")
    func tagsNormalizedToLowercase() {
        let recipes = [
            makeRecipe(tags: ["Italian", "CHICKEN"]),
        ]

        let frequencies = RecipeSearchService.computeTagFrequencies(from: recipes)

        let italian = frequencies.first { $0.name == "italian" }
        let chicken = frequencies.first { $0.name == "chicken" }
        #expect(italian?.count == 1)
        #expect(chicken?.count == 1)
    }

    // MARK: - tagFrequencyPrompt

    @Test("Prompt format includes header and footer")
    func promptFormatHeaderFooter() {
        let prompt = RecipeSearchService.tagFrequencyPrompt(from: [])

        #expect(prompt.hasPrefix("Tags: Select 2-4 tags from ONLY this list"))
        #expect(prompt.hasSuffix("Do NOT invent tags outside this list."))
    }

    @Test("Prompt includes tag counts")
    func promptIncludesTagCounts() {
        let recipes = [
            makeRecipe(tags: ["italian", "chicken"]),
            makeRecipe(tags: ["italian"]),
        ]

        let prompt = RecipeSearchService.tagFrequencyPrompt(from: recipes)

        #expect(prompt.contains("- italian (2 recipes)"))
        #expect(prompt.contains("- chicken (1 recipe)"))
    }

    @Test("Prompt marks custom tags")
    func promptMarksCustomTags() {
        let recipes = [
            makeRecipe(tags: ["date-night"]),
        ]

        let prompt = RecipeSearchService.tagFrequencyPrompt(from: recipes)

        #expect(prompt.contains("- [Custom] date-night (1 recipe)"))
    }

    // MARK: - Helpers

    private func makeRecipe(tags: [String]) -> RecipeFile {
        RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).md"),
            recipe: Recipe(
                title: "Test Recipe",
                tags: tags,
                ingredientGroups: [IngredientGroup(ingredients: [
                    Ingredient(name: "flour")
                ])]
            )
        )
    }
}
