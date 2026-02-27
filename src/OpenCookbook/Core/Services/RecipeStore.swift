//
//  RecipeStore.swift
//  OpenCookbook
//
//  Central store for managing recipe collection
//

import Foundation
import RecipeMD
import SwiftUI

/// Central store for managing the recipe collection
@MainActor
@Observable
class RecipeStore {

    // MARK: - Properties

    /// All successfully parsed recipes
    var recipes: [RecipeFile] = []

    /// Parse errors for files that couldn't be parsed
    var parseErrors: [URL: Error] = [:]

    /// Loading state
    var isLoading = false

    /// Saving state
    var isSaving = false

    /// Parser for RecipeMD files
    private let parser: RecipeFileParser

    /// Serializer for converting recipes to markdown
    private let serializer: RecipeFileSerializer

    /// Filename generator for new recipes
    private let filenameGenerator: FilenameGenerator

    /// File monitor for watching folder changes
    private let fileMonitor: RecipeFileMonitor

    /// Cache of parsed recipes with modification dates
    private var recipeCache: [URL: CachedRecipeFile] = [:]

    // MARK: - Initialization

    init(
        parser: RecipeFileParser = RecipeFileParser(),
        serializer: RecipeFileSerializer = RecipeFileSerializer(),
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
    ///   - recipeFile: The recipe file to save (filePath will be generated)
    ///   - folder: The folder to save in
    /// - Returns: The saved recipe file with updated filePath
    /// - Throws: RecipeWriteError if save fails
    func saveNewRecipe(_ recipeFile: RecipeFile, in folder: URL) async throws -> RecipeFile {
        isSaving = true
        defer { isSaving = false }

        return try folder.withSecurityScopedAccess {
            // Generate unique filename
            let fileURL: URL
            do {
                fileURL = try filenameGenerator.generateFileURL(for: recipeFile.title, in: folder)
        } catch {
            throw RecipeWriteError.invalidFilename
        }

        // Serialize recipe to markdown
        let markdown = serializer.serialize(recipeFile)

        // Write to file atomically
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RecipeWriteError.writeError(underlying: error)
        }

        // Create new recipe file with correct file path
        let savedRecipeFile = RecipeFile(
            id: recipeFile.id,
            filePath: fileURL,
            recipe: recipeFile.recipe,
            fileModifiedDate: Date()
        )

        // Add to recipes array and cache with animation for smooth UI update
        withAnimation {
            recipes.append(savedRecipeFile)
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        recipeCache[fileURL] = CachedRecipeFile(recipeFile: savedRecipeFile, modificationDate: Date())

            return savedRecipeFile
        }
    }

    /// Update an existing recipe
    /// - Parameter recipeFile: The recipe file to update (uses existing filePath)
    /// - Throws: RecipeWriteError if update fails
    func updateRecipe(_ recipeFile: RecipeFile) async throws {
        isSaving = true
        defer { isSaving = false }

        let fileURL = recipeFile.filePath

        try fileURL.withSecurityScopedAccess {
            // Verify file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw RecipeWriteError.writeError(underlying: NSError(
                    domain: "RecipeStore",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Original file not found"]
                ))
            }

            // Serialize recipe to markdown
            let markdown = serializer.serialize(recipeFile)

