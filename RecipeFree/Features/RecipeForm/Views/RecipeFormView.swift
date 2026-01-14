//
//  RecipeFormView.swift
//  RecipeFree
//
//  Form for adding or editing recipes
//

import SwiftUI
import RecipeMD

/// Form view for creating or editing recipes
struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FolderManager.self) private var folderManager

    @State private var viewModel: RecipeFormViewModel
    let recipeStore: RecipeStore
    let onSave: ((RecipeFile) -> Void)?

    @State private var showCancelConfirmation = false
    @State private var showErrorAlert = false

    // MARK: - Initialization

    init(
        viewModel: RecipeFormViewModel,
        recipeStore: RecipeStore,
        onSave: ((RecipeFile) -> Void)? = nil
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.recipeStore = recipeStore
        self.onSave = onSave
    }

    // MARK: - Body

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                // Title Section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Recipe name", text: $viewModel.title)
                            .font(.headline)
                            .accessibilityLabel("Recipe title")
                        if viewModel.titleHasError {
                            Text(viewModel.validationErrors.first { $0.field == "title" }?.message ?? "")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    HStack {
                        Text("Title")
                        Text("*").foregroundStyle(.red)
                    }
                }

                // Description Section
                Section("Description") {
                    TextEditor(text: $viewModel.descriptionText)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Recipe description")
                        .accessibilityHint("Optional brief description of the recipe")
                }

                // Tags Section
                Section {
                    TextField("dessert, quick, vegetarian", text: $viewModel.tagsText)
                        .accessibilityLabel("Recipe tags")
                        .accessibilityHint("Enter tags separated by commas")
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Separate tags with commas")
                }

                // Yields Section
                Section {
                    TextField("serves 4, makes 12 cookies", text: $viewModel.yieldsText)
                        .accessibilityLabel("Recipe yields")
                        .accessibilityHint("Enter serving size or quantity")
                } header: {
                    Text("Yields")
                } footer: {
                    Text("Separate multiple yields with commas")
                }

                // Ingredients Section
                Section {
                    ForEach($viewModel.ingredients) { $ingredient in
                        IngredientRowView(
                            ingredient: $ingredient,
                            onDelete: {
                                if let index = viewModel.ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                                    viewModel.removeIngredient(at: IndexSet(integer: index))
                                }
                            }
                        )
                    }

                    Button {
                        viewModel.addIngredient()
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle")
                    }
                    .accessibilityHint("Add another ingredient to the list")

                    if viewModel.ingredientsHasError {
                        Text(viewModel.validationErrors.first { $0.field == "ingredients" }?.message ?? "")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    HStack {
                        Text("Ingredients")
                        Text("*").foregroundStyle(.red)
                    }
                }

                // Instructions Section
                Section("Instructions") {
                    TextEditor(text: $viewModel.instructions)
                        .frame(minHeight: 150)
                        .accessibilityLabel("Recipe instructions")
                        .accessibilityHint("Enter step-by-step cooking instructions")
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.saveButtonText) {
                        Task {
                            await handleSave()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    savingOverlay
                }
            }
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes that will be lost.")
            }
            .alert("Error Saving Recipe", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                if let error = viewModel.saveError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Subviews

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Saving recipe...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            showCancelConfirmation = true
        } else {
            dismiss()
        }
    }

    private func handleSave() async {
        guard let folder = folderManager.selectedFolderURL else {
            viewModel.saveError = RecipeWriteError.folderNotAccessible
            showErrorAlert = true
            return
        }

        do {
            let savedRecipeFile = try await viewModel.save(to: folder, using: recipeStore)
            onSave?(savedRecipeFile)
            dismiss()
        } catch {
            showErrorAlert = true
        }
    }
}

// MARK: - Previews

#Preview("Add Recipe") {
    RecipeFormView(
        viewModel: RecipeFormViewModel(mode: .add),
        recipeStore: RecipeStore()
    )
    .environment(FolderManager())
}

#Preview("Edit Recipe") {
    let recipeFile = RecipeFile(
        filePath: URL(fileURLWithPath: "/tmp/test.md"),
        recipe: Recipe(
            title: "Chocolate Chip Cookies",
            description: "Classic homemade cookies",
            tags: ["dessert", "baking"],
            yield: Yield(amount: [Amount(24, unit: "cookies")]),
            ingredientGroups: [IngredientGroup(ingredients: [
                Ingredient(name: "flour", amount: Amount(2, unit: "cups")),
                Ingredient(name: "sugar", amount: Amount(1, unit: "cup"))
            ])],
            instructions: "1. Mix ingredients\n2. Bake at 350F"
        )
    )

    RecipeFormView(
        viewModel: RecipeFormViewModel(mode: .edit(recipeFile)),
        recipeStore: RecipeStore()
    )
    .environment(FolderManager())
}
