//
//  Ingredient.swift
//  DoctorRecipe
//
//  Models for representing recipe ingredients
//

import Foundation

/// Represents a single ingredient in a recipe
struct Ingredient: Identifiable, Hashable, Codable {
    /// Unique identifier
    let id: UUID

    /// Quantity of the ingredient (e.g., "2", "1/2")
    var quantity: String?

    /// Unit of measurement (e.g., "cup", "tablespoon", "kg")
    var unit: String?

    /// Name of the ingredient (e.g., "flour", "sugar", "chicken breast")
    var name: String

    /// Optional preparation notes (e.g., "chopped", "diced", "at room temperature")
    var preparation: String?

    /// Initialize with all properties
    init(
        id: UUID = UUID(),
        quantity: String? = nil,
        unit: String? = nil,
        name: String,
        preparation: String? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.unit = unit
        self.name = name
        self.preparation = preparation
    }

    /// Full ingredient text for display
    var displayText: String {
        var parts: [String] = []

        if let quantity = quantity {
            parts.append(quantity)
        }

        if let unit = unit {
            parts.append(unit)
        }

        parts.append(name)

        if let preparation = preparation {
            parts.append("(\(preparation))")
        }

        return parts.joined(separator: " ")
    }
}

/// Represents a group of ingredients (e.g., "For the dough", "For the sauce")
struct IngredientGroup: Identifiable, Hashable, Codable {
    /// Unique identifier
    let id: UUID

    /// Name of the group (e.g., "For the dough", "Marinade")
    var name: String?

    /// Ingredients in this group
    var ingredients: [Ingredient]

    /// Initialize with all properties
    init(
        id: UUID = UUID(),
        name: String? = nil,
        ingredients: [Ingredient] = []
    ) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
    }
}
