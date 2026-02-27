//
//  RecipeListSplitView.swift
//  OpenCookbook
//
//  iPad recipe list view with NavigationSplitView
//

import SwiftUI
import RecipeMD

/// iPad recipe list view using NavigationSplitView
struct RecipeListSplitView: View {

    // MARK: - Properties

    @Environment(FolderManager.self) private var folderManager
    @State private var viewModel: RecipeListViewModel
    @State private var selectedRecipeFile: RecipeFile?
    @State private var selectedError: (URL, Error)?
    @State private var showErrorAlert = false
    @State private var showAddRecipe = false
    @State private var importSource: ImportRecipeViewModel.ImportSource?
    @State private var importedFormViewModel: RecipeFormViewModel?
    @State private var pendingImportMarkdown: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("isLibraryExpanded") private var isLibraryExpanded = false

    // MARK: - Initialization

    init(viewModel: RecipeListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Recipe List
            sidebarContent
                .navigationTitle("Recipes")
                .navigationBarTitleDisplayMode(.inline)
                .navigationSplitViewColumnWidth(
                    min: isLibraryExpanded ? 1000 : 300,
                    ideal: isLibraryExpanded ? 2000 : 350,
                    max: isLibraryExpanded ? .infinity : 500
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            toggleLibraryExpansion()
                        } label: {
                            Image(systemName: isLibraryExpanded
                                ? "arrow.down.right.and.arrow.up.left"
                                : "arrow.up.left.and.arrow.down.right")
                        }
                        .accessibilityLabel(isLibraryExpanded ? "Collapse Library" : "Expand Library")
                    }

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
        .onChange(of: viewModel.recipeStore.recipes) { _, _ in
            viewModel.syncSearchService()
        }
        .onChange(of: selectedRecipeFile) { _, newValue in
            if newValue != nil {
                withAnimation {
                    columnVisibility = .detailOnly
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
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
    }

    // MARK: - Actions

    private func toggleLibraryExpansion() {
        withAnimation {
            isLibraryExpanded.toggle()
            if isLibraryExpanded {
                columnVisibility = .all
            }
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
        importedFormViewModel = formVM
    }

    // MARK: - Subviews

    @ViewBuilder
    private var sidebarContent: some View {
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
                sidebarWithSearch
            }
        }
    }

    /// Sidebar with search bar and tag filter
    private var sidebarWithSearch: some View {
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

    private var recipeList: some View {
        List(selection: $selectedRecipeFile) {
            // Show successfully parsed recipes
            ForEach(viewModel.displayedRecipes) { recipeFile in
                Button {
                    selectedRecipeFile = recipeFile
                } label: {
                    RecipeCard(recipeFile: recipeFile)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(
                    selectedRecipeFile?.id == recipeFile.id ?
                    Color.accentColor.opacity(0.1) : Color.clear
                )
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
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await viewModel.refresh()
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

    @ViewBuilder
    private var detailContent: some View {
        if let recipeFile = selectedRecipeFile {
            RecipeDetailView(recipeFile: recipeFile, recipeStore: viewModel.recipeStore)
        } else {
            // No selection
            ContentUnavailableView(
                "Select a Recipe",
                systemImage: "book",
                description: Text("Tap on the \(Image(systemName: "sidebar.left")) icon to view a recipe from your library")
            )
        }
    }
}

// MARK: - Placeholder Detail View

/// Temporary placeholder until F004 implements full detail view
struct RecipeDetailPlaceholder: View {

    let recipeFile: RecipeFile

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(recipeFile.title)
                .font(.title)
                .fontWeight(.semibold)

            if let description = recipeFile.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if !recipeFile.tags.isEmpty {
                HStack {
                    ForEach(recipeFile.tags, id: \.self) { tag in
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
        .navigationTitle(recipeFile.title)
        .navigationBarTitleDisplayMode(.inline)
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

    RecipeListSplitView(viewModel: RecipeListViewModel(recipeStore: store))
        .environment(FolderManager())
}

#Preview("Empty State") {
    RecipeListSplitView(viewModel: RecipeListViewModel(recipeStore: RecipeStore()))
        .environment(FolderManager())
}
