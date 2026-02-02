//
//  RecipeFormViewModel.swift
//  RecipeFree
//
//  ViewModel for the recipe add/edit form
//

import Foundation
import RecipeMD

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

    /// Create from a library Ingredient model
    init(from ingredient: Ingredient) {
        self.id = UUID()
        self.name = ingredient.name

        // Format amount from library Amount type
        if let amt = ingredient.amount {
            self.amount = amt.formatted
        } else {
            self.amount = ""
        }
    }

    /// Convert to library Ingredient model
    func toIngredient() -> Ingredient {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedAmount = amount.trimmingCharacters(in: .whitespaces)

        if trimmedAmount.isEmpty {
            return Ingredient(name: trimmedName)
        }

        // Parse amount string into Amount
        let parsedAmount = parseAmount(trimmedAmount)
        return Ingredient(name: trimmedName, amount: parsedAmount)
    }

    /// Parse amount string into library Amount type
    private func parseAmount(_ amountString: String) -> Amount? {
        guard !amountString.isEmpty else { return nil }

        let parts = amountString.split(separator: " ", maxSplits: 1)

        if parts.count >= 2 {
            // Has both quantity and unit
            let quantityStr = String(parts[0])
            let unit = String(parts[1])

            if let quantity = parseQuantity(quantityStr) {
                return Amount(quantity, unit: unit)
            } else {
                // Treat whole string as rawText
                return Amount(amount: 0, unit: nil, rawText: amountString)
            }
        } else if parts.count == 1 {
            let firstPart = String(parts[0])
            if let quantity = parseQuantity(firstPart) {
                return Amount(quantity, unit: nil)
            } else {
                // Might be just a unit like "pinch"
                return Amount(amount: 0, unit: firstPart, rawText: firstPart)
            }
        }

        return nil
    }

    /// Parse a quantity string (handles fractions)
    private func parseQuantity(_ str: String) -> Double? {
        // Handle fractions like "1/2"
        if str.contains("/") {
            let fractionParts = str.split(separator: "/")
            if fractionParts.count == 2,
               let numerator = Double(fractionParts[0]),
               let denominator = Double(fractionParts[1]),
               denominator != 0 {
                return numerator / denominator
            }
        }
        // Handle mixed numbers like "1 1/2" - already split, so just parse
        return Double(str)
    }

    /// Check if this ingredient has valid content
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Mode for the recipe form
enum RecipeFormMode: Equatable {
    case add
    case edit(RecipeFile)

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

    /// Original recipe file for edit mode (to detect changes)
    private var originalRecipeFile: RecipeFile?

    /// Initial form state for change detection
    private var initialState: FormState?

    // MARK: - Initialization

