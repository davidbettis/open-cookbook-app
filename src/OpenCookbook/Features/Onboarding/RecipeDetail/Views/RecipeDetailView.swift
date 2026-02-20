//
//  RecipeDetailView.swift
//  OpenCookbook
//
//  Displays full recipe content using MarkdownUI
//

import MarkdownUI
import SwiftUI
import RecipeMD

struct RecipeDetailView: View {
    let recipeFile: RecipeFile
    var recipeStore: RecipeStore?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var markdownContent: String?
    @State private var loadError: Error?
    @State private var currentRecipeFile: RecipeFile?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: Error?
    @State private var showDeleteError = false
    @State private var recipeToEdit: RecipeFile?

    private let parser = RecipeFileParser()

    var body: some View {
        Group {
            if let content = markdownContent {
                if horizontalSizeClass == .regular {
                    // iPad: RecipeDetailContent handles its own scrolling
                    RecipeDetailContent(
                        recipeFile: currentRecipeFile ?? recipeFile,
                        markdownContent: content
                    )
                } else {
                    // iPhone: Wrap in ScrollView
                    ScrollView {
                        RecipeDetailContent(
                            recipeFile: currentRecipeFile ?? recipeFile,
                            markdownContent: content
                        )
                    }
                }
            } else if let error = loadError {
                ScrollView {
                    errorView(error)
                }
            } else {
                ScrollView {
                    loadingView
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Centered app icon (iPad/macOS only)
            if horizontalSizeClass == .regular {
                ToolbarItem(placement: .principal) {
                    Image("AppIconSmall")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Open Cookbook")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // Share button - shares the file like Files app
                ShareLink(item: currentRecipeFile?.filePath ?? recipeFile.filePath) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share Recipe")

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
        .fullScreenCover(item: $recipeToEdit) { fullRecipeFile in
            if let store = recipeStore {
                RecipeFormView(
                    viewModel: RecipeFormViewModel(mode: .edit(fullRecipeFile)),
                    recipeStore: store,
                    onSave: { savedRecipeFile in
                        currentRecipeFile = savedRecipeFile
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
            Text("Are you sure you want to delete \"\(recipeFile.title)\"? This action cannot be undone.")
        }
        .alert("Error Deleting Recipe", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            if let error = deleteError {
                Text(error.localizedDescription)
            }
        }
        .task(id: recipeFile.id) {
            // Reset state when recipe changes
            markdownContent = nil
            loadError = nil
            currentRecipeFile = recipeFile
            await loadRecipeContent()
        }
    }

    // MARK: - Content Loading

    private func loadRecipeContent() async {
        do {
            let fileToLoad = currentRecipeFile?.filePath ?? recipeFile.filePath
            let data = try fileToLoad.withSecurityScopedAccess {
                try Data(contentsOf: fileToLoad)
            }
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
        let fileURL = currentRecipeFile?.filePath ?? recipeFile.filePath

        recipeToEdit = fileURL.withSecurityScopedAccess {
            try? parser.parse(from: fileURL)
        } ?? currentRecipeFile ?? recipeFile
    }

    // MARK: - Delete

    private func deleteRecipe() async {
        guard let store = recipeStore else { return }

        do {
            try await store.deleteRecipe(currentRecipeFile ?? recipeFile)
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
            recipeFile: RecipeFile(
                filePath: URL(fileURLWithPath: "/example/recipe.md"),
                recipe: Recipe(title: "Chocolate Chip Cookies")
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
            recipeFile: RecipeFile(
                filePath: tempFile,
                recipe: Recipe(title: "Chocolate Chip Cookies")
            )
        )
    }
}
