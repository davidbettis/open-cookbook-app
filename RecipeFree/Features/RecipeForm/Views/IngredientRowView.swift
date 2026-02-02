//
//  IngredientRowView.swift
//  RecipeFree
//
//  A single ingredient row in the recipe form
//

import SwiftUI

/// Identifies which field is focused within an ingredient row
enum IngredientField: Hashable {
    case amount(UUID)
    case name(UUID)
}

/// A row for entering a single ingredient with amount and name fields
struct IngredientRowView: View {
    @Binding var ingredient: EditableIngredient
    let isLastRow: Bool
    let focusedField: FocusState<IngredientField?>.Binding
    let onDelete: () -> Void
    let onTabFromName: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Amount field (narrow)
            TextField("Amount", text: $ingredient.amount)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .frame(width: 100)
                .focused(focusedField, equals: .amount(ingredient.id))
                .accessibilityLabel("Ingredient amount")
                .accessibilityHint("Enter quantity and unit, like 2 cups")
                .onSubmit {
                    focusedField.wrappedValue = .name(ingredient.id)
                }
                .onKeyPress(.tab) {
                    focusedField.wrappedValue = .name(ingredient.id)
                    return .handled
                }

            // Name field (wide)
            TextField("Ingredient name", text: $ingredient.name)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .focused(focusedField, equals: .name(ingredient.id))
                .accessibilityLabel("Ingredient name")
                .accessibilityHint("Enter the ingredient name")
                .onSubmit {
                    onTabFromName()
                }
                .onKeyPress(.tab) {
                    onTabFromName()
                    return .handled
                }

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
    @Previewable @FocusState var focus: IngredientField?
    IngredientRowView(
        ingredient: .constant(EditableIngredient()),
        isLastRow: true,
        focusedField: $focus,
        onDelete: {},
        onTabFromName: {}
    )
    .padding()
}

#Preview("Filled Row") {
    @Previewable @FocusState var focus: IngredientField?
    IngredientRowView(
        ingredient: .constant(EditableIngredient(
            amount: "2 cups",
            name: "all-purpose flour"
        )),
        isLastRow: false,
        focusedField: $focus,
        onDelete: {},
        onTabFromName: {}
    )
    .padding()
}
