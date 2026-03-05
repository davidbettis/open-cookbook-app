//
//  IncomingRecipeHandler.swift
//  OpenCookbook
//
//  Handles incoming .recipe.md files from AirDrop, Files, or other apps
//

import Foundation
import RecipeMD

/// Errors that can occur when processing an incoming recipe file
enum IncomingRecipeError: LocalizedError {
    case fileUnreadable
    case notARecipe

    var errorDescription: String? {
        switch self {
        case .fileUnreadable:
            return "Unable to read the file."
        case .notARecipe:
            return "This doesn't appear to be a recipe."
        }
    }
}

/// Represents a successfully parsed incoming recipe ready for preview/save
struct IncomingRecipe: Identifiable {
    let id = UUID()
    let markdown: String
    let recipe: Recipe
}

/// Handles reading and validating incoming .recipe.md files
enum IncomingRecipeHandler {

    /// Read and validate an incoming recipe file URL.
    /// - Parameter url: The file URL to read (may be a security-scoped resource)
    /// - Returns: An `IncomingRecipe` with the raw markdown and parsed recipe
    /// - Throws: `IncomingRecipeError` if the file can't be read or isn't a valid recipe
    static func handleIncomingFile(at url: URL) throws -> IncomingRecipe {
        // Gain access to security-scoped resource (AirDrop inbox, etc.)
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let markdown: String
        do {
            markdown = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw IncomingRecipeError.fileUnreadable
        }

        return try handleIncomingMarkdown(markdown)
    }

    /// Validate a raw markdown string as a recipe.
    /// - Parameter markdown: The raw markdown text
    /// - Returns: An `IncomingRecipe` with the raw markdown and parsed recipe
    /// - Throws: `IncomingRecipeError.notARecipe` if parsing fails
    static func handleIncomingMarkdown(_ markdown: String) throws -> IncomingRecipe {
        let parser = RecipeMDParser()
        do {
            let recipe = try parser.parse(markdown)
            // Require at least a title to consider it a valid recipe
            guard !recipe.title.isEmpty else {
                throw IncomingRecipeError.notARecipe
            }
            return IncomingRecipe(markdown: markdown, recipe: recipe)
        } catch {
            throw IncomingRecipeError.notARecipe
        }
    }
}
