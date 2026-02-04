//
//  RecipeFileSerializer.swift
//  OpenCookbook
//
//  Serializes Recipe models to RecipeMD markdown format using the RecipeMD library
//

import Foundation
import RecipeMD

/// Serializes Recipe models to valid RecipeMD markdown format
/// Uses the RecipeMD library's generator
final class RecipeFileSerializer {
    private let generator = RecipeMDGenerator()

    // MARK: - Public Methods

    /// Serialize a Recipe to RecipeMD markdown format
    /// - Parameter recipe: The recipe to serialize
    /// - Returns: Valid RecipeMD markdown string
    func serialize(_ recipe: Recipe) -> String {
        return generator.generate(recipe)
    }

    /// Serialize a RecipeFile to RecipeMD markdown format
    /// - Parameter recipeFile: The recipe file to serialize
    /// - Returns: Valid RecipeMD markdown string
    func serialize(_ recipeFile: RecipeFile) -> String {
        return generator.generate(recipeFile.recipe)
    }
}
