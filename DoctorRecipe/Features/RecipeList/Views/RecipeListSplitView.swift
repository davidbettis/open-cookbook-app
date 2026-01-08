//
//  RecipeListSplitView.swift
//  DoctorRecipe
//
//  iPad recipe list view with NavigationSplitView
//

import SwiftUI

/// iPad recipe list view using NavigationSplitView
struct RecipeListSplitView: View {

    // MARK: - Properties

    @Environment(FolderManager.self) private var folderManager
    @State private var viewModel: RecipeListViewModel
    @State private var selectedRecipe: Recipe?
    @State private var selectedError: (URL, Error)?
    @State private var showErrorAlert = false

    // MARK: - Initialization

    init(viewModel: RecipeListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            // Sidebar - Recipe List
            sidebarContent
                .navigationTitle("Recipes")
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 500)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            // TODO: Add recipe action (F005)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Recipe")
                    }
                }
        } detail: {
            // Detail pane
            detailContent
        }
        .alert("Parse Error", isPresented: $showErrorAlert, presenting: selectedError) { _ in
            Button("OK") {
                selectedError = nil
            }
        } message: { error in
            Text(error.1.localizedDescription)
        }
        .task {
            // Load recipes on appear
            if let folder = folderManager.selectedFolderURL {
                await viewModel.loadRecipes(folder: folder)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var sidebarContent: some View {
        Group {
            if viewModel.recipeStore.isLoading && viewModel.recipeStore.recipes.isEmpty {
                // Show loading state on initial load
                ProgressView("Loading recipes...")
                    .padding()
            } else if viewModel.recipeStore.recipes.isEmpty {
                // Show empty state
                RecipeListEmptyState()
            } else {
                // Show recipe list
                recipeList
            }
        }
    }

    private var recipeList: some View {
        List(selection: $selectedRecipe) {
            // Show successfully parsed recipes
            ForEach(viewModel.recipeStore.recipes) { recipe in
                Button {
                    selectedRecipe = recipe
                } label: {
                    RecipeCard(recipe: recipe)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(
                    selectedRecipe?.id == recipe.id ?
                    Color.accentColor.opacity(0.1) : Color.clear
                )
            }

            // Show parse errors
            ForEach(Array(viewModel.recipeStore.parseErrors.keys.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })), id: \.self) { url in
                if let error = viewModel.recipeStore.parseErrors[url] {
                    Button {
                        selectedError = (url, error)
                        showErrorAlert = true
                    } label: {
                        RecipeErrorCard(fileURL: url, error: error)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let recipe = selectedRecipe {
            RecipeDetailView(recipe: recipe)
        } else {
            // No selection
            ContentUnavailableView(
                "Select a Recipe",
                systemImage: "book",
                description: Text("Choose a recipe from the list to view its details")
            )
        }
    }
}

// MARK: - Placeholder Detail View

/// Temporary placeholder until F004 implements full detail view
struct RecipeDetailPlaceholder: View {

    let recipe: Recipe

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(recipe.title)
                .font(.title)
                .fontWeight(.semibold)

            if let description = recipe.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if !recipe.tags.isEmpty {
                HStack {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Spacer()
                .frame(height: 32)

            Text("Full recipe view coming in F004")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview("With Recipes") {
    @Previewable @State var store: RecipeStore = {
        let s = RecipeStore()
        s.recipes = [
            Recipe(
                filePath: URL(fileURLWithPath: "/tmp/cookies.md"),
                title: "Chocolate Chip Cookies",
                description: "Classic homemade cookies",
                tags: ["dessert", "baking"]
            ),
            Recipe(
                filePath: URL(fileURLWithPath: "/tmp/pasta.md"),
                title: "Pasta Carbonara",
                description: "Traditional Italian pasta dish",
                tags: ["dinner", "italian"]
            ),
            Recipe(
                filePath: URL(fileURLWithPath: "/tmp/salad.md"),
                title: "Caesar Salad",
                tags: ["lunch", "salad"]
            )
        ]
        return s
    }()

    RecipeListSplitView(viewModel: RecipeListViewModel(recipeStore: store))
        .environment(FolderManager())
}

#Preview("Empty State") {
    RecipeListSplitView(viewModel: RecipeListViewModel(recipeStore: RecipeStore()))
        .environment(FolderManager())
}
