//
//  RecipeFormViewModelTests.swift
//  OpenCookbookTests
//
//  Tests for RecipeFormViewModel
//

import Foundation
import Testing
import RecipeMD
@testable import OpenCookbook

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
        #expect(viewModel.instructionGroups.count == 1)
        #expect(viewModel.instructionGroups[0].text == "")
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
        #expect(viewModel.instructionGroups.count == 1)
        #expect(viewModel.instructionGroups[0].text == "Test instructions")
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

    @Test("Non-numeric amount folds into ingredient name")
    func nonNumericAmountFoldsIntoName() {
        let editable = EditableIngredient(amount: "pinch", name: "basil")
        let ingredient = editable.toIngredient()

        #expect(ingredient.amount == nil)
        #expect(ingredient.name == "pinch basil")
    }

    @Test("Non-numeric multi-word amount folds into ingredient name")
    func nonNumericMultiWordAmountFoldsIntoName() {
        let editable = EditableIngredient(amount: "1c", name: "flour")
        let ingredient = editable.toIngredient()

        #expect(ingredient.amount == nil)
        #expect(ingredient.name == "1c flour")
    }

    @Test("Numeric amount with unit parses correctly")
    func numericAmountWithUnitParsesCorrectly() {
        let editable = EditableIngredient(amount: "1 T", name: "romano cheese")
        let ingredient = editable.toIngredient()

        #expect(ingredient.amount != nil)
        #expect(ingredient.amount?.amount == 1.0)
        #expect(ingredient.amount?.unit == "T")
        #expect(ingredient.name == "romano cheese")
    }

    @Test("Unicode fraction amount parses correctly")
    func unicodeFractionAmountParsesCorrectly() {
        let editable = EditableIngredient(amount: "½ teaspoon", name: "cornstarch")
        let ingredient = editable.toIngredient()

        #expect(ingredient.name == "cornstarch")
        #expect(ingredient.amount != nil)
        #expect(ingredient.amount?.amount == 0.5)
        #expect(ingredient.amount?.unit == "teaspoon")
    }

    @Test("Mixed number with unicode fraction parses correctly")
    func mixedNumberWithUnicodeFractionParsesCorrectly() {
        let editable = EditableIngredient(amount: "1½ cups", name: "flour")
        let ingredient = editable.toIngredient()

        #expect(ingredient.name == "flour")
        #expect(ingredient.amount != nil)
        #expect(ingredient.amount?.amount == 1.5)
        #expect(ingredient.amount?.unit == "cups")
    }

    @Test("Single unicode fraction without unit parses correctly")
    func singleUnicodeFractionWithoutUnitParsesCorrectly() {
        let editable = EditableIngredient(amount: "¾", name: "lemon, juiced")
        let ingredient = editable.toIngredient()

        #expect(ingredient.name == "lemon, juiced")
        #expect(ingredient.amount != nil)
        #expect(ingredient.amount?.amount == 0.75)
        #expect(ingredient.amount?.unit == nil)
    }

    @Test("Round-trip preserves unicode fraction ingredient")
    func roundTripPreservesUnicodeFractionIngredient() {
        let original = Ingredient(
            name: "cornstarch",
            amount: Amount(amount: 0.5, unit: "teaspoon", rawText: "½")
        )

        let editable = EditableIngredient(from: original)
        let result = editable.toIngredient()

        #expect(result.name == "cornstarch")
        #expect(result.amount != nil)
        #expect(result.amount?.amount == 0.5)
        #expect(result.amount?.unit == "teaspoon")
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

    // MARK: - Ingredient Group Tests

    @Test("Initializes with empty ingredient groups in add mode")
    func initializesWithEmptyGroups() {
        let viewModel = RecipeFormViewModel(mode: .add)

        #expect(viewModel.ingredientGroups.isEmpty)
    }

    @Test("Adds ingredient group")
    func addsIngredientGroup() {
        let viewModel = RecipeFormViewModel(mode: .add)

        let groupId = viewModel.addIngredientGroup()

        #expect(viewModel.ingredientGroups.count == 1)
        #expect(viewModel.ingredientGroups.first?.id == groupId)
        #expect(viewModel.ingredientGroups.first?.title == "")
        #expect(viewModel.ingredientGroups.first?.ingredients.count == 1)
    }

    @Test("Removes ingredient group")
    func removesIngredientGroup() {
        let viewModel = RecipeFormViewModel(mode: .add)
        let groupId = viewModel.addIngredientGroup()

        viewModel.removeIngredientGroup(id: groupId)

        #expect(viewModel.ingredientGroups.isEmpty)
    }

    @Test("Adds ingredient to group")
    func addsIngredientToGroup() {
        let viewModel = RecipeFormViewModel(mode: .add)
        let groupId = viewModel.addIngredientGroup()
        let initialCount = viewModel.ingredientGroups[0].ingredients.count

        let newId = viewModel.addIngredientToGroup(groupId: groupId)

        #expect(newId != nil)
        #expect(viewModel.ingredientGroups[0].ingredients.count == initialCount + 1)
    }

    @Test("Removes ingredient from group keeping at least one")
    func removesIngredientFromGroupKeepsOne() {
        let viewModel = RecipeFormViewModel(mode: .add)
        let groupId = viewModel.addIngredientGroup()
        #expect(viewModel.ingredientGroups[0].ingredients.count == 1)

        viewModel.removeIngredientFromGroup(groupId: groupId, at: IndexSet(integer: 0))

        #expect(viewModel.ingredientGroups[0].ingredients.count == 1)
    }

    @Test("Populates ingredient groups from existing recipe")
    func populatesGroupsFromExistingRecipe() {
        let recipe = Recipe(
            title: "Cinnamon Rolls",
            ingredientGroups: [
                IngredientGroup(ingredients: [
                    Ingredient(name: "flour", amount: Amount(3, unit: "cups"))
                ]),
                IngredientGroup(
                    title: "For the Filling",
                    ingredients: [
                        Ingredient(name: "brown sugar", amount: Amount(0.75, unit: "cup")),
                        Ingredient(name: "cinnamon", amount: Amount(2, unit: "tbsp"))
                    ]
                ),
                IngredientGroup(
                    title: "For the Frosting",
                    ingredients: [
                        Ingredient(name: "cream cheese", amount: Amount(4, unit: "oz"))
                    ]
                )
            ]
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))

        // Ungrouped ingredients (from the untitled group)
        #expect(viewModel.ingredients.count == 1)
        #expect(viewModel.ingredients[0].name == "flour")

        // Named groups
        #expect(viewModel.ingredientGroups.count == 2)
        #expect(viewModel.ingredientGroups[0].title == "For the Filling")
        #expect(viewModel.ingredientGroups[0].ingredients.count == 2)
        #expect(viewModel.ingredientGroups[1].title == "For the Frosting")
        #expect(viewModel.ingredientGroups[1].ingredients.count == 1)
    }

    @Test("Populates flat list when recipe has single unnamed group")
    func populatesFlatListForSingleUnnamedGroup() {
        let recipe = Recipe(
            title: "Simple Recipe",
            ingredientGroups: [
                IngredientGroup(ingredients: [
                    Ingredient(name: "flour", amount: Amount(2, unit: "cups")),
                    Ingredient(name: "sugar", amount: Amount(1, unit: "cup"))
                ])
            ]
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))

        #expect(viewModel.ingredients.count == 2)
        #expect(viewModel.ingredientGroups.isEmpty)
    }

    @Test("Validates group title is required")
    func validatesGroupTitleRequired() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]
        viewModel.addIngredientGroup()
        // Leave group title empty

        let isValid = viewModel.validate()

        #expect(isValid == false)
        #expect(viewModel.groupTitleHasError == true)
    }

    @Test("Validates successfully with valid group title")
    func validatesWithValidGroupTitle() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]
        viewModel.addIngredientGroup()
        viewModel.ingredientGroups[0].title = "For the Sauce"
        viewModel.ingredientGroups[0].ingredients = [EditableIngredient(amount: "1 cup", name: "tomatoes")]

        let isValid = viewModel.validate()

        #expect(isValid == true)
    }

    @Test("Validates with ingredients only in groups")
    func validatesWithIngredientsOnlyInGroups() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        // No ungrouped ingredients (only empty default)
        viewModel.ingredients = [EditableIngredient()]
        viewModel.addIngredientGroup()
        viewModel.ingredientGroups[0].title = "Sauce"
        viewModel.ingredientGroups[0].ingredients = [EditableIngredient(amount: "1 cup", name: "tomatoes")]

        let isValid = viewModel.validate()

        #expect(isValid == true)
    }

    @Test("Builds RecipeFile with ingredient groups")
    func buildsRecipeFileWithGroups() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("group-build-test-\(UUID().uuidString).md")
        try "".write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let recipe = Recipe(
            title: "Test",
            ingredientGroups: [IngredientGroup(ingredients: [Ingredient(name: "flour")])]
        )
        let recipeFile = RecipeFile(filePath: testFile, recipe: recipe, fileModifiedDate: Date())

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))
        viewModel.title = "Test"
        viewModel.ingredients = [EditableIngredient(amount: "2 cups", name: "flour")]
        viewModel.addIngredientGroup()
        viewModel.ingredientGroups[0].title = "For the Glaze"
        viewModel.ingredientGroups[0].ingredients = [EditableIngredient(amount: "1 cup", name: "powdered sugar")]

        let store = RecipeStore()
        let saved = try await viewModel.save(to: tempDir, using: store, forceOverwrite: true)

        #expect(saved.recipe.ingredientGroups.count == 2)
        // First group: ungrouped
        #expect(saved.recipe.ingredientGroups[0].title == nil)
        #expect(saved.recipe.ingredientGroups[0].ingredients.count == 1)
        #expect(saved.recipe.ingredientGroups[0].ingredients[0].name == "flour")
        // Second group: named
        #expect(saved.recipe.ingredientGroups[1].title == "For the Glaze")
        #expect(saved.recipe.ingredientGroups[1].ingredients.count == 1)
        #expect(saved.recipe.ingredientGroups[1].ingredients[0].name == "powdered sugar")
    }

    @Test("Hides ungrouped section when recipe has only named groups")
    func hidesUngroupedForOnlyNamedGroups() {
        let recipe = Recipe(
            title: "Cinnamon Rolls",
            ingredientGroups: [
                IngredientGroup(
                    title: "For the Dough",
                    ingredients: [Ingredient(name: "flour", amount: Amount(3, unit: "cups"))]
                ),
                IngredientGroup(
                    title: "For the Filling",
                    ingredients: [Ingredient(name: "brown sugar", amount: Amount(0.75, unit: "cup"))]
                )
            ]
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))

        #expect(viewModel.ingredients.isEmpty)
        #expect(viewModel.ingredientGroups.count == 2)
    }

    @Test("Detects ingredient group changes")
    func detectsIngredientGroupChanges() {
        let viewModel = RecipeFormViewModel(mode: .add)
        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.addIngredientGroup()

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test("Detects group title changes")
    func detectsGroupTitleChanges() {
        let recipe = Recipe(
            title: "Test",
            ingredientGroups: [
                IngredientGroup(ingredients: [Ingredient(name: "flour")]),
                IngredientGroup(title: "Sauce", ingredients: [Ingredient(name: "tomato")])
            ]
        )
        let recipeFile = RecipeFile(filePath: URL(fileURLWithPath: "/tmp/test.md"), recipe: recipe)
        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))
        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.ingredientGroups[0].title = "New Sauce Name"

        #expect(viewModel.hasUnsavedChanges == true)
    }

    // MARK: - Instruction Group Tests

    @Test("Parses instructions with no headings into single ungrouped group")
    func parsesInstructionsNoHeadings() {
        let viewModel = RecipeFormViewModel(mode: .add)
        let groups = viewModel.parseInstructionsToGroups("Preheat oven\nMix ingredients\nBake")

        #expect(groups.count == 1)
        #expect(groups[0].isUngrouped == true)
        #expect(groups[0].text == "Preheat oven\nMix ingredients\nBake")
    }

    @Test("Parses instructions with headings into groups")
    func parsesInstructionsWithHeadings() {
        let input = "Preheat oven\nMix dough\n\n## Filling\n\nMix sugar and cinnamon\nSpread on dough"
        let viewModel = RecipeFormViewModel(mode: .add)
        let groups = viewModel.parseInstructionsToGroups(input)

        #expect(groups.count == 2)
        #expect(groups[0].isUngrouped == true)
        #expect(groups[0].text == "Preheat oven\nMix dough")
        #expect(groups[1].title == "Filling")
        #expect(groups[1].text == "Mix sugar and cinnamon\nSpread on dough")
    }

    @Test("Parses instructions with only headings (no ungrouped text)")
    func parsesInstructionsOnlyHeadings() {
        let input = "## Dough\n\nMix flour and water\n\n## Filling\n\nMix sugar"
        let viewModel = RecipeFormViewModel(mode: .add)
        let groups = viewModel.parseInstructionsToGroups(input)

        #expect(groups.count == 3)
        #expect(groups[0].isUngrouped == true)
        #expect(groups[0].text == "")
        #expect(groups[1].title == "Dough")
        #expect(groups[1].text == "Mix flour and water")
        #expect(groups[2].title == "Filling")
        #expect(groups[2].text == "Mix sugar")
    }

    @Test("Serializes instruction groups back to string")
    func serializesInstructionGroups() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.instructionGroups = [
            EditableInstructionGroup(title: "", text: "Preheat oven\nMix dough"),
            EditableInstructionGroup(title: "Filling", text: "Mix sugar and cinnamon")
        ]

        let result = viewModel.serializeInstructionGroups()

        #expect(result == "Preheat oven\nMix dough\n\n## Filling\n\nMix sugar and cinnamon")
    }

    @Test("Serialization round-trip preserves content")
    func serializationRoundTrip() {
        let original = "Preheat oven\nMix dough\n\n## Filling\n\nMix sugar and cinnamon\nSpread on dough"
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.instructionGroups = viewModel.parseInstructionsToGroups(original)

        let result = viewModel.serializeInstructionGroups()

        #expect(result == original)
    }

    @Test("Adds instruction group")
    func addsInstructionGroup() {
        let viewModel = RecipeFormViewModel(mode: .add)
        let initialCount = viewModel.instructionGroups.count

        let newId = viewModel.addInstructionGroup()

        #expect(viewModel.instructionGroups.count == initialCount + 1)
        #expect(viewModel.instructionGroups.last?.id == newId)
        #expect(viewModel.instructionGroups.last?.title == "New Group")
    }

    @Test("Removes instruction group by ID")
    func removesInstructionGroup() {
        let viewModel = RecipeFormViewModel(mode: .add)
        let groupId = viewModel.addInstructionGroup()
        #expect(viewModel.instructionGroups.count == 2)

        viewModel.removeInstructionGroup(id: groupId)

        #expect(viewModel.instructionGroups.count == 1)
    }

    @Test("Cannot remove ungrouped instruction group")
    func cannotRemoveUngroupedInstructionGroup() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.addInstructionGroup()
        #expect(viewModel.instructionGroups.count == 2)

        let ungroupedId = viewModel.instructionGroups[0].id
        viewModel.removeInstructionGroup(id: ungroupedId)

        #expect(viewModel.instructionGroups.count == 2)
    }

    @Test("Validates instruction group title cannot be empty")
    func validatesInstructionGroupTitleRequired() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]
        viewModel.instructionGroups = [
            EditableInstructionGroup(title: "", text: "Step one"),
            EditableInstructionGroup(title: "", text: "Step two")  // empty title on named group
        ]

        let isValid = viewModel.validate()

        #expect(isValid == false)
        #expect(viewModel.instructionGroupTitleHasError == true)
    }

    @Test("Validates successfully with valid instruction group titles")
    func validatesWithValidInstructionGroupTitles() {
        let viewModel = RecipeFormViewModel(mode: .add)
        viewModel.title = "Test Recipe"
        viewModel.ingredients = [EditableIngredient(amount: "", name: "flour")]
        viewModel.instructionGroups = [
            EditableInstructionGroup(title: "", text: "Step one"),
            EditableInstructionGroup(title: "Frosting", text: "Beat cream cheese")
        ]

        let isValid = viewModel.validate()

        #expect(isValid == true)
    }

    @Test("Detects instruction group changes")
    func detectsInstructionGroupChanges() {
        let viewModel = RecipeFormViewModel(mode: .add)
        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.addInstructionGroup()

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test("Populates instruction groups from existing recipe")
    func populatesInstructionGroupsFromRecipe() {
        let recipe = Recipe(
            title: "Cinnamon Rolls",
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "flour", amount: Amount(3, unit: "cups"))
            ])],
            instructions: "Make dough\nLet rise\n\n## Filling\n\nMix sugar and cinnamon"
        )

        let recipeFile = RecipeFile(
            filePath: URL(fileURLWithPath: "/tmp/test.md"),
            recipe: recipe
        )

        let viewModel = RecipeFormViewModel(mode: .edit(recipeFile))

        #expect(viewModel.instructionGroups.count == 2)
        #expect(viewModel.instructionGroups[0].isUngrouped == true)
        #expect(viewModel.instructionGroups[0].text == "Make dough\nLet rise")
        #expect(viewModel.instructionGroups[1].title == "Filling")
        #expect(viewModel.instructionGroups[1].text == "Mix sugar and cinnamon")
    }

    @Test("Initializes with single empty ungrouped instruction group in add mode")
    func initializesWithSingleUngroupedInstructionGroup() {
        let viewModel = RecipeFormViewModel(mode: .add)

        #expect(viewModel.instructionGroups.count == 1)
        #expect(viewModel.instructionGroups[0].isUngrouped == true)
        #expect(viewModel.instructionGroups[0].text == "")
    }
}
