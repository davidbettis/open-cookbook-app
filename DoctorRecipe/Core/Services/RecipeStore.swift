//
//  RecipeStore.swift
//  DoctorRecipe
//
//  Central store for managing recipe collection
//

import Foundation

/// Central store for managing the recipe collection
@MainActor
@Observable
class RecipeStore {

    // MARK: - Properties

    /// All successfully parsed recipes
    var recipes: [Recipe] = []

    /// Parse errors for files that couldn't be parsed
    var parseErrors: [URL: Error] = [:]

    /// Loading state
    var isLoading = false

    /// Parser for RecipeMD files
    private let parser: RecipeMDParser

    /// File monitor for watching folder changes
    private let fileMonitor: RecipeFileMonitor

    /// Cache of parsed recipes with modification dates
    private var recipeCache: [URL: CachedRecipe] = [:]

    // MARK: - Initialization

    init(parser: RecipeMDParser = RecipeMDParser(), fileMonitor: RecipeFileMonitor = RecipeFileMonitor()) {
        self.parser = parser
        self.fileMonitor = fileMonitor

        // Set up file change callback
        fileMonitor.onFilesChanged = { [weak self] in
            Task {
                await self?.refreshRecipes()
            }
        }
    }

    // MARK: - Public Methods

    /// Load recipes from a folder
    /// - Parameter folder: The folder URL containing .md files
    func loadRecipes(from folder: URL) {
        isLoading = true
        defer { isLoading = false }

        // Start monitoring folder
        fileMonitor.startMonitoring(folder: folder)

        // Parse all files
        parseAllRecipes()
    }

    /// Refresh recipes (re-scan folder and re-parse changed files)
    func refreshRecipes() {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        // Rescan folder
        fileMonitor.scanFolder()

        // Parse all files
        parseAllRecipes()
    }

    /// Stop monitoring and clear all data
    func reset() {
        fileMonitor.stopMonitoring()
        recipes = []
        parseErrors = [:]
        recipeCache = [:]
    }

    // MARK: - Private Methods

    /// Parse all recipe files from the monitored folder
    private func parseAllRecipes() {
        let fileURLs = fileMonitor.fileURLs

        // Clear current state
        var newRecipes: [Recipe] = []
        var newErrors: [URL: Error] = [:]

        // Parse files sequentially (fast for small collections)
        for url in fileURLs {
            let result = parseRecipe(at: url)
            switch result {
            case .success(let recipe):
                newRecipes.append(recipe)
            case .failure(let error):
                newErrors[url] = error
            }
        }

        // Sort recipes by title
        newRecipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        // Update state
        recipes = newRecipes
        parseErrors = newErrors
    }

    /// Parse a single recipe file with caching
    /// - Parameter url: The file URL to parse
    /// - Returns: Result containing Recipe or Error
    private func parseRecipe(at url: URL) -> Result<Recipe, Error> {
        // Get file modification date
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attributes?[.modificationDate] as? Date ?? Date()

        // Check cache
        if let cached = recipeCache[url],
           cached.modificationDate == modDate {
            return .success(cached.recipe)
        }

        // Parse file
        do {
            let recipe = try parser.parseMetadata(from: url)

            // Update cache
            recipeCache[url] = CachedRecipe(recipe: recipe, modificationDate: modDate)

            return .success(recipe)
        } catch {
            // Remove from cache if parsing fails
            recipeCache.removeValue(forKey: url)
            return .failure(error)
        }
    }

    // MARK: - Helper Types

    /// Cached recipe with modification date for cache invalidation
    private struct CachedRecipe {
        let recipe: Recipe
        let modificationDate: Date
    }
}
