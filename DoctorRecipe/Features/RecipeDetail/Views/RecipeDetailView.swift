//
//  RecipeDetailView.swift
//  DoctorRecipe
//
//  Displays full recipe content using MarkdownUI
//

import MarkdownUI
import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var markdownContent: String?
    @State private var loadError: Error?

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

                // Edit button (placeholder for F006)
                Button {
                    // TODO: Navigate to edit view (F006)
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Recipe")
            }
        }
        .task {
            await loadRecipeContent()
        }
    }

    // MARK: - Content Loading

    private func loadRecipeContent() async {
        do {
            // Start accessing security-scoped resource if needed
            let didStartAccess = recipe.filePath.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    recipe.filePath.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: recipe.filePath)
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
