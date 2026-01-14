//
//  RecipeDetailContent.swift
//  RecipeFree
//
//  Platform-adaptive recipe content view:
//  - iPad (regular width): Split layout with side-by-side ingredients/instructions
//  - iPhone (compact width): Vertical markdown layout
//

import MarkdownUI
import RecipeMD
import SwiftUI

/// Platform-adaptive recipe content that switches between split (iPad) and stacked (iPhone) layouts
struct RecipeDetailContent: View {
    let recipeFile: RecipeFile
    let markdownContent: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: Header + Split content
            iPadLayout
        } else {
            // iPhone: Full markdown in ScrollView (existing behavior)
            iPhoneLayout
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        VStack(spacing: 0) {
            // Full-width header
            RecipeHeaderView(
                title: recipeFile.title,
                description: recipeFile.description,
                tags: recipeFile.tags,
                yield: recipeFile.yield
            )
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Split ingredients/instructions
            RecipeDetailSplitContent(
                ingredientGroups: recipeFile.ingredientGroups,
                instructions: recipeFile.instructions
            )
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        Markdown(markdownContent)
            .markdownTheme(.recipe)
            .padding()
    }
}

// MARK: - Previews

#Preview("iPad Layout") {
    RecipeDetailContent(
        recipeFile: RecipeFile(
            filePath: URL(fileURLWithPath: "/example/recipe.md"),
            recipe: Recipe(
                title: "Chocolate Chip Cookies",
                description: "Classic homemade chocolate chip cookies with a chewy center and crispy edges.",
                tags: ["dessert", "baking", "quick"],
                yield: Yield(amount: [Amount(24, unit: "cookies")]),
                ingredientGroups: [
                    IngredientGroup(
                        title: "For the Dough",
                        ingredients: [
                            Ingredient(name: "all-purpose flour", amount: Amount(2.25, unit: "cups")),
                            Ingredient(name: "baking soda", amount: Amount(1, unit: "tsp"))
                        ]
                    ),
                    IngredientGroup(
                        title: "Mix-ins",
                        ingredients: [
                            Ingredient(name: "chocolate chips", amount: Amount(2, unit: "cups"))
                        ]
                    )
                ],
                instructions: """
                1. Preheat oven to 375°F
                2. Mix dry ingredients
                3. Cream butter and sugars
                4. Combine and bake
                """
            )
        ),
        markdownContent: "# Chocolate Chip Cookies\n\nSample content..."
    )
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone Layout") {
    ScrollView {
        RecipeDetailContent(
            recipeFile: RecipeFile(
                filePath: URL(fileURLWithPath: "/example/recipe.md"),
                recipe: Recipe(title: "Chocolate Chip Cookies")
            ),
            markdownContent: """
            # Chocolate Chip Cookies

            Classic homemade chocolate chip cookies.

            *dessert, baking*

            **makes 24 cookies**

            ---

            - *2 cups* flour
            - *1 tsp* baking soda

            ---

            1. Preheat oven
            2. Mix and bake
            """
        )
        .environment(\.horizontalSizeClass, .compact)
    }
}
