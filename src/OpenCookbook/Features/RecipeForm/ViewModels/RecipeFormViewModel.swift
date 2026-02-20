//
//  RecipeFormViewModel.swift
//  OpenCookbook
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
        if let parsedAmount = parseAmount(trimmedAmount) {
            return Ingredient(name: trimmedName, amount: parsedAmount)
        }

        // Non-numeric amount text (e.g., "pinch") — fold into ingredient name
        return Ingredient(name: "\(trimmedAmount) \(trimmedName)")
    }

    /// Parse amount string into library Amount type.
    /// Returns nil if the text cannot be parsed as a numeric amount.
    private func parseAmount(_ amountString: String) -> Amount? {
        guard !amountString.isEmpty else { return nil }

        let parts = amountString.split(separator: " ", maxSplits: 1)

        if parts.count >= 2 {
            // Has both quantity and unit (e.g., "2 cups")
            let quantityStr = String(parts[0])
            let unit = String(parts[1])

            if let quantity = parseQuantity(quantityStr) {
                return Amount(quantity, unit: unit)
            }
            return nil
        } else if parts.count == 1 {
            let firstPart = String(parts[0])
            if let quantity = parseQuantity(firstPart) {
                return Amount(quantity, unit: nil)
            }
            return nil
        }

        return nil
    }

    /// Parse a quantity string (handles fractions and unicode fractions)
    private func parseQuantity(_ str: String) -> Double? {
        // Handle single unicode fraction like "½"
        if str.count == 1, let first = str.first, let value = UnicodeFractions.value(for: first) {
            return value
        }

        // Handle mixed number with unicode fraction like "1½"
        if let last = str.last, let fractionValue = UnicodeFractions.value(for: last) {
            let wholeStr = String(str.dropLast())
            if let whole = Double(wholeStr) {
                return whole + fractionValue
            }
        }

        // Handle ASCII fractions like "1/2"
        if str.contains("/") {
            let fractionParts = str.split(separator: "/")
            if fractionParts.count == 2,
               let numerator = Double(fractionParts[0]),
               let denominator = Double(fractionParts[1]),
               denominator != 0 {
                return numerator / denominator
            }
        }
        // Handle integers and decimals
        return Double(str)
    }

    /// Check if this ingredient has valid content
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Represents an editable ingredient group in the form
struct EditableIngredientGroup: Identifiable {
    let id: UUID
    var title: String
    var ingredients: [EditableIngredient]

    init(id: UUID = UUID(), title: String = "", ingredients: [EditableIngredient] = [EditableIngredient()]) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
    }

    /// Check if this group has at least one valid ingredient
    var hasValidIngredients: Bool {
        ingredients.contains { $0.isValid }
    }
}

/// Represents an editable instruction group in the form
struct EditableInstructionGroup: Identifiable {
    let id: UUID
    var title: String    // empty string for ungrouped
    var text: String     // the instruction content

    var isUngrouped: Bool { title.isEmpty }

