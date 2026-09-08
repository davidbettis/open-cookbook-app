//
//  RecipeLibraryLoadingTests.swift
//  OpenCookbookTests
//
//  Regression tests for library loading and folder monitoring
//

import Testing
import Foundation
import RecipeMD
@testable import OpenCookbook

@Suite("Recipe Library Loading", .serialized)
@MainActor
struct RecipeLibraryLoadingTests {

    // MARK: - Helpers

    /// Minimal valid RecipeMD document
    static func markdown(title: String) -> String {
        """
        # \(title)

        ---

        - *1 cup* flour

        ---

        1. Mix it.
        """
    }

    func createTestDirectory(fileCount: Int = 0) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecipeLibraryLoadingTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for index in 0..<fileCount {
            let url = tempDir.appendingPathComponent("recipe-\(index).md")
            try? Self.markdown(title: "Recipe \(index)").write(to: url, atomically: true, encoding: .utf8)
        }

        return tempDir
    }

    func cleanupTestDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Poll until `condition` holds or the timeout elapses.
    func waitUntil(
        timeout: Duration = .seconds(5),
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    // MARK: - Monitor Lifecycle

    /// The library container and the list view both loaded on appear, so the
    /// monitor was started twice in a row. Cancelling the first dispatch source
    /// closes its descriptor asynchronously, `open()` immediately hands the same
    /// number to the replacement source, and the stale cancel handler then
    /// closed the live descriptor — silently killing file monitoring.
    @Test("Monitoring the same folder twice keeps delivering file events")
    func remonitoringSameFolderKeepsEventsAlive() async throws {
        let dir = createTestDirectory()
        defer { cleanupTestDirectory(dir) }

        final class Box { var fired = false }
        let box = Box()

        let monitor = RecipeFileMonitor()
        monitor.onFilesChanged = { box.fired = true }

        monitor.startMonitoring(folder: dir)
        monitor.startMonitoring(folder: dir)
        defer { monitor.stopMonitoring() }

        try Self.markdown(title: "Late Arrival")
            .write(to: dir.appendingPathComponent("late.md"), atomically: true, encoding: .utf8)

        let fired = await waitUntil { box.fired }
        #expect(fired, "monitor stopped delivering events after being restarted on the same folder")
    }

    @Test("Restarting monitoring keeps the scanned file list intact")
    func remonitoringKeepsFileList() async throws {
        let dir = createTestDirectory(fileCount: 3)
        defer { cleanupTestDirectory(dir) }

        let monitor = RecipeFileMonitor()
        monitor.startMonitoring(folder: dir)
        monitor.startMonitoring(folder: dir)
        defer { monitor.stopMonitoring() }

        #expect(monitor.fileURLs.count == 3)
        #expect(monitor.monitoredFolder == dir)
    }

    // MARK: - Store Loading

    /// Reproduces the on-appear double load: both views call `loadRecipes` for
    /// the same folder, and afterwards the folder must still be monitored.
    @Test("Duplicate concurrent loads still leave the library watched")
    func duplicateLoadKeepsMonitoringAlive() async throws {
        let dir = createTestDirectory(fileCount: 2)
        defer { cleanupTestDirectory(dir) }

        let store = RecipeStore()
        async let first: Void = store.loadRecipes(from: dir)
        async let second: Void = store.loadRecipes(from: dir)
        _ = await (first, second)

        #expect(store.recipes.count == 2)
        #expect(store.isLoading == false)
        #expect(store.loadingProgress == nil)

        // A recipe added on disk must still be picked up by the monitor.
        try Self.markdown(title: "Added Later")
            .write(to: dir.appendingPathComponent("later.md"), atomically: true, encoding: .utf8)

        let noticed = await waitUntil { store.recipes.count == 3 }
        #expect(noticed, "file monitoring was lost after the duplicate on-appear load")
    }

    /// A library larger than the read window must drain completely — a bug in
    /// the sliding window would stall the pass with the progress counter stuck
    /// partway through, which is what a stuck "Loading 0 of N" looks like.
    @Test("A library larger than the read window loads every recipe")
    func libraryLargerThanReadWindowLoadsFully() async throws {
        let fileCount = RecipeStore.maxConcurrentFileReads * 4 + 3
        let dir = createTestDirectory(fileCount: fileCount)
        defer { cleanupTestDirectory(dir) }

        let store = RecipeStore()
        await store.loadRecipes(from: dir)
        defer { store.reset() }

        #expect(store.recipes.count == fileCount)
        #expect(store.parseErrors.isEmpty)
        #expect(store.loadingProgress == nil, "progress must be cleared once the pass completes")
        #expect(store.isLoading == false)
    }

    @Test("Reloading an unchanged library reuses the cache and still reports every recipe")
    func reloadReusesCache() async throws {
        let dir = createTestDirectory(fileCount: 5)
        defer { cleanupTestDirectory(dir) }

        let store = RecipeStore()
        await store.loadRecipes(from: dir)
        #expect(store.recipes.count == 5)

        // Second pass hits the modification-date cache for every file.
        await store.refreshRecipes()
        defer { store.reset() }

        #expect(store.recipes.count == 5)
        #expect(store.parseErrors.isEmpty)
    }
}
