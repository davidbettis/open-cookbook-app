//
//  RecipeDetailView.swift
//  RecipeFree
//
//  Displays full recipe content using MarkdownUI
//

import MarkdownUI
import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    var recipeStore: RecipeStore?

    @Environment(\.dismiss) private var dismiss
    @State private var markdownContent: String?
    @State private var loadError: Error?
    @State private var currentRecipe: Recipe?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: Error?
    @State private var showDeleteError = false
    @State private var recipeToEdit: Recipe?

    private let parser = RecipeMDParser()

    var body: some View {
        ScrollView {
            if let content = markdownContent {
                Markdown(content)
                    .markdownTheme(.recipe)
                    .padding()
            } else if let error = loadError {
                errorView(error)
            } else {
                loadingView
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Share button
                if let content = markdownContent {
                    ShareLink(
                        item: content,
                        subject: Text(recipe.title),
                        message: Text("Check out this recipe!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share Recipe")
                }

                // Edit button
                if recipeStore != nil {
                    Button {
                        loadFullRecipeAndEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit Recipe")
                }

                // More menu (with delete)
                if recipeStore != nil {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Recipe", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
                }
            }
        }
        .sheet(item: $recipeToEdit) { fullRecipe in
            if let store = recipeStore {
                RecipeFormView(
                    viewModel: RecipeFormViewModel(mode: .edit(fullRecipe)),
                    recipeStore: store,
                    onSave: { savedRecipe in
                        currentRecipe = savedRecipe
                        Task {
                            await loadRecipeContent()
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete Recipe?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteRecipe()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(recipe.title)\"? This action cannot be undone.")
        }
        .alert("Error Deleting Recipe", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            if let error = deleteError {
                Text(error.localizedDescription)
            }
        }
        .task(id: recipe.id) {
            // Reset state when recipe changes
            markdownContent = nil
            loadError = nil
            currentRecipe = recipe
            await loadRecipeContent()
        }
    }

    // MARK: - Content Loading

    private func loadRecipeContent() async {
        do {
            // Start accessing security-scoped resource if needed
            let fileToLoad = currentRecipe?.filePath ?? recipe.filePath
            let didStartAccess = fileToLoad.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    fileToLoad.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: fileToLoad)
            guard let content = String(data: data, encoding: .utf8) else {
                throw RecipeParseError.encodingError
            }

            await MainActor.run {
                self.markdownContent = content
            }
        } catch {
            await MainActor.run {
                self.loadError = error
            }
        }
    }

    // MARK: - Edit

    private func loadFullRecipeAndEdit() {
        let fileURL = currentRecipe?.filePath ?? recipe.filePath

        // Access security-scoped resource
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Parse full recipe and set it - this triggers sheet presentation
            recipeToEdit = try parser.parseFullRecipe(from: fileURL)
        } catch {
            // Fall back to partial recipe if full parse fails
            recipeToEdit = currentRecipe ?? recipe
        }
    }

    // MARK: - Delete

    private func deleteRecipe() async {
        guard let store = recipeStore else { return }

        do {
            try await store.deleteRecipe(currentRecipe ?? recipe)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                deleteError = error
                showDeleteError = true
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading recipe...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Unable to load recipe")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Preview

#Preview("Recipe Detail") {
    NavigationStack {
        RecipeDetailView(
            recipe: Recipe(
                filePath: URL(fileURLWithPath: "/example/recipe.md"),
                title: "Chocolate Chip Cookies"
            )
        )
    }
}

#Preview("Recipe Detail - With Content") {
    // Create a temporary file for preview
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("preview-recipe.md")

    let sampleContent = """
    # Chocolate Chip Cookies

    Classic homemade chocolate chip cookies with a chewy center.

    *dessert, baking, quick*

    **makes 24 cookies**

    ---

    - *2 1/4 cups* all-purpose flour
    - *1 tsp* baking soda
    - *1 cup* butter, softened
    - *2 cups* chocolate chips

    ---

    1. Preheat oven to 375°F
    2. Mix flour and baking soda
    3. Cream butter and sugars
    4. Combine and bake for 10-12 minutes
    """

    try? sampleContent.write(to: tempFile, atomically: true, encoding: .utf8)

    return NavigationStack {
        RecipeDetailView(
            recipe: Recipe(
                filePath: tempFile,
                title: "Chocolate Chip Cookies"
            )
        )
    }
}
