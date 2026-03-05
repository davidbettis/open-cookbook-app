//
//  RecipeImportPreviewView.swift
//  OpenCookbook
//
//  Preview screen for an imported recipe with Save/Cancel actions
//

import MarkdownUI
import RecipeMD
import SwiftUI

/// Shows a preview of an incoming recipe and lets the user save or dismiss it.
struct RecipeImportPreviewView: View {
    let incomingRecipe: IncomingRecipe
    let folderURL: URL?
    let onDismiss: () -> Void

    @State private var isSaving = false
    @State private var saveError: Error?
    @State private var showSaveError = false

    private let filenameGenerator = FilenameGenerator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(incomingRecipe.recipe.title)
                        .font(.largeTitle.bold())

                    if let desc = incomingRecipe.recipe.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if !incomingRecipe.recipe.tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(incomingRecipe.recipe.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.secondary.opacity(0.15), in: Capsule())
                            }
                        }
                    }

                    Divider()

                    Text("Ingredients")
                        .font(.headline)

                    ForEach(incomingRecipe.recipe.ingredientGroups, id: \.title) { group in
                        if let groupTitle = group.title {
                            Text(groupTitle)
                                .font(.subheadline.bold())
                                .padding(.top, 4)
                        }
                        ForEach(group.ingredients, id: \.name) { ingredient in
                            ingredientRow(ingredient)
                        }
                    }

                    Divider()

                    if let instructions = incomingRecipe.recipe.instructions, !instructions.isEmpty {
                        Text("Instructions")
                            .font(.headline)

                        Markdown(instructions)
                            .markdownTheme(.gitHub)
                    }
                }
                .padding()
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .disabled(isSaving || folderURL == nil)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error Saving Recipe", isPresented: $showSaveError) {
                Button("OK") {}
            } message: {
                if let error = saveError {
                    Text(error.localizedDescription)
                }
            }
            .overlay {
                if folderURL == nil {
                    ContentUnavailableView(
                        "No Recipe Folder",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Open the app and select a recipe folder first.")
                    )
                }
            }
        }
    }

    // MARK: - Ingredient Row

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let amount = ingredient.amount {
                Text(amount.formattedScaled(by: 1.0))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 50, alignment: .trailing)
            }
            Text(ingredient.name)
                .font(.body)
        }
    }

    // MARK: - Save

    /// Write the recipe file directly, then notify the store to refresh.
    private func saveRecipe() {
        guard let folder = folderURL else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try folder.withSecurityScopedAccess {
                let fileURL = try filenameGenerator.generateFileURL(
                    for: incomingRecipe.recipe.title,
                    in: folder
                )
                try incomingRecipe.markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            NotificationCenter.default.post(name: .recipesDidChange, object: nil)
            onDismiss()
        } catch {
            saveError = error
            showSaveError = true
        }
    }
}
