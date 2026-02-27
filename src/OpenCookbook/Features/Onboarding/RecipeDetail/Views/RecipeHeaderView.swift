//
//  RecipeHeaderView.swift
//  OpenCookbook
//
//  Displays recipe header content (title, description, tags, yields)
//

import RecipeMD
import SwiftUI

/// Displays recipe header content (title, description, tags, yields)
struct RecipeHeaderView: View {
    let title: String
    let description: String?
    let tags: [String]
    let yield: Yield
    var portionMultiplier: Double = 1.0

    @AppStorage("amountDisplayFormat") private var amountDisplayFormatRaw: String = AmountDisplayFormat.original.rawValue

    private var amountFormat: AmountDisplayFormat {
        AmountDisplayFormat(rawValue: amountDisplayFormatRaw) ?? .original
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            // Description
            if let description = description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            // Tags
            if !tags.isEmpty {
                TagsView(tags: tags)
            }

            // Yields (scaled by portion multiplier)
            let scaledYield = yield.formattedScaled(by: portionMultiplier, format: amountFormat)
            if !scaledYield.isEmpty {
                YieldView(yieldText: scaledYield)
            }
        }
    }
}

// MARK: - Tags View

/// Displays tags as styled pills/chips
private struct TagsView: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tags: \(tags.joined(separator: ", "))")
    }
}

// MARK: - Yield View

/// Displays yield information prominently
private struct YieldView: View {
    let yieldText: String

    var body: some View {
        Text(yieldText)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Yield: \(yieldText)")
    }
}

// MARK: - Flow Layout

// FlowLayout is defined in TagPickerView.swift and shared across the app

// MARK: - Previews

#Preview("Full Header") {
    RecipeHeaderView(
        title: "Chocolate Chip Cookies",
        description: "Classic homemade chocolate chip cookies with a chewy center and crispy edges.",
        tags: ["dessert", "baking", "quick", "family favorite"],
        yield: Yield(amount: [Amount(24, unit: "cookies")])
    )
    .padding()
}

#Preview("Minimal Header") {
    RecipeHeaderView(
        title: "Simple Toast",
        description: nil,
        tags: [],
        yield: Yield(amount: [])
    )
    .padding()
}

#Preview("No Description") {
    RecipeHeaderView(
        title: "Quick Pasta",
        description: nil,
        tags: ["dinner", "quick"],
        yield: Yield(amount: [Amount(4, unit: "servings")])
    )
    .padding()
}
