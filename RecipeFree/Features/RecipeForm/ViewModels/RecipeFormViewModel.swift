//
//  RecipeFormViewModel.swift
//  RecipeFree
//
//  ViewModel for the recipe add/edit form
//

import Foundation

/// Represents an editable ingredient in the form
struct EditableIngredient: Identifiable {
    let id: UUID
    var amount: String  // Combined quantity + unit (e.g., "2 cups")
    var name: String

    init(id: UUID = UUID(), amount: String = "", name: String = "") {
        self.id = id
        self.amount = amount
        self.name = name
    }

    /// Create from an Ingredient model
    init(from ingredient: Ingredient) {
        self.id = ingredient.id
        self.name = ingredient.name

        // Combine quantity and unit into amount string
        var amountParts: [String] = []
        if let quantity = ingredient.quantity, !quantity.isEmpty {
            amountParts.append(quantity)
        }
        if let unit = ingredient.unit, !unit.isEmpty {
            amountParts.append(unit)
        }
        self.amount = amountParts.joined(separator: " ")
    }

    /// Convert to Ingredient model
    func toIngredient() -> Ingredient {
        // Parse amount into quantity and unit
        let parts = amount.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)

        let quantity: String?
        let unit: String?

        if parts.count >= 2 {
            quantity = String(parts[0])
            unit = String(parts[1])
        } else if parts.count == 1 {
            // Check if it's a number or unit
            let firstPart = String(parts[0])
            if firstPart.first?.isNumber == true || firstPart.contains("/") {
                quantity = firstPart
                unit = nil
            } else {
                quantity = nil
                unit = firstPart
            }
        } else {
            quantity = nil
            unit = nil
        }

        return Ingredient(
            id: id,
            quantity: quantity,
            unit: unit,
            name: name.trimmingCharacters(in: .whitespaces)
        )
    }

    /// Check if this ingredient has valid content
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Mode for the recipe form
enum RecipeFormMode: Equatable {
    case add
    case edit(Recipe)

    static func == (lhs: RecipeFormMode, rhs: RecipeFormMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add):
            return true
        case (.edit(let r1), .edit(let r2)):
            return r1.id == r2.id
        default:
            return false
        }
    }
}

/// Validation error for recipe form
struct RecipeValidationError: Identifiable {
    let id = UUID()
    let field: String
    let message: String
}

/// ViewModel for recipe add/edit form
@MainActor
@Observable
class RecipeFormViewModel {

    // MARK: - Form Fields

    var title: String = ""
    var descriptionText: String = ""
    var tagsText: String = ""
    var yieldsText: String = ""
    var ingredients: [EditableIngredient] = [EditableIngredient()]
    var instructions: String = ""

    // MARK: - State

    var mode: RecipeFormMode
    var isSaving = false
    var saveError: Error?
    var validationErrors: [RecipeValidationError] = []

    /// Original recipe for edit mode (to detect changes)
    private var originalRecipe: Recipe?

    /// Initial form state for change detection
    private var initialState: FormState?

    // MARK: - Initialization

    init(mode: RecipeFormMode = .add) {
        self.mode = mode

        if case .edit(let recipe) = mode {
            self.originalRecipe = recipe
            populateFromRecipe(recipe)
        }

        // Capture initial state after population
        self.initialState = currentState
    }

    // MARK: - Computed Properties

    /// Check if form has unsaved changes
    var hasUnsavedChanges: Bool {
        guard let initial = initialState else { return false }
        return currentState != initial
    }

    /// Check if form is valid
    var isValid: Bool {
        validate()
        return validationErrors.isEmpty
    }

    /// Navigation title based on mode
    var navigationTitle: String {
        switch mode {
        case .add:
            return "New Recipe"
        case .edit:
            return "Edit Recipe"
        }
    }

    /// Save button text based on mode
    var saveButtonText: String {
        switch mode {
        case .add:
            return "Save"
        case .edit:
            return "Save Changes"
        }
    }

    /// Check if title field has error
    var titleHasError: Bool {
        validationErrors.contains { $0.field == "title" }
    }

