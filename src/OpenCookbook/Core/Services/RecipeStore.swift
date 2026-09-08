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

    /// Progress during `loadRecipes` / `refreshRecipes`; `nil` when not loading.
    var loadingProgress: LoadingProgress? = nil

    /// Number of recipe files waiting for iCloud to download their content.
    var pendingDownloadCount: Int = 0

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

    /// URLs of files currently waiting for iCloud to make their content available.
    private var pendingDownloadURLs: Set<URL> = []

    /// Re-triggers iCloud download for stalled files after a timeout.
    private var downloadStallTask: Task<Void, Never>?

    /// Set when a refresh is requested while a load is already running; the
    /// in-flight load re-runs once it finishes so monitor events are coalesced
    /// rather than dropped.
    private var pendingReload = false

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
    func loadRecipes(from folder: URL) async {
        // The library container and the list/split view both load on appear, so
        // this can be called twice for the same folder. A second concurrent pass
        // duplicates every file read for no benefit, so let the first one finish.
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        fileMonitor.startMonitoring(folder: folder)
        await reloadFromMonitor()
    }

    /// Refresh recipes (re-scan folder and re-parse changed files)
    func refreshRecipes() async {
        // A load is already running — record that another pass is needed and let
        // the in-flight load pick it up when it finishes, rather than dropping
        // this monitor event (e.g. an iCloud download that lands mid-load).
        guard !isLoading else {
            pendingReload = true
            return
        }

        // A file arrived — cancel any pending stall timer.
        downloadStallTask?.cancel()
        downloadStallTask = nil

        isLoading = true
        defer { isLoading = false }

        fileMonitor.scanFolder()
        await reloadFromMonitor()
    }

    /// Stop monitoring and clear all data
    func reset() {
        downloadStallTask?.cancel()
        downloadStallTask = nil
        fileMonitor.stopMonitoring()
        recipes = []
        parseErrors = [:]
        recipeCache = [:]
        pendingDownloadURLs = []
        pendingDownloadCount = 0
        loadingProgress = nil
        pendingReload = false
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
    /// - Returns: The updated recipe file after re-parsing from disk
    /// - Throws: RecipeWriteError if update fails
    @discardableResult
    func updateRecipe(_ recipeFile: RecipeFile) async throws -> RecipeFile {
        isSaving = true
        defer { isSaving = false }

        let fileURL = recipeFile.filePath

        return try fileURL.withSecurityScopedAccess {
            try verifyFileExists(at: fileURL)
            let markdown = serializer.serialize(recipeFile)
            try writeMarkdown(markdown, to: fileURL)

            // Re-parse the written file so the parser can extract supplemental amounts
            let reparsed = try parseWrittenFile(at: fileURL)
            let updatedRecipeFile = RecipeFile(
                id: recipeFile.id,
                filePath: fileURL,
                recipe: reparsed.recipe,
                fileModifiedDate: Date()
            )

            replaceInStore(updatedRecipeFile)
            NotificationCenter.default.post(name: .recipeDidUpdate, object: recipeFile.id)
            return updatedRecipeFile
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
            let reparsed = try parseWrittenFile(at: filePath)

            // Preserve the original recipe's ID so views can find it
            let originalID = recipes.first(where: { $0.filePath == filePath })?.id ?? reparsed.id
            let updatedRecipeFile = RecipeFile(
                id: originalID,
                filePath: filePath,
                recipe: reparsed.recipe,
                fileModifiedDate: Date()
            )

            replaceInStore(updatedRecipeFile)
            NotificationCenter.default.post(name: .recipeDidUpdate, object: originalID)
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

    /// Reload the library from the monitor's current file list, coalescing any
    /// monitor events that arrive while the pass is running.
    private func reloadFromMonitor() async {
        await performLoadPass()

        // A monitor event arrived while we were loading — fold it into one more
        // pass instead of dropping it. `isLoading` is still true here (the
        // caller's defer hasn't run), so further events keep coalescing. This
        // loops rather than recursing so a folder that keeps changing during a
        // long load doesn't grow the async stack without bound.
        while pendingReload {
            pendingReload = false
            fileMonitor.scanFolder()
            await performLoadPass()
        }

        scheduleDownloadStallCheck()
    }

    /// One load pass: resolve each file's metadata and content off the main
    /// actor, then parse and publish on it.
    ///
    /// Reads run through a sliding window rather than one child task per file.
    /// iCloud-backed files are served by the file provider, and firing a request
    /// per file at it (77+ for a large library, none of them warm on a first
    /// launch) both saturates the cooperative thread pool with blocking reads
    /// and queues work the provider serialises anyway — leaving the progress
    /// counter pinned at 0 while nothing appears to happen.
    private func performLoadPass() async {
        let fileURLs = fileMonitor.fileURLs
        loadingProgress = LoadingProgress(total: fileURLs.count, loaded: 0)

        // Snapshot what the cache was built from. Only the dates cross into the
        // child tasks, so an unchanged file can be skipped without them
        // touching main-actor state; the entries themselves stay here.
        let cacheSnapshot = recipeCache
        let cachedModDates = cacheSnapshot.mapValues(\.fileModifiedDate)

        var newRecipes: [RecipeFile] = []
        var newErrors: [URL: Error] = [:]
        var newPendingURLs: Set<URL> = []
        var loaded = 0

        await withTaskGroup(of: (URL, Date?, FileLoadOutcome).self) { group in
            var remaining = fileURLs.makeIterator()

            func addNext() {
                guard let url = remaining.next() else { return }
                let cachedModDate = cachedModDates[url] ?? nil
                group.addTask {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let modDate = attrs?[.modificationDate] as? Date

                    let resourceValues = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    if resourceValues?.ubiquitousItemDownloadingStatus == .notDownloaded {
                        return (url, modDate, .placeholder)
                    }

                    if let cachedModDate, let modDate, cachedModDate == modDate {
                        return (url, modDate, .unchanged)
                    }

                    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                        return (url, modDate, .unreadable)
                    }
                    return (url, modDate, .content(content))
                }
            }

            for _ in 0..<Self.maxConcurrentFileReads { addNext() }

            for await (url, modDate, outcome) in group {
                switch outcome {
                case .placeholder:
                    // iCloud hasn't downloaded this yet — request it and defer.
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                    newPendingURLs.insert(url)

                case .unchanged:
                    if let cached = cacheSnapshot[url] {
                        newRecipes.append(cached)
                    }

                case .content(let content):
                    do {
                        let recipeFile = try parser.parse(content: content, at: url, modDate: modDate)
                        recipeCache[url] = recipeFile
                        newRecipes.append(recipeFile)
                    } catch {
                        recipeCache.removeValue(forKey: url)
                        newErrors[url] = error
                    }

                case .unreadable:
                    newErrors[url] = RecipeParseError.fileNotReadable
                }

                loaded += 1
                loadingProgress = LoadingProgress(total: fileURLs.count, loaded: loaded)
                addNext()
            }
        }

        pendingDownloadURLs = newPendingURLs
        pendingDownloadCount = newPendingURLs.count

        // Evict cache entries for files no longer present in the folder
        let validURLs = Set(fileURLs)
        recipeCache = recipeCache.filter { validURLs.contains($0.key) }

        newRecipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        withAnimation {
            recipes = newRecipes
            parseErrors = newErrors
            loadingProgress = nil
        }
    }

    /// Fires a 15-second timer that re-requests iCloud download for any stalled placeholders.
    private func scheduleDownloadStallCheck() {
        downloadStallTask?.cancel()
        guard !pendingDownloadURLs.isEmpty else { return }

        downloadStallTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self?.retriggerPendingDownloads()
        }
    }

    private func retriggerPendingDownloads() {
        guard !pendingDownloadURLs.isEmpty else { return }
        for url in pendingDownloadURLs {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        scheduleDownloadStallCheck()
    }
}

// MARK: - Nested Types

extension RecipeStore {
    /// Upper bound on file reads in flight at once during a load pass.
    static let maxConcurrentFileReads = 8

    /// What a load pass established about a single file, off the main actor.
    enum FileLoadOutcome: Sendable {
        /// iCloud has not downloaded the file's content yet.
        case placeholder
        /// Modification date matches the cached entry — reuse it, no read needed.
        case unchanged
        /// Freshly read markdown, still to be parsed.
        case content(String)
        /// The file exists but its content could not be read.
        case unreadable
    }

    struct LoadingProgress {
        let total: Int
        let loaded: Int
        var remaining: Int { total - loaded }
        var fraction: Double { total > 0 ? Double(loaded) / Double(total) : 0 }
    }
}