    init(mode: RecipeFormMode = .add) {
        self.mode = mode

        if case .edit(let recipeFile) = mode {
            self.originalRecipeFile = recipeFile
            populateFromRecipeFile(recipeFile)
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

    /// Add a new empty ingredient row and return its ID
    @discardableResult
    func addIngredient() -> UUID {
        let newIngredient = EditableIngredient()
        ingredients.append(newIngredient)
        return newIngredient.id
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

    /// Check if the file was modified externally since we loaded it
    /// - Returns: true if the file was modified externally
    func checkForExternalModification() -> Bool {
        guard case .edit(let originalFile) = mode,
              let originalDate = originalFile.fileModifiedDate else {
            return false
        }

        let fileURL = originalFile.filePath

        // Start accessing security-scoped resource if needed
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Get current file modification date
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let currentDate = attributes[.modificationDate] as? Date else {
            return false
        }

        // Compare dates (allow 1 second tolerance for filesystem precision)
        return abs(currentDate.timeIntervalSince(originalDate)) > 1.0
    }

    /// Save the recipe
    /// - Parameters:
    ///   - folder: The folder to save in (for new recipes)
    ///   - store: The recipe store
    ///   - forceOverwrite: If true, skip conflict check and overwrite
    /// - Returns: The saved recipe file
    func save(to folder: URL, using store: RecipeStore, forceOverwrite: Bool = false) async throws -> RecipeFile {
        guard validate() else {
            throw RecipeWriteError.serializationError
        }

        // Check for external modifications in edit mode (unless force overwrite)
        if !forceOverwrite && checkForExternalModification() {
            throw RecipeWriteError.fileModifiedExternally
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let recipeFile = buildRecipeFile()

        do {
            let savedRecipeFile: RecipeFile
            switch mode {
            case .add:
                savedRecipeFile = try await store.saveNewRecipe(recipeFile, in: folder)
            case .edit:
                try await store.updateRecipe(recipeFile)
                savedRecipeFile = recipeFile
            }
            return savedRecipeFile
        } catch {
            saveError = error
            throw error
        }
    }

    // MARK: - Private Methods

    /// Populate form fields from an existing recipe file
    private func populateFromRecipeFile(_ recipeFile: RecipeFile) {
        let recipe = recipeFile.recipe

        title = recipe.title
        descriptionText = recipe.description ?? ""
        tagsText = recipe.tags.joined(separator: ", ")
        instructions = recipe.instructions ?? ""

        // Format yields from Yield type
        yieldsText = recipe.yield.formatted

        // Convert ingredients from all groups
        let allIngredients = recipe.ingredientGroups.flatMap { $0.allIngredients }
        if allIngredients.isEmpty {
            ingredients = [EditableIngredient()]
        } else {
            ingredients = allIngredients.map { EditableIngredient(from: $0) }
        }
    }

    /// Build a RecipeFile from the current form state
    private func buildRecipeFile() -> RecipeFile {
        // Parse tags from comma-separated string
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Parse yields from comma-separated string into Yield type
        let yieldAmounts = yieldsText
            .split(separator: ",")
            .compactMap { yieldStr -> Amount? in
                let trimmed = yieldStr.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                return parseYieldAmount(trimmed)
            }
        let yield = Yield(amount: yieldAmounts)

        // Convert editable ingredients to library Ingredient models
        let recipeIngredients = ingredients
            .filter { $0.isValid }
            .map { $0.toIngredient() }

        // Create a single ingredient group with all ingredients
        let ingredientGroup = IngredientGroup(ingredients: recipeIngredients)

        // Build the library Recipe
        let recipe = Recipe(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.isEmpty ? nil : descriptionText,
            tags: tags,
            yield: yield,
            ingredientGroups: [ingredientGroup],
            instructions: instructions.isEmpty ? nil : instructions
        )

        // Get file path from original recipe or use placeholder
        let filePath: URL
        if case .edit(let originalFile) = mode {
            filePath = originalFile.filePath
        } else {
            // Placeholder - will be replaced by RecipeStore.saveNewRecipe
            filePath = URL(fileURLWithPath: "/tmp/placeholder.md")
        }

        // Get ID from original recipe or generate new
        let id: UUID
        if case .edit(let originalFile) = mode {
            id = originalFile.id
        } else {
            id = UUID()
        }

        return RecipeFile(
            id: id,
            filePath: filePath,
            recipe: recipe,
            fileModifiedDate: Date()
        )
    }

    /// Parse a yield amount string (e.g., "4 servings", "2 loaves")
    private func parseYieldAmount(_ str: String) -> Amount {
        let parts = str.split(separator: " ", maxSplits: 1)

        if parts.count >= 2 {
            let quantityStr = String(parts[0])
            let unit = String(parts[1])

            if let quantity = Double(quantityStr) {
                return Amount(quantity, unit: unit)
            }
        } else if parts.count == 1 {
            let firstPart = String(parts[0])
            if let quantity = Double(firstPart) {
                return Amount(quantity, unit: nil)
            }
        }

        // Fall back to raw text
        return Amount(amount: 0, unit: nil, rawText: str)
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