        // Write to file atomically (overwrites existing)
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RecipeWriteError.writeError(underlying: error)
        }

        // Update recipe file with new modification date
        let updatedRecipeFile = RecipeFile(
            id: recipeFile.id,
            filePath: fileURL,
            recipe: recipeFile.recipe,
            fileModifiedDate: Date()
        )

        // Update recipes array with animation for smooth UI update
        withAnimation {
            if let index = recipes.firstIndex(where: { $0.id == recipeFile.id }) {
                recipes[index] = updatedRecipeFile
            }
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        // Update cache
        recipeCache[fileURL] = CachedRecipeFile(recipeFile: updatedRecipeFile, modificationDate: Date())
        }
    }

    /// Save a new recipe from raw markdown content
    /// - Parameters:
    ///   - markdown: The raw markdown string to write
    ///   - title: The recipe title (used for filename generation)
    ///   - folder: The folder to save in
    /// - Returns: The saved recipe file
    /// - Throws: RecipeWriteError if save fails
    func saveNewRecipeFromMarkdown(_ markdown: String, title: String, in folder: URL) async throws -> RecipeFile {
        isSaving = true
        defer { isSaving = false }

        return try folder.withSecurityScopedAccess {
            // Generate unique filename
            let fileURL: URL
            do {
                fileURL = try filenameGenerator.generateFileURL(for: title, in: folder)
        } catch {
            throw RecipeWriteError.invalidFilename
        }

        // Write raw markdown to file
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RecipeWriteError.writeError(underlying: error)
        }

        // Parse the written file to get a proper RecipeFile for the store
        let savedRecipeFile: RecipeFile
        do {
            savedRecipeFile = try parser.parse(from: fileURL)
        } catch {
            throw RecipeWriteError.serializationError
        }

        // Add to recipes array and cache with animation
        withAnimation {
            recipes.append(savedRecipeFile)
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        recipeCache[fileURL] = CachedRecipeFile(recipeFile: savedRecipeFile, modificationDate: Date())

            return savedRecipeFile
        }
    }

    /// Update an existing recipe from raw markdown content
    /// - Parameters:
    ///   - markdown: The raw markdown string to write
    ///   - filePath: The file URL to overwrite
    /// - Throws: RecipeWriteError if update fails
    func updateRecipeFromMarkdown(_ markdown: String, filePath: URL) async throws {
        isSaving = true
        defer { isSaving = false }

        let fileURL = filePath

        try fileURL.withSecurityScopedAccess {
            // Verify file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw RecipeWriteError.writeError(underlying: NSError(
                domain: "RecipeStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Original file not found"]
            ))
        }

        // Write raw markdown to file
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RecipeWriteError.writeError(underlying: error)
        }

        // Re-parse to update the store's in-memory RecipeFile
        let updatedRecipeFile: RecipeFile
        do {
            updatedRecipeFile = try parser.parse(from: fileURL)
        } catch {
            throw RecipeWriteError.serializationError
        }

        // Update recipes array with animation
        withAnimation {
            if let index = recipes.firstIndex(where: { $0.filePath == fileURL }) {
                recipes[index] = updatedRecipeFile
            }
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        // Update cache
        recipeCache[fileURL] = CachedRecipeFile(recipeFile: updatedRecipeFile, modificationDate: Date())
        }
    }

    /// Delete a recipe
    /// - Parameter recipeFile: The recipe file to delete
    /// - Throws: RecipeDeleteError if deletion fails
    func deleteRecipe(_ recipeFile: RecipeFile) async throws {
        let fileURL = recipeFile.filePath

        try fileURL.withSecurityScopedAccess {
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

        // Remove from recipes array with animation for smooth UI update
        withAnimation {
            recipes.removeAll { $0.id == recipeFile.id }
        }

        // Remove from cache
        recipeCache.removeValue(forKey: fileURL)

        // Remove from parse errors if present
        parseErrors.removeValue(forKey: fileURL)
        }
    }

    // MARK: - Bulk Operations

    /// Add tags to multiple recipes at once
    /// - Parameters:
    ///   - tags: Tags to add
    ///   - recipeIDs: IDs of recipes to update
    /// - Returns: Result with success and failure counts
    func bulkAddTags(_ tags: Set<String>, to recipeIDs: Set<UUID>) -> BulkOperationResult {
        var successCount = 0
        var failures: [(RecipeFile, Error)] = []

        for id in recipeIDs {
            guard let index = recipes.firstIndex(where: { $0.id == id }) else { continue }
            let recipeFile = recipes[index]

            do {
                var updated = recipeFile
                var tagSet = Set(updated.recipe.tags)
                tagSet.formUnion(tags)
                updated.recipe.tags = Array(tagSet).sorted()
                updated.fileModifiedDate = Date()

                try recipeFile.filePath.withSecurityScopedAccess {
                    let markdown = serializer.serialize(updated)
                    try markdown.write(to: recipeFile.filePath, atomically: true, encoding: .utf8)
                }

                recipes[index] = updated
                recipeCache[recipeFile.filePath] = CachedRecipeFile(recipeFile: updated, modificationDate: Date())
                successCount += 1
            } catch {
                failures.append((recipeFile, error))
            }
        }

        withAnimation {
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        return BulkOperationResult(successCount: successCount, failureCount: failures.count, failedRecipes: failures)
    }

    /// Remove tags from multiple recipes at once
    /// - Parameters:
    ///   - tags: Tags to remove
    ///   - recipeIDs: IDs of recipes to update
    /// - Returns: Result with success and failure counts
    func bulkRemoveTags(_ tags: Set<String>, from recipeIDs: Set<UUID>) -> BulkOperationResult {
        var successCount = 0
        var failures: [(RecipeFile, Error)] = []

        for id in recipeIDs {
            guard let index = recipes.firstIndex(where: { $0.id == id }) else { continue }
            let recipeFile = recipes[index]

            do {
                var updated = recipeFile
                updated.recipe.tags = recipeFile.recipe.tags.filter { !tags.contains($0) }
                updated.fileModifiedDate = Date()

                try recipeFile.filePath.withSecurityScopedAccess {
                    let markdown = serializer.serialize(updated)
                    try markdown.write(to: recipeFile.filePath, atomically: true, encoding: .utf8)
                }

                recipes[index] = updated
                recipeCache[recipeFile.filePath] = CachedRecipeFile(recipeFile: updated, modificationDate: Date())
                successCount += 1
            } catch {
                failures.append((recipeFile, error))
            }
        }

        withAnimation {
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        return BulkOperationResult(successCount: successCount, failureCount: failures.count, failedRecipes: failures)
    }

    // MARK: - Private Methods

    /// Parse all recipe files from the monitored folder
    private func parseAllRecipes() {
        let fileURLs = fileMonitor.fileURLs

        // Clear current state
        var newRecipes: [RecipeFile] = []
        var newErrors: [URL: Error] = [:]

        // Parse files sequentially (fast for small collections)
        for url in fileURLs {
            let result = parseRecipeFile(at: url)
            switch result {
            case .success(let recipeFile):
                newRecipes.append(recipeFile)
            case .failure(let error):
                newErrors[url] = error
            }
        }

        // Sort recipes by title
        newRecipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        // Update state with animation for smooth UI update
        withAnimation {
            recipes = newRecipes
            parseErrors = newErrors
        }
    }

    /// Parse a single recipe file with caching
    /// - Parameter url: The file URL to parse
    /// - Returns: Result containing RecipeFile or Error
    private func parseRecipeFile(at url: URL) -> Result<RecipeFile, Error> {
        // Get file modification date
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attributes?[.modificationDate] as? Date ?? Date()

        // Check cache
        if let cached = recipeCache[url],
           cached.modificationDate == modDate {
            return .success(cached.recipeFile)
        }

        // Parse file
        do {
            let recipeFile = try parser.parse(from: url)

            // Update cache
            recipeCache[url] = CachedRecipeFile(recipeFile: recipeFile, modificationDate: modDate)

            return .success(recipeFile)
        } catch {
            // Remove from cache if parsing fails
            recipeCache.removeValue(forKey: url)
            return .failure(error)
        }
    }

    // MARK: - Helper Types

    /// Cached recipe file with modification date for cache invalidation
    private struct CachedRecipeFile {
        let recipeFile: RecipeFile
        let modificationDate: Date
    }
}
