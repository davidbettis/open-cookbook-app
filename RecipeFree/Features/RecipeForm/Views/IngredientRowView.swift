//
//  IngredientRowView.swift
//  RecipeFree
//
//  A single ingredient row in the recipe form
//

import SwiftUI

/// A row for entering a single ingredient with amount and name fields
struct IngredientRowView: View {
    @Binding var ingredient: EditableIngredient
    let onDelete: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case amount
        case name
    }

    var body: some View {
        HStack(spacing: 12) {
            // Amount field (narrow)
            TextField("Amount", text: $ingredient.amount)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .focused($focusedField, equals: .amount)
                .accessibilityLabel("Ingredient amount")
                .accessibilityHint("Enter quantity and unit, like 2 cups")
                .onSubmit {
                    focusedField = .name
                }

            // Name field (wide)
            TextField("Ingredient name", text: $ingredient.name)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .accessibilityLabel("Ingredient name")
                .accessibilityHint("Enter the ingredient name")

            // Delete button
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove ingredient")
        }
    }
}

// MARK: - Previews

#Preview("Empty Row") {
    IngredientRowView(
        ingredient: .constant(EditableIngredient()),
        onDelete: {}
    )
    .padding()
}

#Preview("Filled Row") {
    IngredientRowView(
        ingredient: .constant(EditableIngredient(
            amount: "2 cups",
            name: "all-purpose flour"
        )),
        onDelete: {}
    )
    .padding()
}