    /// Check if ingredients field has error
    var ingredientsHasError: Bool {
        validationErrors.contains { $0.field == "ingredients" }
    }

    // MARK: - Public Methods

    /// Add a new empty ingredient row
    func addIngredient() {
        ingredients.append(EditableIngredient())
    }

    /// Remove ingredient at index
    func removeIngredient(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
        // Ensure at least one ingredient row
        if ingredients.isEmpty {
            ingredients.append(EditableIngredient())
        }
    }

    /// Validate the form and update validationErrors
    @discardableResult
    func validate() -> Bool {
        validationErrors = []

        // Title validation
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            validationErrors.append(RecipeValidationError(
                field: "title",
                message: "Title is required"
            ))
        } else if trimmedTitle.count > 200 {
            validationErrors.append(RecipeValidationError(
                field: "title",
                message: "Title must be less than 200 characters"
            ))
        }

        // Ingredients validation
        let validIngredients = ingredients.filter { $0.isValid }
        if validIngredients.isEmpty {
            validationErrors.append(RecipeValidationError(
                field: "ingredients",
                message: "At least one ingredient is required"
            ))
        }

        return validationErrors.isEmpty
    }

    /// Save the recipe
    /// - Parameters:
    ///   - folder: The folder to save in (for new recipes)
    ///   - store: The recipe store
    /// - Returns: The saved recipe
    func save(to folder: URL, using store: RecipeStore) async throws -> Recipe {
        guard validate() else {
            throw RecipeWriteError.serializationError
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let recipe = buildRecipe()

        do {
            let savedRecipe: Recipe
            switch mode {
            case .add:
                savedRecipe = try await store.saveNewRecipe(recipe, in: folder)
            case .edit:
                try await store.updateRecipe(recipe)
                savedRecipe = recipe
            }
            return savedRecipe
        } catch {
            saveError = error
            throw error
        }
    }

    // MARK: - Private Methods

    /// Populate form fields from an existing recipe
    private func populateFromRecipe(_ recipe: Recipe) {
        title = recipe.title
        descriptionText = recipe.description ?? ""
        tagsText = recipe.tags.joined(separator: ", ")
        yieldsText = recipe.yields.joined(separator: ", ")
        instructions = recipe.instructions ?? ""

        // Convert ingredients
        let allIngredients = recipe.ingredients + recipe.ingredientGroups.flatMap { $0.ingredients }
        if allIngredients.isEmpty {
            ingredients = [EditableIngredient()]
        } else {
            ingredients = allIngredients.map { EditableIngredient(from: $0) }
        }
    }

    /// Build a Recipe from the current form state
    private func buildRecipe() -> Recipe {
        // Parse tags from comma-separated string
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Parse yields from comma-separated string
        let yields = yieldsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Convert editable ingredients to Ingredient models
        let recipeIngredients = ingredients
            .filter { $0.isValid }
            .map { $0.toIngredient() }

        // Get file path from original recipe or use placeholder
        let filePath: URL
        if case .edit(let recipe) = mode {
            filePath = recipe.filePath
        } else {
            // Placeholder - will be replaced by RecipeStore.saveNewRecipe
            filePath = URL(fileURLWithPath: "/tmp/placeholder.md")
        }

        // Get ID from original recipe or generate new
        let id: UUID
        if case .edit(let recipe) = mode {
            id = recipe.id
        } else {
            id = UUID()
        }

        return Recipe(
            id: id,
            filePath: filePath,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.isEmpty ? nil : descriptionText,
            tags: tags,
            yields: yields,
            ingredients: recipeIngredients,
            ingredientGroups: [],  // v1.0: flat list only
            instructions: instructions.isEmpty ? nil : instructions
        )
    }

    /// Current form state for change detection
    private var currentState: FormState {
        FormState(
            title: title,
            description: descriptionText,
            tags: tagsText,
            yields: yieldsText,
            ingredients: ingredients.map { "\($0.amount)|\($0.name)" },
            instructions: instructions
        )
    }

    /// Form state struct for change detection
    private struct FormState: Equatable {
        let title: String
        let description: String
        let tags: String
        let yields: String
        let ingredients: [String]
        let instructions: String
    }
}
