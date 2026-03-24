//
//  RecipeFileParser.swift
//  OpenCookbook
//
//  Parses RecipeMD files into RecipeFile instances using the RecipeMD library
//

import Foundation
import RecipeMD

/// Parses RecipeMD files into RecipeFile instances
/// Uses the RecipeMD library for parsing and wraps results with file metadata
final class RecipeFileParser {
    private let parser = RecipeMDParser()

    // MARK: - Public Methods

    /// Parse a RecipeMD file from a URL
    /// - Parameter url: URL of the .md file to parse
    /// - Returns: A RecipeFile instance with parsed recipe and file metadata
    /// - Throws: RecipeParseError if parsing fails
    func parse(from url: URL) throws -> RecipeFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecipeParseError.fileNotFound
        }

        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw RecipeParseError.encodingError
        }

        let recipe: Recipe
        do {
            recipe = try parser.parse(content)
        } catch {
            throw RecipeParseError.invalidFormat(reason: error.localizedDescription)
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attributes?[.modificationDate] as? Date

        return RecipeFile(
            filePath: url,
            recipe: recipe,
            fileModifiedDate: modDate
        )
    }
}
