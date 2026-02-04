//
//  SampleRecipeLoader.swift
//  OpenCookbook
//
//  Helper for loading bundled sample recipes for testing
//

import Foundation

/// Helper for loading and copying sample recipes bundled with the app
class SampleRecipeLoader {

    /// Errors that can occur when loading sample recipes
    enum SampleRecipeError: LocalizedError {
        case bundleResourceNotFound
        case copyFailed(Error)
        case directoryCreationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .bundleResourceNotFound:
                return "Sample recipes not found in app bundle"
            case .copyFailed(let error):
                return "Failed to copy sample recipes: \(error.localizedDescription)"
            case .directoryCreationFailed(let error):
                return "Failed to create directory: \(error.localizedDescription)"
            }
        }
    }

    /// Copy all bundled sample recipes to a destination folder
    /// - Parameter destinationURL: The folder where sample recipes should be copied
    /// - Returns: Array of URLs for the copied recipe files
    /// - Throws: SampleRecipeError if copying fails
    nonisolated static func copySampleRecipes(to destinationURL: URL) throws -> [URL] {
        let fileManager = FileManager.default

        // List of sample recipe filenames bundled with the app
        let sampleRecipeNames = [
            "Guacamole.md",
            "Chocolate Chip Cookies.md",
            "Spaghetti Carbonara.md",
            "Green Smoothie.md",
            "Margherita Pizza.md"
        ]

        // Create destination directory if it doesn't exist
        if !fileManager.fileExists(atPath: destinationURL.path) {
            do {
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            } catch {
                throw SampleRecipeError.directoryCreationFailed(error)
            }
        }

        var copiedFiles: [URL] = []
        var foundAny = false

        // Copy each sample recipe file from bundle
        for fileName in sampleRecipeNames {
            // Get URL for bundled file (without extension, then add it back)
            let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
            guard let sourceURL = Bundle.main.url(forResource: fileNameWithoutExt, withExtension: "md") else {
                continue // Skip if file not found in bundle
            }

            foundAny = true
            let destinationFileURL = destinationURL.appendingPathComponent(fileName)

            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationFileURL.path) {
                try? fileManager.removeItem(at: destinationFileURL)
            }

            // Copy file
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationFileURL)
                copiedFiles.append(destinationFileURL)
            } catch {
                throw SampleRecipeError.copyFailed(error)
            }
        }

        // If no files were found at all, throw error
        if !foundAny {
            throw SampleRecipeError.bundleResourceNotFound
        }

        return copiedFiles
    }

    /// Get a temporary directory for sample recipes
    /// - Returns: URL for a temporary directory to store sample recipes
    static func createTemporarySampleDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenCookbook-SampleRecipes")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        return tempDir
    }

    /// Load sample recipes into a temporary directory and return the directory URL
    /// - Returns: URL of the temporary directory containing sample recipes
    nonisolated static func loadSampleRecipesIntoTempDirectory() throws -> URL {
        let tempDir = try createTemporarySampleDirectory()
        _ = try copySampleRecipes(to: tempDir)
        return tempDir
    }
}
