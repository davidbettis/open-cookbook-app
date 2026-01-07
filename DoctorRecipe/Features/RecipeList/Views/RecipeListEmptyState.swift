//
//  RecipeListEmptyState.swift
//  DoctorRecipe
//
//  Empty state view for recipe list
//

import SwiftUI

/// Empty state view shown when there are no recipes
struct RecipeListEmptyState: View {

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Recipes Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("Add .md recipe files to your selected folder to see them here")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No recipes. Add recipe files to your selected folder to see them here.")
    }
}

// MARK: - Previews

#Preview {
    RecipeListEmptyState()
}

#Preview("In Navigation Stack") {
    NavigationStack {
        RecipeListEmptyState()
            .navigationTitle("Recipes")
    }
}
