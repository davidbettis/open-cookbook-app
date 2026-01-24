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
    @State private var selectedPortion: PortionOption = .whole

    var body: some View {
        Group {
            #if os(macOS)
            let useWideLayout = true
            #else
            let useWideLayout = horizontalSizeClass == .regular
            #endif

            if useWideLayout {
                // iPad/macOS: Header + Split content with yield in ingredients pane
                iPadLayout
            } else {
                // iPhone: Structured layout with yield under title
                iPhoneLayout
            }
        }
        .onChange(of: recipeFile.id) { _, _ in
            // Reset portion to whole when navigating to a different recipe
            selectedPortion = .whole
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        VStack(spacing: 0) {
            // Full-width header (without yield - it's shown in ingredients pane)
            RecipeHeaderView(
                title: recipeFile.title,
                description: recipeFile.description,
                tags: recipeFile.tags,
                yield: Yield(amount: []),
                portionMultiplier: selectedPortion.multiplier
            )
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Split ingredients/instructions with yield and portion selector
            RecipeDetailSplitContent(
                ingredientGroups: recipeFile.ingredientGroups,
                instructions: recipeFile.instructions,
                yield: recipeFile.yield,
                selectedPortion: $selectedPortion
            )
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with scaled yields
            RecipeHeaderView(
                title: recipeFile.title,
                description: recipeFile.description,
                tags: recipeFile.tags,
                yield: recipeFile.yield,
                portionMultiplier: selectedPortion.multiplier
            )
            .padding(.horizontal)

            Divider()

            // Portion selector
            PortionSelectorView(selectedPortion: $selectedPortion)
                .padding(.horizontal)

            // Ingredients with scaling
            IngredientsListView(
                ingredientGroups: recipeFile.ingredientGroups,
                portionMultiplier: selectedPortion.multiplier
            )
            .padding(.horizontal)

            Divider()

            // Instructions (still markdown)
            if let instructions = recipeFile.instructions, !instructions.isEmpty {
                Markdown(instructions)
                    .markdownTheme(.recipe)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
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
                recipe: Recipe(
                    title: "Chocolate Chip Cookies",
                    description: "Classic homemade chocolate chip cookies.",
                    tags: ["dessert", "baking"],
                    yield: Yield(amount: [Amount(24, unit: "cookies")]),
                    ingredientGroups: [
                        IngredientGroup(ingredients: [
                            Ingredient(name: "flour", amount: Amount(2, unit: "cups")),
                            Ingredient(name: "baking soda", amount: Amount(1, unit: "tsp"))
                        ])
                    ],
                    instructions: "1. Preheat oven\n2. Mix and bake"
                )
            ),
            markdownContent: "# Chocolate Chip Cookies\n\nSample content..."
        )
        .environment(\.horizontalSizeClass, .compact)
    }
}
