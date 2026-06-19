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
    private let parser = RecipeMDParser(options: ParserOptions(extractSupplementalAmounts: true))

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

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attributes?[.modificationDate] as? Date

        return try parse(content: content, at: url, modDate: modDate)
    }

    /// Parse pre-loaded RecipeMD content into a RecipeFile (no file I/O).
    /// Use this when file contents have already been read off the main actor.
    /// - Parameters:
    ///   - content: The raw markdown string
    ///   - url: The source file URL (used for filePath and ID)
    ///   - modDate: The file's modification date, if known
    /// - Returns: A RecipeFile instance with parsed recipe and file metadata
    /// - Throws: RecipeParseError if parsing fails
    func parse(content: String, at url: URL, modDate: Date?) throws -> RecipeFile {
        let recipe: Recipe
        do {
            recipe = try parser.parse(content)
        } catch {
            throw RecipeParseError.invalidFormat(reason: error.localizedDescription)
        }

        return RecipeFile(
            filePath: url,
            recipe: recipe,
            fileModifiedDate: modDate
        )
    }
}
