//
//  RecipeStore.swift
//  OpenCookbook
//
//  Central store for managing recipe collection
//

import Foundation
import RecipeMD
import SwiftUI

extension Notification.Name {
    /// Posted when a recipe's content is updated. The notification's `object` is the recipe's `UUID`.
    static let recipeDidUpdate = Notification.Name("recipeDidUpdate")
}

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

    /// Cache of parsed recipes keyed by file URL
    private var recipeCache: [URL: RecipeFile] = [:]

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
            let fileURL = try generateFileURL(for: recipeFile.title, in: folder)
            let markdown = serializer.serialize(recipeFile)
            try writeMarkdown(markdown, to: fileURL)

            let savedRecipeFile = RecipeFile(
                id: recipeFile.id,
                filePath: fileURL,
                recipe: recipeFile.recipe,
                fileModifiedDate: Date()
            )

            insertInStore(savedRecipeFile)
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
            try verifyFileExists(at: fileURL)
            let markdown = serializer.serialize(recipeFile)
            try writeMarkdown(markdown, to: fileURL)

            let updatedRecipeFile = RecipeFile(
                id: recipeFile.id,
                filePath: fileURL,
                recipe: recipeFile.recipe,
                fileModifiedDate: Date()
            )

            replaceInStore(updatedRecipeFile)
            NotificationCenter.default.post(name: .recipeDidUpdate, object: recipeFile.id)
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
            let fileURL = try generateFileURL(for: title, in: folder)
            try writeMarkdown(markdown, to: fileURL)
            let savedRecipeFile = try parseWrittenFile(at: fileURL)

            insertInStore(savedRecipeFile)
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

        try filePath.withSecurityScopedAccess {
            try verifyFileExists(at: filePath)
            try writeMarkdown(markdown, to: filePath)
            let updatedRecipeFile = try parseWrittenFile(at: filePath)

            replaceInStore(updatedRecipeFile)
            NotificationCenter.default.post(name: .recipeDidUpdate, object: updatedRecipeFile.id)
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
    func bulkAddTags(_ tags: Set<String>, to recipeIDs: Set<UUID>) -> BulkOperationResult {
        bulkModifyTags(for: recipeIDs) { existingTags in
            var tagSet = Set(existingTags)
            tagSet.formUnion(tags)
            existingTags = Array(tagSet).sorted()
        }
    }

    /// Remove tags from multiple recipes at once
    func bulkRemoveTags(_ tags: Set<String>, from recipeIDs: Set<UUID>) -> BulkOperationResult {
        bulkModifyTags(for: recipeIDs) { existingTags in
            existingTags = existingTags.filter { !tags.contains($0) }
        }
    }

    // MARK: - Private Helpers

    /// Generate a unique file URL for a new recipe
    private func generateFileURL(for title: String, in folder: URL) throws -> URL {
        do {
            return try filenameGenerator.generateFileURL(for: title, in: folder)
        } catch {
            throw RecipeWriteError.invalidFilename
        }
    }

    /// Write markdown content to a file atomically
    private func writeMarkdown(_ markdown: String, to fileURL: URL) throws {
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RecipeWriteError.writeError(underlying: error)
        }
    }

    /// Verify that a file exists at the given URL
    private func verifyFileExists(at fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw RecipeWriteError.writeError(underlying: NSError(
                domain: "RecipeStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Original file not found"]
            ))
        }
    }

    /// Parse a freshly-written file back into a RecipeFile
    private func parseWrittenFile(at fileURL: URL) throws -> RecipeFile {
        do {
            return try parser.parse(from: fileURL)
        } catch {
            throw RecipeWriteError.serializationError
        }
    }

    /// Add a new recipe to the store and cache
    private func insertInStore(_ recipeFile: RecipeFile) {
        withAnimation {
            recipes.append(recipeFile)
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        recipeCache[recipeFile.filePath] = recipeFile
    }

    /// Replace an existing recipe in the store and cache
    private func replaceInStore(_ recipeFile: RecipeFile) {
        withAnimation {
            if let index = recipes.firstIndex(where: { $0.id == recipeFile.id || $0.filePath == recipeFile.filePath }) {
                recipes[index] = recipeFile
            }
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        recipeCache[recipeFile.filePath] = recipeFile
    }

    /// Shared implementation for bulk tag add/remove operations
    private func bulkModifyTags(for recipeIDs: Set<UUID>, mutation: (inout [String]) -> Void) -> BulkOperationResult {
        var successCount = 0
        var failures: [(RecipeFile, Error)] = []

        for id in recipeIDs {
            guard let index = recipes.firstIndex(where: { $0.id == id }) else { continue }
            let recipeFile = recipes[index]

            do {
                var updated = recipeFile
                mutation(&updated.recipe.tags)
                updated.fileModifiedDate = Date()

                try recipeFile.filePath.withSecurityScopedAccess {
                    let markdown = serializer.serialize(updated)
                    try markdown.write(to: recipeFile.filePath, atomically: true, encoding: .utf8)
                }

                recipes[index] = updated
                recipeCache[recipeFile.filePath] = updated
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

    // MARK: - Parsing

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
        let modDate = attributes?[.modificationDate] as? Date

        // Check cache — reuse if file hasn't changed
        if let cached = recipeCache[url],
           modDate != nil,
           cached.fileModifiedDate == modDate {
            return .success(cached)
        }

        // Parse file
        do {
            let recipeFile = try parser.parse(from: url)
            recipeCache[url] = recipeFile
            return .success(recipeFile)
        } catch {
            recipeCache.removeValue(forKey: url)
            return .failure(error)
        }
    }
}
