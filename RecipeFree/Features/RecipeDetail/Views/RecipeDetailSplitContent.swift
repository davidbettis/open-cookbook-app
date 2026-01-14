//
//  RecipeDetailSplitContent.swift
//  RecipeFree
//
//  Side-by-side ingredients (25%) and instructions (75%) for iPad
//

import MarkdownUI
import RecipeMD
import SwiftUI

/// Displays ingredients and instructions side-by-side for iPad
/// - Ingredients panel: 25% width, independently scrollable
/// - Instructions panel: 75% width, independently scrollable
struct RecipeDetailSplitContent: View {
    let ingredientGroups: [IngredientGroup]
    let instructions: String?

    /// Proportion of width for ingredients panel
    private let ingredientsProportion: CGFloat = 0.33

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left panel: Ingredients (25%)
                ingredientsPanel
                    .frame(width: geometry.size.width * ingredientsProportion)

                Divider()

                // Right panel: Instructions (75%)
                instructionsPanel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Ingredients Panel

    private var ingredientsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Ingredients")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .accessibilityAddTraits(.isHeader)

            Divider()

            // Scrollable ingredients list
            ScrollView {
                IngredientsListView(ingredientGroups: ingredientGroups)
                    .padding(16)
            }
        }
        .background(Color(.secondarySystemBackground).opacity(0.3))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ingredients")
    }

    // MARK: - Instructions Panel

    private var instructionsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Instructions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .accessibilityAddTraits(.isHeader)

            Divider()

            // Scrollable instructions
            ScrollView {
                if let instructions = instructions, !instructions.isEmpty {
                    Markdown(instructions)
                        .markdownTheme(.recipe)
                        .padding(16)
                } else {
                    Text("No instructions provided")
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(16)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Instructions")
    }
}

// MARK: - Previews

#Preview("Split Content") {
    RecipeDetailSplitContent(
        ingredientGroups: [
            IngredientGroup(
                title: "For the Dough",
                ingredients: [
                    Ingredient(name: "all-purpose flour", amount: Amount(2.25, unit: "cups")),
                    Ingredient(name: "baking soda", amount: Amount(1, unit: "tsp")),
                    Ingredient(name: "salt", amount: Amount(1, unit: "tsp"))
                ]
            ),
            IngredientGroup(
                title: "For the Mix-ins",
                ingredients: [
                    Ingredient(name: "chocolate chips", amount: Amount(2, unit: "cups")),
                    Ingredient(name: "walnuts, chopped", amount: Amount(1, unit: "cup"))
                ]
            )
        ],
        instructions: """
        1. Preheat oven to 375°F (190°C)
        2. Mix flour, baking soda, and salt in a bowl
        3. In a separate bowl, cream together butter and sugars
        4. Beat in eggs and vanilla to butter mixture
        5. Gradually blend in flour mixture
        6. Stir in chocolate chips and walnuts
        7. Drop rounded tablespoons onto ungreased cookie sheets
        8. Bake for 10-12 minutes until golden brown
        9. Cool on baking sheet for 2 minutes before transferring
        """
    )
    .frame(height: 500)
}

#Preview("No Instructions") {
    RecipeDetailSplitContent(
        ingredientGroups: [
            IngredientGroup(ingredients: [
                Ingredient(name: "ingredient 1", amount: Amount(1, unit: "cup")),
                Ingredient(name: "ingredient 2", amount: Amount(2, unit: "tbsp"))
            ])
        ],
        instructions: nil
    )
    .frame(height: 400)
}