    init(id: UUID = UUID(), title: String = "", text: String = "") {
        self.id = id
        self.title = title
        self.text = text
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
    var ingredientGroups: [EditableIngredientGroup] = []
    var instructionGroups: [EditableInstructionGroup] = [EditableInstructionGroup()]

    // MARK: - State

    var mode: RecipeFormMode
    var isSaving = false
    var saveError: Error?
    var validationErrors: [RecipeValidationError] = []

    // MARK: - Markdown Mode State

    /// Raw markdown content when in markdown editing mode
    var rawMarkdown: String = ""

    /// Snapshot of markdown when entering markdown mode (for change detection)
    private var initialMarkdown: String?

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

    /// Check if any ingredient group title has error
    var groupTitleHasError: Bool {
        validationErrors.contains { $0.field == "groupTitle" }
    }

    /// Check if any instruction group title has error
    var instructionGroupTitleHasError: Bool {
        validationErrors.contains { $0.field == "instructionGroupTitle" }
    }

    /// Check if markdown has unsaved changes
    var hasUnsavedMarkdownChanges: Bool {
        guard let initial = initialMarkdown else { return false }
        return rawMarkdown != initial
    }

    // MARK: - Markdown Mode Methods

    /// Generate the markdown representation of the current recipe.
    /// In edit mode with no form changes, reads the original file from disk to preserve user formatting.
    /// Otherwise, serializes the current form state.
    func generateMarkdown() -> String {
        // In edit mode with no form changes, read original file content
        if case .edit(let originalFile) = mode, !hasUnsavedChanges {
            let content: String? = originalFile.filePath.withSecurityScopedAccess {
                try? String(contentsOf: originalFile.filePath, encoding: .utf8)
            }
            if let content {
                return content
            }
        }

        // Otherwise, serialize current form state
        let recipeFile = buildRecipeFile()
        return RecipeFileSerializer().serialize(recipeFile)
    }

    /// Enter markdown editing mode — populates rawMarkdown from current state
    func enterMarkdownMode() {
        rawMarkdown = generateMarkdown()
        if initialMarkdown == nil {
            initialMarkdown = rawMarkdown
        }
    }

    /// Exit markdown mode by parsing rawMarkdown back into form fields.
    /// - Returns: nil on success, or an error message string if parsing fails
    func exitMarkdownMode() -> String? {
        let parser = RecipeMDParser()
        do {
            let recipe = try parser.parse(rawMarkdown)
            let tempFile = RecipeFile(
                filePath: URL(fileURLWithPath: "/tmp/markdown-preview.md"),
                recipe: recipe
            )
            populateFromRecipeFile(tempFile)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Validate raw markdown content (lighter than full form validation)
    @discardableResult
    func validateMarkdown() -> Bool {
        validationErrors = []
        let trimmed = rawMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            validationErrors.append(RecipeValidationError(
                field: "markdown",
                message: "Markdown content cannot be empty"
            ))
            return false
        }

        if !trimmed.hasPrefix("# ") {
            validationErrors.append(RecipeValidationError(
                field: "markdown",
                message: "Recipe must start with a title (# Title)"
            ))
            return false
        }

        return true
    }

    /// Save the raw markdown content directly
    /// - Parameters:
    ///   - folder: The folder to save in (for new recipes)
    ///   - store: The recipe store
    ///   - forceOverwrite: If true, skip conflict check and overwrite
    /// - Returns: The saved recipe file
    func saveRawMarkdown(to folder: URL, using store: RecipeStore, forceOverwrite: Bool = false) async throws -> RecipeFile {
        guard validateMarkdown() else {
            throw RecipeWriteError.serializationError
        }

        // Check for external modifications in edit mode (unless force overwrite)
        if !forceOverwrite && checkForExternalModification() {
            throw RecipeWriteError.fileModifiedExternally
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        // Parse markdown to get recipe (needed for title in add mode and store updates)
        let parser = RecipeMDParser()
        let recipe: Recipe
        do {
            recipe = try parser.parse(rawMarkdown)
        } catch {
            throw RecipeWriteError.serializationError
        }

        do {
            let savedRecipeFile: RecipeFile
            switch mode {
            case .add:
                savedRecipeFile = try await store.saveNewRecipeFromMarkdown(rawMarkdown, title: recipe.title, in: folder)
            case .edit(let originalFile):
                try await store.updateRecipeFromMarkdown(rawMarkdown, filePath: originalFile.filePath)
                savedRecipeFile = RecipeFile(
                    filePath: originalFile.filePath,
                    recipe: recipe,
                    fileModifiedDate: Date()
                )
            }
            return savedRecipeFile
        } catch {
            saveError = error
            throw error
        }
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

    // MARK: - Ingredient Group Methods

    /// Add a new empty ingredient group and return its ID
    @discardableResult
    func addIngredientGroup() -> UUID {
        let group = EditableIngredientGroup()
        ingredientGroups.append(group)
        return group.id
    }

    /// Remove an ingredient group by ID
    func removeIngredientGroup(id: UUID) {
        ingredientGroups.removeAll { $0.id == id }
    }

    /// Add a new empty ingredient to a group and return its ID
    @discardableResult
    func addIngredientToGroup(groupId: UUID) -> UUID? {
        guard let index = ingredientGroups.firstIndex(where: { $0.id == groupId }) else {
            return nil
        }
        let newIngredient = EditableIngredient()
        ingredientGroups[index].ingredients.append(newIngredient)
        return newIngredient.id
    }

    /// Remove an ingredient from a group at the given offsets
    func removeIngredientFromGroup(groupId: UUID, at offsets: IndexSet) {
        guard let index = ingredientGroups.firstIndex(where: { $0.id == groupId }) else {
            return
        }
        ingredientGroups[index].ingredients.remove(atOffsets: offsets)
        // Ensure at least one ingredient row in group
        if ingredientGroups[index].ingredients.isEmpty {
            ingredientGroups[index].ingredients.append(EditableIngredient())
        }
    }

    // MARK: - Instruction Group Methods

    /// Add a new instruction group and return its ID
    @discardableResult
    func addInstructionGroup() -> UUID {
        let newGroup = EditableInstructionGroup(title: "New Group")
        instructionGroups.append(newGroup)
        return newGroup.id
    }

    /// Remove instruction group by ID (cannot remove ungrouped at index 0)
    func removeInstructionGroup(id: UUID) {
        guard let index = instructionGroups.firstIndex(where: { $0.id == id }),
              index > 0 else { return }
        instructionGroups.remove(at: index)
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

        // Ingredients validation - check ungrouped + all groups
        let validUngrouped = ingredients.filter { $0.isValid }
        let validGrouped = ingredientGroups.flatMap { $0.ingredients.filter { $0.isValid } }
        if validUngrouped.isEmpty && validGrouped.isEmpty {
            validationErrors.append(RecipeValidationError(
                field: "ingredients",
                message: "At least one ingredient is required"
            ))
        }

        // Ingredient group title validation
        for group in ingredientGroups {
            if group.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationErrors.append(RecipeValidationError(
                    field: "groupTitle",
                    message: "Group title is required"
                ))
                break
            }
        }

        // Instruction group title validation (skip index 0, which is ungrouped)
        for group in instructionGroups.dropFirst() {
            if group.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationErrors.append(RecipeValidationError(
                    field: "instructionGroupTitle",
                    message: "Instruction group titles cannot be empty"
                ))
                break
            }
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

        return fileURL.withSecurityScopedAccess {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let currentDate = attributes[.modificationDate] as? Date else {
                return false
            }
            return abs(currentDate.timeIntervalSince(originalDate)) > 1.0
        }
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
    func populateFromRecipeFile(_ recipeFile: RecipeFile) {
        let recipe = recipeFile.recipe

        title = recipe.title
        descriptionText = recipe.description ?? ""
        tagsText = recipe.tags.joined(separator: ", ")
        instructionGroups = parseInstructionsToGroups(recipe.instructions ?? "")

        // Format yields from Yield type
        yieldsText = recipe.yield.formatted

        // Populate ingredients preserving group structure
        populateIngredientGroups(from: recipe.ingredientGroups)
    }

    /// Populate ingredient sections from parsed ingredient groups
    private func populateIngredientGroups(from groups: [IngredientGroup]) {
        var ungrouped: [EditableIngredient] = []
        var named: [EditableIngredientGroup] = []

        for group in groups {
            let editableIngredients = group.ingredients.map { EditableIngredient(from: $0) }

            if group.title != nil && !group.title!.isEmpty {
                // Named group
                named.append(EditableIngredientGroup(
                    title: group.title!,
                    ingredients: editableIngredients.isEmpty ? [EditableIngredient()] : editableIngredients
                ))
            } else {
                // Ungrouped
                ungrouped.append(contentsOf: editableIngredients)
            }
        }

        if ungrouped.isEmpty && !named.isEmpty {
            // Recipe has only named groups — no need for an empty ungrouped section
            ingredients = []
        } else {
            ingredients = ungrouped.isEmpty ? [EditableIngredient()] : ungrouped
        }
        ingredientGroups = named
    }

    /// Parse a raw instructions string into instruction groups by splitting on `## ` headings
    func parseInstructionsToGroups(_ instructions: String) -> [EditableInstructionGroup] {
        guard !instructions.isEmpty else {
            return [EditableInstructionGroup()]
        }

        var groups: [EditableInstructionGroup] = []
        var currentTitle = ""
        var currentLines: [String] = []

        for line in instructions.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                // Save the previous group
                let text = currentLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                groups.append(EditableInstructionGroup(title: currentTitle, text: text))

                // Start a new group
                currentTitle = String(trimmed.dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        // Save the last group
        let text = currentLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        groups.append(EditableInstructionGroup(title: currentTitle, text: text))

        return groups
    }

    /// Serialize instruction groups back into a single instructions string
    func serializeInstructionGroups() -> String {
        var parts: [String] = []

        for group in instructionGroups {
            let trimmedText = group.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if group.isUngrouped {
                if !trimmedText.isEmpty {
                    parts.append(trimmedText)
                }
            } else {
                var section = "## \(group.title)"
                if !trimmedText.isEmpty {
                    section += "\n\n\(trimmedText)"
                }
                parts.append(section)
            }
        }

        return parts.joined(separator: "\n\n")
    }

    /// Build a RecipeFile from the current form state
    func buildRecipeFile() -> RecipeFile {
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

        // Build ingredient groups
        var allGroups: [IngredientGroup] = []

        // Ungrouped ingredients (no title)
        let ungroupedIngredients = ingredients
            .filter { $0.isValid }
            .map { $0.toIngredient() }
        if !ungroupedIngredients.isEmpty {
            allGroups.append(IngredientGroup(ingredients: ungroupedIngredients))
        }

        // Named groups
        for group in ingredientGroups {
            let groupIngredients = group.ingredients
                .filter { $0.isValid }
                .map { $0.toIngredient() }
            let trimmedTitle = group.title.trimmingCharacters(in: .whitespacesAndNewlines)
            allGroups.append(IngredientGroup(
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                ingredients: groupIngredients
            ))
        }

        // Build the library Recipe
        let recipe = Recipe(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.isEmpty ? nil : descriptionText,
            tags: tags,
            yield: yield,
            ingredientGroups: allGroups,
            instructions: serializeInstructionGroups().isEmpty ? nil : serializeInstructionGroups()
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
            ingredientGroups: ingredientGroups.map { group in
                IngredientGroupState(
                    title: group.title,
                    ingredients: group.ingredients.map { "\($0.amount)|\($0.name)" }
                )
            },
            instructionGroups: instructionGroups.map { group in
                InstructionGroupState(title: group.title, text: group.text)
            }
        )
    }

    /// Form state struct for change detection
    private struct FormState: Equatable {
        let title: String
        let description: String
        let tags: String
        let yields: String
        let ingredients: [String]
        let ingredientGroups: [IngredientGroupState]
        let instructionGroups: [InstructionGroupState]
    }

    /// Ingredient group state for change detection
    private struct IngredientGroupState: Equatable {
        let title: String
        let ingredients: [String]
    }

    /// Instruction group state for change detection
    private struct InstructionGroupState: Equatable {
        let title: String
        let text: String
    }
}
