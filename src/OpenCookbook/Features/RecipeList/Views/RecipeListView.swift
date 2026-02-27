//
//  RecipeListView.swift
//  OpenCookbook
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

    // MARK: - Edit Mode

    /// Whether bulk edit mode is active
    var isEditMode = false

    /// IDs of selected recipes in edit mode
    var selectedRecipeIDs: Set<UUID> = []

    /// Number of currently selected recipes
    var selectedCount: Int { selectedRecipeIDs.count }

    /// Toggle selection of a recipe
    func toggleSelection(_ recipeID: UUID) {
        if selectedRecipeIDs.contains(recipeID) {
            selectedRecipeIDs.remove(recipeID)
        } else {
            selectedRecipeIDs.insert(recipeID)
        }
    }

    /// Enter edit mode
    func enterEditMode() {
        isEditMode = true
        selectedRecipeIDs = []
    }

    /// Exit edit mode and clear selection
    func exitEditMode() {
        isEditMode = false
        selectedRecipeIDs = []
    }

    /// Get tags present on selected recipes with per-tag counts
    func tagsOnSelectedRecipes() -> [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for id in selectedRecipeIDs {
            guard let recipe = recipeStore.recipes.first(where: { $0.id == id }) else { continue }
            for tag in recipe.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts.map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count || ($0.count == $1.count && $0.tag < $1.tag) }
    }

    /// Bulk add tags to selected recipes
    func bulkAddTags(_ tags: Set<String>) -> BulkOperationResult {
        let result = recipeStore.bulkAddTags(tags, to: selectedRecipeIDs)
        syncSearchService()
        return result
    }

    /// Bulk remove tags from selected recipes
    func bulkRemoveTags(_ tags: Set<String>) -> BulkOperationResult {
        let result = recipeStore.bulkRemoveTags(tags, from: selectedRecipeIDs)
        syncSearchService()
        return result
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
    @State private var importSource: ImportRecipeViewModel.ImportSource?
    @State private var importedFormViewModel: RecipeFormViewModel?
    @State private var pendingImportMarkdown: String?
    @State private var recipeToDelete: RecipeFile?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: Error?
    @State private var showDeleteError = false

    // Bulk edit mode state
    @State private var showBulkAddTags = false
    @State private var showBulkRemoveTags = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastStyle: ToastStyle = .success

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.recipeStore.recipes.isEmpty {
                        Button(viewModel.isEditMode ? "Done" : "Select") {
                            if viewModel.isEditMode {
                                viewModel.exitEditMode()
                            } else {
                                viewModel.enterEditMode()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Image("AppIconSmall")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Open Cookbook")
                }
                if !viewModel.isEditMode {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showAddRecipe = true
                            } label: {
                                Label("New Recipe", systemImage: "square.and.pencil")
                            }
                            Button {
                                importSource = .website
                            } label: {
                                Label("Import from Website", systemImage: "globe")
                            }
                            Button {
                                importSource = .photo
                            } label: {
                                Label("Import from Photo", systemImage: "camera")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Recipe")
                    }
                }
            }
            .navigationDestination(for: RecipeFile.self) { recipeFile in
                RecipeDetailView(recipeFile: recipeFile, recipeStore: viewModel.recipeStore)
            }
            .fullScreenCover(isPresented: $showAddRecipe) {
                RecipeFormView(
                    viewModel: RecipeFormViewModel(mode: .add),
                    recipeStore: viewModel.recipeStore,
                    tagFrequencies: RecipeSearchService.computeTagFrequencies(from: viewModel.recipeStore.recipes),
                    onSave: { _ in viewModel.syncSearchService() }
                )
            }
            .fullScreenCover(item: $importedFormViewModel) { formVM in
                RecipeFormView(
                    viewModel: formVM,
                    recipeStore: viewModel.recipeStore,
                    tagFrequencies: RecipeSearchService.computeTagFrequencies(from: viewModel.recipeStore.recipes),
                    onSave: { _ in viewModel.syncSearchService() }
                )
            }
            .sheet(item: $importSource) { source in
                ImportRecipeView(
                    initialSource: source,
                    tagPrompt: RecipeSearchService.tagFrequencyPrompt(from: viewModel.recipeStore.recipes)
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .importRecipeCompleted)) { notification in
                guard let markdown = notification.userInfo?["markdown"] as? String else { return }
                pendingImportMarkdown = markdown
            }
            .onChange(of: importSource) { _, newValue in
                if newValue == nil, let markdown = pendingImportMarkdown {
                    pendingImportMarkdown = nil
                    handleImportedRecipe(markdown)
                }
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
            .sheet(isPresented: $showBulkAddTags) {
                BulkTagAddView(
                    selectedCount: viewModel.selectedCount,
                    tagFrequencies: RecipeSearchService.computeTagFrequencies(from: viewModel.recipeStore.recipes),
                    onApply: { tags in
                        handleBulkResult(viewModel.bulkAddTags(tags), verb: "Added", tagCount: tags.count)
                    }
                )
            }
            .sheet(isPresented: $showBulkRemoveTags) {
                BulkTagRemoveView(
                    totalSelected: viewModel.selectedCount,
                    tagsWithCounts: viewModel.tagsOnSelectedRecipes(),
                    onApply: { tags in
                        handleBulkResult(viewModel.bulkRemoveTags(tags), verb: "Removed", tagCount: tags.count)
                    }
                )
            }
            .toast(isPresented: $showToast, message: toastMessage, style: toastStyle)
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

            // Bottom toolbar for edit mode
            if viewModel.isEditMode {
                editModeBottomBar
            }
        }
    }

    /// Recipe list content
    private var recipeList: some View {
        List {
            // Show successfully parsed recipes
            ForEach(viewModel.displayedRecipes) { recipeFile in
                if viewModel.isEditMode {
                    Button {
                        viewModel.toggleSelection(recipeFile.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: viewModel.selectedRecipeIDs.contains(recipeFile.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(viewModel.selectedRecipeIDs.contains(recipeFile.id) ? Color.accentColor : .secondary)
                                .font(.title3)
                            RecipeCard(recipeFile: recipeFile)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } else {
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
            }

            // Show parse errors (only when not filtering, not in edit mode)
            if !viewModel.searchService.hasActiveFilters && !viewModel.isEditMode {
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
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await viewModel.refresh()
        }
    }

    /// Bottom toolbar shown during edit mode
    private var editModeBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("\(viewModel.selectedCount) Selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Tags") {
                    showBulkAddTags = true
                }
                .disabled(viewModel.selectedCount == 0)
                Button("Remove Tags") {
                    showBulkRemoveTags = true
                }
                .disabled(viewModel.selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
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

    /// Handle the result of a bulk tag operation
    private func handleBulkResult(_ result: BulkOperationResult, verb: String, tagCount: Int) {
        if result.failureCount == 0 {
            toastMessage = "\(verb) \(tagCount) \(tagCount == 1 ? "tag" : "tags") \(verb == "Added" ? "to" : "from") \(result.successCount) \(result.successCount == 1 ? "recipe" : "recipes")"
            toastStyle = .success
            viewModel.exitEditMode()
        } else if result.successCount > 0 {
            toastMessage = "Updated \(result.successCount) of \(result.successCount + result.failureCount) recipes. \(result.failureCount) could not be updated."
            toastStyle = .error
            // Keep edit mode active with failed recipes still selected
            let failedIDs = Set(result.failedRecipes.map { $0.0.id })
            viewModel.selectedRecipeIDs = failedIDs
        } else {
            toastMessage = "Could not update any recipes."
            toastStyle = .error
        }
        withAnimation {
            showToast = true
        }
    }

    /// Handle imported recipe markdown by parsing and pre-populating the form.
    /// Setting importedFormViewModel triggers the item-based fullScreenCover.
    private func handleImportedRecipe(_ markdown: String) {
        let parser = RecipeMDParser()
        let formVM = RecipeFormViewModel(mode: .add)
        if let recipe = try? parser.parse(markdown) {
            let tempFile = RecipeFile(
                filePath: URL(fileURLWithPath: "/tmp/imported-recipe.md"),
                recipe: recipe
            )
            formVM.populateFromRecipeFile(tempFile)
        }
        // Always set — the item-based fullScreenCover will present
        importedFormViewModel = formVM
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
