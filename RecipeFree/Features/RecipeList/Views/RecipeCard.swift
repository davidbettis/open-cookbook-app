//
//  RecipeCard.swift
//  RecipeFree
//
//  Card component for displaying recipe in list
//

import SwiftUI
import RecipeMD

/// Card view component for displaying a recipe in the list
struct RecipeCard: View {

    // MARK: - Properties

    let recipeFile: RecipeFile

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(recipeFile.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            // Primary tag chip
            if let tag = recipeFile.primaryTag {
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Description preview
            if let description = recipeFile.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = "Recipe: \(recipeFile.title)"

        if let tag = recipeFile.primaryTag {
            label += ", Category: \(tag)"
        }

        if let description = recipeFile.description {
            label += ", \(description)"
        }

        return label
    }
}

// MARK: - Previews

#Preview("Basic Recipe") {
    RecipeCard(recipeFile: RecipeFile(
        filePath: URL(fileURLWithPath: "/tmp/test.md"),
        recipe: Recipe(
            title: "Chocolate Chip Cookies",
            description: "Classic homemade cookies",
            tags: ["dessert", "baking"]
        )
    ))
    .padding()
}

#Preview("No Description") {
    RecipeCard(recipeFile: RecipeFile(
        filePath: URL(fileURLWithPath: "/tmp/test.md"),
        recipe: Recipe(
            title: "Simple Pasta",
            tags: ["dinner", "italian"]
        )
    ))
    .padding()
}

#Preview("No Tags") {
    RecipeCard(recipeFile: RecipeFile(
        filePath: URL(fileURLWithPath: "/tmp/test.md"),
        recipe: Recipe(
            title: "Minimal Recipe",
            description: "A very simple recipe"
        )
    ))
    .padding()
}

#Preview("Long Title") {
    RecipeCard(recipeFile: RecipeFile(
        filePath: URL(fileURLWithPath: "/tmp/test.md"),
        recipe: Recipe(
            title: "Super Delicious Extra Long Recipe Title That Should Truncate",
            description: "This is a recipe with a very long title to test truncation",
            tags: ["test"]
        )
    ))
    .padding()
}
