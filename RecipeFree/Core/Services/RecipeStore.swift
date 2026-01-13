//
//  RecipeStore.swift
//  RecipeFree
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

    /// Saving state
    var isSaving = false

    /// Parser for RecipeMD files
    private let parser: RecipeMDParser

    /// Serializer for converting recipes to markdown
    private let serializer: RecipeMDSerializer

    /// Filename generator for new recipes
    private let filenameGenerator: FilenameGenerator

    /// File monitor for watching folder changes
    private let fileMonitor: RecipeFileMonitor

    /// Cache of parsed recipes with modification dates
    private var recipeCache: [URL: CachedRecipe] = [:]

    // MARK: - Initialization

    init(
        parser: RecipeMDParser = RecipeMDParser(),
        serializer: RecipeMDSerializer = RecipeMDSerializer(),
        filenameGenerator: FilenameGenerator = FilenameGenerator(),
        fileMonitor: RecipeFileMonitor = RecipeFileMonitor()
    ) {
        self.parser = parser
        self.serializer = serializer
        self.filenameGenerator = filenameGenerator
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

    // MARK: - CRUD Operations

    /// Save a new recipe to the folder
    /// - Parameters:
    ///   - recipe: The recipe to save (filePath will be generated)
    ///   - folder: The folder to save in
    /// - Returns: The saved recipe with updated filePath
    /// - Throws: RecipeWriteError if save fails
    func saveNewRecipe(_ recipe: Recipe, in folder: URL) async throws -> Recipe {
        isSaving = true
        defer { isSaving = false }

        // Start accessing security-scoped resource
        let didStartAccess = folder.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                folder.stopAccessingSecurityScopedResource()
            }
        }

        // Generate unique filename
        let fileURL: URL
        do {
            fileURL = try filenameGenerator.generateFileURL(for: recipe.title, in: folder)
        } catch {
            throw RecipeWriteError.invalidFilename
        }

        // Serialize recipe to markdown
        let markdown = serializer.serialize(recipe)

        // Write to file atomically
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RecipeWriteError.writeError(underlying: error)
        }

        // Create new recipe with correct file path
        let savedRecipe = Recipe(
            id: recipe.id,
            filePath: fileURL,
            title: recipe.title,
            description: recipe.description,
            tags: recipe.tags,
            yields: recipe.yields,
            ingredients: recipe.ingredients,
            ingredientGroups: recipe.ingredientGroups,
            instructions: recipe.instructions,
            fileModifiedDate: Date()
        )

        // Add to recipes array and cache
        recipes.append(savedRecipe)
        recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        recipeCache[fileURL] = CachedRecipe(recipe: savedRecipe, modificationDate: Date())

        return savedRecipe
    }

    /// Update an existing recipe
    /// - Parameter recipe: The recipe to update (uses existing filePath)
    /// - Throws: RecipeWriteError if update fails
    func updateRecipe(_ recipe: Recipe) async throws {
        isSaving = true
        defer { isSaving = false }

        let fileURL = recipe.filePath

        // Start accessing security-scoped resource
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw RecipeWriteError.writeError(underlying: NSError(
                domain: "RecipeStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Original file not found"]
            ))
        }

        // Serialize recipe to markdown
        let markdown = serializer.serialize(recipe)

        // Write to file atomically (overwrites existing)
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RecipeWriteError.writeError(underlying: error)
        }

        // Update recipe in array
        let updatedRecipe = Recipe(
            id: recipe.id,
            filePath: fileURL,
            title: recipe.title,
            description: recipe.description,
            tags: recipe.tags,
            yields: recipe.yields,
            ingredients: recipe.ingredients,
            ingredientGroups: recipe.ingredientGroups,
            instructions: recipe.instructions,
            fileModifiedDate: Date()
        )

        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = updatedRecipe
        }
        recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        // Update cache
        recipeCache[fileURL] = CachedRecipe(recipe: updatedRecipe, modificationDate: Date())
    }

    /// Delete a recipe
    /// - Parameter recipe: The recipe to delete
    /// - Throws: RecipeDeleteError if deletion fails
    func deleteRecipe(_ recipe: Recipe) async throws {
        let fileURL = recipe.filePath

        // Start accessing security-scoped resource
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)

        if fileExists {
            // Try to delete
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch let error as NSError {
                // Check for specific error codes
                if error.domain == NSCocoaErrorDomain {
                    switch error.code {
                    case CocoaError.fileNoSuchFile.rawValue:
                        // File already deleted, continue to remove from store
                        break
                    case CocoaError.fileWriteNoPermission.rawValue:
                        throw RecipeDeleteError.permissionDenied
                    case 640:  // File busy error code
                        throw RecipeDeleteError.fileLocked
                    default:
                        throw RecipeDeleteError.deleteError(underlying: error)
                    }
                } else {
                    throw RecipeDeleteError.deleteError(underlying: error)
                }
            }
        }

        // Remove from recipes array
        recipes.removeAll { $0.id == recipe.id }

        // Remove from cache
        recipeCache.removeValue(forKey: fileURL)

        // Remove from parse errors if present
        parseErrors.removeValue(forKey: fileURL)
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
