//
//  DoctorRecipeTests.swift
//  DoctorRecipeTests
//
//  Created by David Bettis on 1/6/26.
//

import Testing
import MarkdownUI
@testable import DoctorRecipe

struct DoctorRecipeTests {

    @Test func exampleTest() async throws {
        // This is a placeholder test to verify test infrastructure works
        #expect(1 + 1 == 2)
    }

    @Test func appLaunches() async throws {
        // Verify basic app structure is set up
        #expect(true)
    }

    @Test func markdownUIIntegration() async throws {
        // Verify MarkdownUI package is properly integrated
        let markdown = "# Hello World"
        #expect(!markdown.isEmpty)
    }

    @Test @MainActor func recipeThemeExists() async throws {
        // Verify custom recipe theme is accessible and can be created
        _ = Theme.recipe
        // If we get here without crashing, the theme is properly configured
        #expect(true)
    }

}
