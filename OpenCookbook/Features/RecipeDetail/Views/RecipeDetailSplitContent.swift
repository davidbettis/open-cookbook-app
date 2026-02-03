//
//  RecipeDetailSplitContent.swift
//  OpenCookbook
//
//  Side-by-side ingredients (25%) and instructions (75%) for iPad
//

import MarkdownUI
import RecipeMD
import SwiftUI

/// Displays ingredients and instructions side-by-side for iPad
/// - Ingredients panel: 33% width, independently scrollable
/// - Instructions panel: 67% width, independently scrollable
struct RecipeDetailSplitContent: View {
    let ingredientGroups: [IngredientGroup]
    let instructions: String?
    let yield: Yield
    @Binding var selectedPortion: PortionOption

    /// Proportion of width for ingredients panel
    private let ingredientsProportion: CGFloat = 0.33

    @AppStorage("autoNumberInstructions") private var autoNumberInstructions = true
    private let instructionsFormatter = InstructionsFormatter()

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
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Yield and portion selector on same line
            HStack {
                // Scaled yield (left-aligned)
                let scaledYield = yield.formattedScaled(by: selectedPortion.multiplier)
                if !scaledYield.isEmpty {
                    Text(scaledYield)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Portion picker (right-aligned, no label)
                Picker("Portion size", selection: $selectedPortion) {
                    ForEach(PortionOption.allOptions) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Portion size")
                .accessibilityHint("Select portion multiplier for ingredient quantities")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Scrollable ingredients list
            ScrollView {
                IngredientsListView(
                    ingredientGroups: ingredientGroups,
                    portionMultiplier: selectedPortion.multiplier
                )
                .padding(16)
            }
        }
        .background(Color(.secondarySystemBackground).opacity(0.3))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ingredients")
    }

    // MARK: - Instructions Panel

    private var instructionsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                Text("Instructions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 12)

                if let instructions = instructions, !instructions.isEmpty {
                    let displayInstructions = autoNumberInstructions
                        ? instructionsFormatter.format(instructions)
                        : instructions
                    Markdown(displayInstructions)
                        .markdownTheme(.recipe)
                } else {
                    Text("No instructions provided")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Instructions")
    }
}

// MARK: - Previews

#Preview("Split Content") {
    struct PreviewWrapper: View {
        @State private var portion = PortionOption.whole

        var body: some View {
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
                """,
                yield: Yield(amount: [Amount(24, unit: "cookies")]),
                selectedPortion: $portion
            )
            .frame(height: 500)
        }
    }
    return PreviewWrapper()
}

#Preview("No Instructions") {
    struct PreviewWrapper: View {
        @State private var portion = PortionOption.whole

        var body: some View {
            RecipeDetailSplitContent(
                ingredientGroups: [
                    IngredientGroup(ingredients: [
                        Ingredient(name: "ingredient 1", amount: Amount(1, unit: "cup")),
                        Ingredient(name: "ingredient 2", amount: Amount(2, unit: "tbsp"))
                    ])
                ],
                instructions: nil,
                yield: Yield(amount: [Amount(4, unit: "servings")]),
                selectedPortion: $portion
            )
            .frame(height: 400)
        }
    }
    return PreviewWrapper()
}
