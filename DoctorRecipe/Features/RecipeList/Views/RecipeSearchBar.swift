//
//  RecipeSearchBar.swift
//  DoctorRecipe
//
//  Search bar component for recipe filtering
//

import SwiftUI

/// Search bar for filtering recipes
struct RecipeSearchBar: View {

    // MARK: - Properties

    @Binding var text: String
    var onClear: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search recipes...", text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Previews

#Preview("Empty") {
    RecipeSearchBar(text: .constant(""), onClear: {})
        .padding()
}

#Preview("With Text") {
    RecipeSearchBar(text: .constant("chocolate"), onClear: {})
        .padding()
}
