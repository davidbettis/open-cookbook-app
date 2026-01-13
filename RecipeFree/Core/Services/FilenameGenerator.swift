//
//  FilenameGenerator.swift
//  RecipeFree
//
//  Generates unique filenames for recipe files
//

import Foundation

/// Generates unique, safe filenames for recipe files
final class FilenameGenerator {

    /// Error thrown when filename generation fails
    enum FilenameError: LocalizedError {
        case emptyTitle
        case emptySlug

        var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Recipe title cannot be empty"
            case .emptySlug:
                return "Recipe title contains no valid characters for a filename"
            }
        }
    }

    // MARK: - Public Methods

    /// Generate a unique filename for a recipe title in a folder
    /// - Parameters:
    ///   - title: The recipe title to create filename from
    ///   - folder: The folder to check for existing files
    /// - Returns: A unique filename with .md extension
    /// - Throws: FilenameError if title cannot be converted to valid filename
    func generateFilename(for title: String, in folder: URL) throws -> String {
        // Validate title
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FilenameError.emptyTitle
        }

        // Create slug from title
        let slug = title.slugified

        // Validate slug
        guard !slug.isEmpty else {
            throw FilenameError.emptySlug
        }

        // Check if base filename exists, if so append number
        let baseFilename = slug
        var filename = "\(baseFilename).md"
        var counter = 1

        while fileExists(filename, in: folder) {
            filename = "\(baseFilename)-\(counter).md"
            counter += 1
        }

        return filename
    }

    /// Generate a file URL for a recipe title in a folder
    /// - Parameters:
    ///   - title: The recipe title
    ///   - folder: The destination folder
    /// - Returns: A unique file URL
    /// - Throws: FilenameError if title cannot be converted to valid filename
    func generateFileURL(for title: String, in folder: URL) throws -> URL {
        let filename = try generateFilename(for: title, in: folder)
        return folder.appendingPathComponent(filename)
    }

    // MARK: - Private Methods

    /// Check if a file exists in a folder
    /// - Parameters:
    ///   - filename: The filename to check
    ///   - folder: The folder to check in
    /// - Returns: True if file exists
    private func fileExists(_ filename: String, in folder: URL) -> Bool {
        let fileURL = folder.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
