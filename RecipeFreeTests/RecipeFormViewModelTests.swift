//
//  RecipeFormViewModelTests.swift
//  RecipeFreeTests
//
//  Tests for RecipeFormViewModel
//

import Foundation
import Testing
import RecipeMD
@testable import RecipeFree

@MainActor
struct RecipeFormViewModelTests {

    // MARK: - Initialization Tests

    @Test("Initializes with add mode defaults")
    func initializesWithAddModeDefaults() {
        let viewModel = RecipeFormViewModel(mode: .add)

        #expect(viewModel.title == "")
        #expect(viewModel.descriptionText == "")
        #expect(viewModel.tagsText == "")
        #expect(viewModel.yieldsText == "")
        #expect(viewModel.instructions == "")
        #expect(viewModel.ingredients.count == 1)
        #expect(viewModel.mode == .add)
        #expect(viewModel.navigationTitle == "New Recipe")
        #expect(viewModel.saveButtonText == "Save")
    }

    @Test("Initializes with edit mode and populates fields")
    func initializesWithEditMode() {
        let recipe = Recipe(
            title: "Test Recipe",
            description: "Test description",
            tags: ["tag1", "tag2"],
            yield: Yield(amount: [Amount(4, unit: "servings")]),
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "flour", amount: Amount(1, unit: "cup"))
            ])],
            instructions: "Test instructions"
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))

        #expect(viewModel.title == "Test Recipe")
        #expect(viewModel.descriptionText == "Test description")
        #expect(viewModel.tagsText == "tag1, tag2")
        #expect(viewModel.instructions == "Test instructions")
        #expect(viewModel.navigationTitle == "Edit Recipe")
        #expect(viewModel.saveButtonText == "Save Changes")
    }

    // MARK: - Validation Tests

    @Test("Validates successfully with minimal data")
    func validatesWithMinimalData() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]

        let isValid = viewModel.validate()

        #expect(isValid == true)
        #expect(viewModel.validationErrors.isEmpty)
    }

    @Test("Fails validation with empty title")
    func failsValidationWithEmptyTitle() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = ""
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]

        let isValid = viewModel.validate()

        #expect(isValid == false)
        #expect(viewModel.titleHasError == true)
        #expect(viewModel.validationErrors.contains { $0.field == "title" })
    }

    @Test("Fails validation with whitespace-only title")
    func failsValidationWithWhitespaceTitle() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "   "
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]

        let isValid = viewModel.validate()

        #expect(isValid == false)
        #expect(viewModel.titleHasError == true)
    }

    @Test("Fails validation with title over 200 characters")
    func failsValidationWithLongTitle() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = String(repeating: "a", count: 201)
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]

        let isValid = viewModel.validate()

        #expect(isValid == false)
        #expect(viewModel.titleHasError == true)
    }

    @Test("Fails validation with no ingredients")
    func failsValidationWithNoIngredients() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        viewModel.ingredients = []

        let isValid = viewModel.validate()

        #expect(isValid == false)
        #expect(viewModel.ingredientsHasError == true)
    }

    @Test("Fails validation with only empty ingredients")
    func failsValidationWithEmptyIngredients() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [
            EditableIngredient(amount: "1 cup", name: ""),
            EditableIngredient(amount: "", name: "   ")
        ]

        let isValid = viewModel.validate()

        #expect(isValid == false)
        #expect(viewModel.ingredientsHasError == true)
    }

    // MARK: - Change Detection Tests

    @Test("Detects no changes after initialization")
    func detectsNoChangesAfterInit() {
        let viewModel = RecipeFormViewModel(mode: .add)

        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("Detects title change")
    func detectsTitleChange() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "New Title"

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test("Detects ingredient change")
    func detectsIngredientChange() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.ingredients[0].name = "flour"

        #expect(viewModel.hasUnsavedChanges == true)
    }

    // MARK: - Ingredient Management Tests

    @Test("Adds ingredient")
    func addsIngredient() {
        let viewModel = RecipeFormViewModel(mode: .add)
        let initialCount = viewModel.ingredients.count

        viewModel.addIngredient()

        #expect(viewModel.ingredients.count == initialCount + 1)
    }

    @Test("Removes ingredient")
    func removesIngredient() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.addIngredient()
        viewModel.addIngredient()
        let initialCount = viewModel.ingredients.count

        viewModel.removeIngredient(at: IndexSet(integer: 0))

        #expect(viewModel.ingredients.count == initialCount - 1)
    }

    @Test("Keeps at least one ingredient after removal")
    func keepsOneIngredientAfterRemoval() {
        let viewModel = RecipeFormViewModel(mode: .add)
        #expect(viewModel.ingredients.count == 1)

        viewModel.removeIngredient(at: IndexSet(integer: 0))

        #expect(viewModel.ingredients.count == 1)
    }

    // MARK: - Editable Ingredient Tests

    @Test("Converts ingredient to model")
    func convertsIngredientToModel() {
        let editable = EditableIngredient(amount: "2 cups", name: "flour")

        let ingredient = editable.toIngredient()

        #expect(ingredient.name == "flour")
        #expect(ingredient.amount != nil)
    }

    @Test("Handles ingredient with quantity only")
    func handlesIngredientWithQuantityOnly() {
        let editable = EditableIngredient(amount: "2", name: "eggs")

        let ingredient = editable.toIngredient()

        #expect(ingredient.name == "eggs")
        #expect(ingredient.amount != nil)
    }

    @Test("Handles ingredient with no amount")
    func handlesIngredientWithNoAmount() {
        let editable = EditableIngredient(amount: "", name: "salt")

        let ingredient = editable.toIngredient()

        #expect(ingredient.amount == nil)
        #expect(ingredient.name == "salt")
    }

    @Test("Creates editable from ingredient model")
    func createsEditableFromModel() {
        let ingredient = Ingredient(name: "sugar", amount: Amount(1, unit: "cup"))

        let editable = EditableIngredient(from: ingredient)

        #expect(editable.name == "sugar")
        #expect(!editable.amount.isEmpty)
    }

    @Test("Validates editable ingredient")
    func validatesEditableIngredient() {
        let valid = EditableIngredient(amount: "1 cup", name: "flour")
        let invalid = EditableIngredient(amount: "1 cup", name: "")

        #expect(valid.isValid == true)
        #expect(invalid.isValid == false)
    }

    // MARK: - Conflict Detection Tests

    @Test("No external modification in add mode")
    func noExternalModificationInAddMode() {
        let viewModel = RecipeFormViewModel(mode: .add)

        #expect(viewModel.checkForExternalModification() == false)
    }

    @Test("No external modification when file unchanged")
    func noExternalModificationWhenFileUnchanged() throws {
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("conflict-test-unchanged-\(UUID().uuidString).md")

        let content = """
        # Test Recipe

        ---

        - flour

        ---

        Instructions here.
        """
        try content.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Get the file's modification date
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let modDate = attributes[.modificationDate] as? Date

        let recipe = Recipe(
            title: "Test Recipe",
            ingredientGroups: [IngredientGroup(ingredients: [Ingredient(name: "flour")])]
        )

        let recipeFile = RecipeFile(
            filePath: testFile,
            recipe: recipe,
            fileModifiedDate: modDate
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))

        #expect(viewModel.checkForExternalModification() == false)
    }

    @Test("Detects external modification when file changed")
    func detectsExternalModificationWhenFileChanged() throws {
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("conflict-test-changed-\(UUID().uuidString).md")

        let content = """
        # Test Recipe

        ---

        - flour

        ---

        Instructions here.
        """
        try content.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Create recipe file with an OLD modification date (simulating loading earlier)
        let oldDate = Date(timeIntervalSinceNow: -60) // 1 minute ago

        let recipe = Recipe(
            title: "Test Recipe",
            ingredientGroups: [IngredientGroup(ingredients: [Ingredient(name: "flour")])]
        )

        let recipeFile = RecipeFile(
            filePath: testFile,
            recipe: recipe,
            fileModifiedDate: oldDate
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))

        // The file on disk has a newer modification date than what we stored
        #expect(viewModel.checkForExternalModification() == true)
    }

    @Test("Save throws error when file modified externally")
    func saveThrowsErrorWhenFileModifiedExternally() async throws {
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("conflict-test-save-\(UUID().uuidString).md")

        let content = """
        # Test Recipe

        ---

        - flour

        ---

        Instructions here.
        """
        try content.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Create recipe file with an OLD modification date
        let oldDate = Date(timeIntervalSinceNow: -60)

        let recipe = Recipe(
            title: "Test Recipe",
            ingredientGroups: [IngredientGroup(ingredients: [Ingredient(name: "flour")])]
        )

        let recipeFile = RecipeFile(
            filePath: testFile,
            recipe: recipe,
            fileModifiedDate: oldDate
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]

        let store = RecipeStore()

        do {
            _ = try await viewModel.save(to: tempDir, using: store, forceOverwrite: false)
            Issue.record("Expected fileModifiedExternally error to be thrown")
        } catch RecipeWriteError.fileModifiedExternally {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Save succeeds with forceOverwrite when file modified externally")
    func saveSucceedsWithForceOverwrite() async throws {
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("conflict-test-force-\(UUID().uuidString).md")

        let content = """
        # Test Recipe

        ---

        - flour

        ---

        Instructions here.
        """
        try content.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Create recipe file with an OLD modification date
        let oldDate = Date(timeIntervalSinceNow: -60)

        let recipe = Recipe(
            title: "Test Recipe",
            ingredientGroups: [IngredientGroup(ingredients: [Ingredient(name: "flour")])]
        )

        let recipeFile = RecipeFile(
            filePath: testFile,
            recipe: recipe,
            fileModifiedDate: oldDate
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]

        let store = RecipeStore()

        // Should succeed with forceOverwrite: true
        let savedRecipe = try await viewModel.save(to: tempDir, using: store, forceOverwrite: true)
        #expect(savedRecipe.title == "Test Recipe")
    }
}
