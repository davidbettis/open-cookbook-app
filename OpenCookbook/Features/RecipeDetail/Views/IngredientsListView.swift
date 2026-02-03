//
//  IngredientsListView.swift
//  OpenCookbook
//
//  Displays ingredient groups from RecipeMD parsed data
//

import RecipeMD
import SwiftUI

/// Renders ingredient groups as a styled list matching the MarkdownUI recipe theme
struct IngredientsListView: View {
    let ingredientGroups: [IngredientGroup]
    var portionMultiplier: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(ingredientGroups.enumerated()), id: \.offset) { _, group in
                IngredientGroupView(group: group, portionMultiplier: portionMultiplier)
            }
        }
    }
}

// MARK: - Ingredient Group View

/// Renders a single ingredient group with optional title
private struct IngredientGroupView: View {
    let group: IngredientGroup
    var portionMultiplier: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group title (if present)
            if let title = group.title, !title.isEmpty {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }

            // Ingredients in this group
            ForEach(Array(group.ingredients.enumerated()), id: \.offset) { _, ingredient in
                IngredientRowDisplayView(ingredient: ingredient, portionMultiplier: portionMultiplier)
            }
        }
    }
}

// MARK: - Ingredient Row Display View

/// Displays a single ingredient with amount and name in uniform format
private struct IngredientRowDisplayView: View {
    let ingredient: Ingredient
    var portionMultiplier: Double = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Bullet point
            Text("•")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            // Amount and name on single line with uniform styling
            Text(displayText)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayText)
    }

    private var displayText: String {
        if let amount = ingredient.amount {
            let scaledAmount = amount.formattedScaled(by: portionMultiplier)
            return "\(scaledAmount) \(ingredient.name)"
        }
        return ingredient.name
    }
}

// MARK: - Previews

#Preview("Simple Ingredients") {
    IngredientsListView(
        ingredientGroups: [
            IngredientGroup(ingredients: [
                Ingredient(name: "all-purpose flour", amount: Amount(2.25, unit: "cups")),
                Ingredient(name: "baking soda", amount: Amount(1, unit: "tsp")),
                Ingredient(name: "butter, softened", amount: Amount(1, unit: "cup")),
                Ingredient(name: "chocolate chips", amount: Amount(2, unit: "cups"))
            ])
        ]
    )
    .padding()
}

#Preview("Grouped Ingredients") {
    IngredientsListView(
        ingredientGroups: [
            IngredientGroup(
                title: "For the Dough",
                ingredients: [
                    Ingredient(name: "all-purpose flour", amount: Amount(2, unit: "cups")),
                    Ingredient(name: "salt", amount: Amount(1, unit: "tsp"))
                ]
            ),
            IngredientGroup(
                title: "For the Filling",
                ingredients: [
                    Ingredient(name: "cream cheese", amount: Amount(1, unit: "cup")),
                    Ingredient(name: "sugar", amount: Amount(2, unit: "tbsp"))
                ]
            )
        ]
    )
    .padding()
}

#Preview("No Amounts") {
    IngredientsListView(
        ingredientGroups: [
            IngredientGroup(ingredients: [
                Ingredient(name: "salt"),
                Ingredient(name: "pepper"),
                Ingredient(name: "olive oil")
            ])
        ]
    )
    .padding()
}
