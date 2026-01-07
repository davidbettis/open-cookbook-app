//
//  RecipeListView.swift
//  DoctorRecipe
//
//  iPhone recipe list view with NavigationStack
//

import SwiftUI

/// ViewModel for RecipeListView
@MainActor
@Observable
class RecipeListViewModel {

    // MARK: - Properties

    var recipeStore: RecipeStore
    var isRefreshing = false

    // MARK: - Initialization

    init(recipeStore: RecipeStore) {
        self.recipeStore = recipeStore
    }

    // MARK: - Methods

    func loadRecipes(folder: URL) async {
        await recipeStore.loadRecipes(from: folder)
    }

    func refresh() async {
        isRefreshing = true
        await recipeStore.refreshRecipes()
        isRefreshing = false
    }
}

/// iPhone recipe list view using NavigationStack
struct RecipeListView: View {

    // MARK: - Properties

    @Environment(FolderManager.self) private var folderManager
    @State private var viewModel: RecipeListViewModel
    @State private var selectedError: (URL, Error)?
    @State private var showErrorAlert = false

    // MARK: - Initialization

    init(viewModel: RecipeListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Recipes")
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
    }

    // MARK: - Subviews

    private var recipeList: some View {
        List {
            // Show successfully parsed recipes
            ForEach(viewModel.recipeStore.recipes) { recipe in
                Button {
                    // TODO: Navigate to detail view (F004)
                } label: {
                    RecipeCard(recipe: recipe)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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

    RecipeListView(viewModel: RecipeListViewModel(recipeStore: store))
        .environment(FolderManager())
}

#Preview("Empty State") {
    RecipeListView(viewModel: RecipeListViewModel(recipeStore: RecipeStore()))
        .environment(FolderManager())
}

#Preview("Loading State") {
    @Previewable @State var store: RecipeStore = {
        let s = RecipeStore()
        s.isLoading = true
        return s
    }()

    RecipeListView(viewModel: RecipeListViewModel(recipeStore: store))
        .environment(FolderManager())
}
