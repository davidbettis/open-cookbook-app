//
//  RecipeErrorCard.swift
//  DoctorRecipe
//
//  Error card for displaying parse errors
//

import SwiftUI

/// Card view for displaying recipe parse errors
struct RecipeErrorCard: View {

    // MARK: - Properties

    let fileURL: URL
    let error: Error

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Parse Error")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(fileURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Show error details")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Parse error for \(fileURL.lastPathComponent). Tap for details.")
    }
}

// MARK: - Previews

#Preview {
    VStack {
        RecipeErrorCard(
            fileURL: URL(fileURLWithPath: "/tmp/broken_recipe.md"),
            error: RecipeParseError.missingTitle
        )

        RecipeErrorCard(
            fileURL: URL(fileURLWithPath: "/tmp/invalid_format.md"),
            error: RecipeParseError.invalidFormat(reason: "Unable to parse markdown")
        )
    }
    .padding()
}
