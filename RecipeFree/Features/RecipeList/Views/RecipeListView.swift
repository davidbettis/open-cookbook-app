//
//  RecipeListView.swift
//  RecipeFree
//
//  iPhone recipe list view with NavigationStack
//

import SwiftUI
import RecipeMD

/// ViewModel for RecipeListView
@MainActor
@Observable
class RecipeListViewModel {

    // MARK: - Properties

    var recipeStore: RecipeStore
    var isRefreshing = false

    /// Search service for filtering recipes
    let searchService = RecipeSearchService()

    /// Recipes to display (filtered or all)
    var displayedRecipes: [RecipeFile] {
        if searchService.hasActiveFilters {
            return searchService.filteredRecipes
        }
        return recipeStore.recipes
    }

    // MARK: - Initialization

    init(recipeStore: RecipeStore) {
        self.recipeStore = recipeStore
    }

    // MARK: - Methods

    func loadRecipes(folder: URL) async {
        await recipeStore.loadRecipes(from: folder)
        searchService.updateRecipes(recipeStore.recipes)
    }

    func refresh() async {
        isRefreshing = true
        await recipeStore.refreshRecipes()
        searchService.updateRecipes(recipeStore.recipes)
        isRefreshing = false
    }

    /// Called when recipes change to update search index
    func syncSearchService() {
        searchService.updateRecipes(recipeStore.recipes)
    }
}

/// iPhone recipe list view using NavigationStack
struct RecipeListView: View {

    // MARK: - Properties

    @Environment(FolderManager.self) private var folderManager
    @State private var viewModel: RecipeListViewModel
    @State private var selectedError: (URL, Error)?
    @State private var showErrorAlert = false
    @State private var showAddRecipe = false
    @State private var recipeToDelete: RecipeFile?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: Error?
    @State private var showDeleteError = false

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
                } else if viewModel.recipeStore.recipes.isEmpty && !viewModel.searchService.hasActiveFilters {
                    // Show empty state (no recipes at all)
                    RecipeListEmptyState()
                } else {
                    // Show recipe list with search/filter
                    recipeListWithSearch
                }
            }
            .navigationTitle("Recipe Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Recipe")
                }
            }
            .navigationDestination(for: RecipeFile.self) { recipeFile in
                RecipeDetailView(recipeFile: recipeFile, recipeStore: viewModel.recipeStore)
            }
            .sheet(isPresented: $showAddRecipe) {
                RecipeFormView(
                    viewModel: RecipeFormViewModel(mode: .add),
                    recipeStore: viewModel.recipeStore,
                    onSave: { _ in
                        // Recipe already added to store, just sync search
                        viewModel.syncSearchService()
                    }
                )
            }
            .alert("Parse Error", isPresented: $showErrorAlert, presenting: selectedError) { _ in
                Button("OK") {
                    selectedError = nil
                }
            } message: { error in
                Text(error.1.localizedDescription)
            }
            .confirmationDialog(
                "Delete Recipe?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let recipeFile = recipeToDelete {
                        Task {
                            await deleteRecipe(recipeFile)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    recipeToDelete = nil
                }
            } message: {
                if let recipeFile = recipeToDelete {
                    Text("Are you sure you want to delete \"\(recipeFile.title)\"? This action cannot be undone.")
                }
            }
            .alert("Error Deleting Recipe", isPresented: $showDeleteError) {
                Button("OK") {
                    deleteError = nil
                }
            } message: {
                if let error = deleteError {
                    Text(error.localizedDescription)
                }
            }
            .task {
                // Load recipes on appear
                if let folder = folderManager.selectedFolderURL {
                    await viewModel.loadRecipes(folder: folder)
                }
            }
            .onChange(of: viewModel.recipeStore.recipes) { _, _ in
                viewModel.syncSearchService()
            }
        }
    }

    // MARK: - Subviews

    /// Recipe list with search bar and tag filter
    private var recipeListWithSearch: some View {
        VStack(spacing: 0) {
            // Search bar
            RecipeSearchBar(
                text: Binding(
                    get: { viewModel.searchService.searchText },
                    set: { viewModel.searchService.searchText = $0 }
                ),
                onClear: { viewModel.searchService.clearSearch() }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Tag filter bar (only show if there are tags)
            if !viewModel.searchService.availableTags.isEmpty {
                TagFilterBar(
                    tags: viewModel.searchService.availableTags,
                    selectedTags: viewModel.searchService.selectedTags,
                    onTagTap: { viewModel.searchService.toggleTag($0) },
                    onClearAll: { viewModel.searchService.clearTagFilters() }
                )
                .padding(.top, 8)
            }

            // Result count (when filtering)
            if viewModel.searchService.hasActiveFilters {
                HStack {
                    Text(viewModel.searchService.resultCountMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear All") {
                        viewModel.searchService.clearAllFilters()
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Recipe list or no results
            if viewModel.displayedRecipes.isEmpty && viewModel.searchService.hasActiveFilters {
                noResultsView
            } else {
                recipeList
            }
        }
    }

    /// Recipe list content
    private var recipeList: some View {
        List {
            // Show successfully parsed recipes
            ForEach(viewModel.displayedRecipes) { recipeFile in
                NavigationLink(value: recipeFile) {
                    RecipeCard(recipeFile: recipeFile)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        recipeToDelete = recipeFile
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Show parse errors (only when not filtering)
            if !viewModel.searchService.hasActiveFilters {
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
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Actions

    /// Delete a recipe
    private func deleteRecipe(_ recipeFile: RecipeFile) async {
        do {
            try await viewModel.recipeStore.deleteRecipe(recipeFile)
            recipeToDelete = nil
            viewModel.syncSearchService()
        } catch {
            deleteError = error
            showDeleteError = true
        }
    }

    /// No results view when search/filter returns empty
    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Recipes Found", systemImage: "magnifyingglass")
        } description: {
            Text("No recipes match your search")
        } actions: {
            Button("Clear Filters") {
                viewModel.searchService.clearAllFilters()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Previews

#Preview("With Recipes") {
    let store: RecipeStore = {
        let s = RecipeStore()
        s.recipes = [
            RecipeFile(
                filePath: URL(fileURLWithPath: "/tmp/cookies.md"),
                recipe: Recipe(
                    title: "Chocolate Chip Cookies",
                    description: "Classic homemade cookies",
                    tags: ["dessert", "baking"],
                    ingredientGroups: [IngredientGroup(ingredients: [
                        Ingredient(name: "flour"),
                        Ingredient(name: "sugar")
                    ])]
                )
            ),
            RecipeFile(
                filePath: URL(fileURLWithPath: "/tmp/pasta.md"),
                recipe: Recipe(
                    title: "Pasta Carbonara",
                    description: "Traditional Italian pasta dish",
                    tags: ["dinner", "italian", "quick"],
                    ingredientGroups: [IngredientGroup(ingredients: [
                        Ingredient(name: "pasta"),
                        Ingredient(name: "eggs")
                    ])]
                )
            ),
            RecipeFile(
                filePath: URL(fileURLWithPath: "/tmp/salad.md"),
                recipe: Recipe(
                    title: "Caesar Salad",
                    tags: ["lunch", "salad", "quick"],
                    ingredientGroups: [IngredientGroup(ingredients: [
                        Ingredient(name: "lettuce"),
                        Ingredient(name: "croutons")
                    ])]
                )
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
    let store: RecipeStore = {
        let s = RecipeStore()
        s.isLoading = true
        return s
    }()

    RecipeListView(viewModel: RecipeListViewModel(recipeStore: store))
        .environment(FolderManager())
}
