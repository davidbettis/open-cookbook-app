//
//  RecipeMDSerializer.swift
//  DoctorRecipe
//
//  Serializes Recipe models to RecipeMD markdown format
//

import Foundation

/// Serializes Recipe models to valid RecipeMD markdown format
/// Following RecipeMD v2.4.0 specification
final class RecipeMDSerializer {

    // MARK: - Public Methods

    /// Serialize a Recipe to RecipeMD markdown format
    /// - Parameter recipe: The recipe to serialize
    /// - Returns: Valid RecipeMD markdown string
    func serialize(_ recipe: Recipe) -> String {
        var lines: [String] = []

        // Title (required) - H1 heading
        lines.append("# \(recipe.title)")
        lines.append("")

        // Description (optional) - plain paragraph
        if let description = recipe.description, !description.isEmpty {
            lines.append(description)
            lines.append("")
        }

        // Tags (optional) - italic text
        if !recipe.tags.isEmpty {
            let tagsText = recipe.tags.joined(separator: ", ")
            lines.append("*\(tagsText)*")
            lines.append("")
        }

        // Yields (optional) - bold text
        if !recipe.yields.isEmpty {
            let yieldsText = recipe.yields.joined(separator: ", ")
            lines.append("**\(yieldsText)**")
            lines.append("")
        }

        // Horizontal rule before ingredients
        lines.append("---")
        lines.append("")

        // Ingredient groups (if any)
        for group in recipe.ingredientGroups {
            if let groupName = group.name, !groupName.isEmpty {
                lines.append("## \(groupName)")
                lines.append("")
            }
            for ingredient in group.ingredients {
                lines.append(serializeIngredient(ingredient))
            }
            lines.append("")
        }

        // Ungrouped ingredients
        for ingredient in recipe.ingredients {
            lines.append(serializeIngredient(ingredient))
        }

        // Instructions (optional)
        if let instructions = recipe.instructions, !instructions.isEmpty {
            lines.append("")
            lines.append("---")
            lines.append("")
            lines.append(instructions)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Methods

    /// Serialize a single ingredient to markdown list item
    /// - Parameter ingredient: The ingredient to serialize
    /// - Returns: Markdown list item string
    private func serializeIngredient(_ ingredient: Ingredient) -> String {
        var parts: [String] = []

        // Build amount string from quantity and unit
        let amount = buildAmountString(ingredient)
        if !amount.isEmpty {
            parts.append("*\(amount)*")
        }

        // Add ingredient name
        parts.append(ingredient.name)

        // Add preparation notes if present
        if let preparation = ingredient.preparation, !preparation.isEmpty {
            parts.append("(\(preparation))")
        }

        return "- \(parts.joined(separator: " "))"
    }

    /// Build the amount string from quantity and unit
    /// - Parameter ingredient: The ingredient
    /// - Returns: Combined amount string (e.g., "2 cups")
    private func buildAmountString(_ ingredient: Ingredient) -> String {
        var amountParts: [String] = []

        if let quantity = ingredient.quantity, !quantity.isEmpty {
            amountParts.append(quantity)
        }

        if let unit = ingredient.unit, !unit.isEmpty {
            amountParts.append(unit)
        }

        return amountParts.joined(separator: " ")
    }
}
