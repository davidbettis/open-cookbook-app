//
//  RecipeFile.swift
//  RecipeFree
//
//  Wrapper combining a RecipeMD Recipe with file system metadata
//

import Foundation
import RecipeMD

/// Wrapper combining a RecipeMD Recipe with file system metadata
struct RecipeFile: Identifiable, Hashable {
    /// Unique identifier (helps with testing and SwiftUI diffing)
    let id: UUID

    /// Path to the .md file
    let filePath: URL

    /// The parsed recipe content
    var recipe: Recipe

    /// File modification date for cache invalidation
    var fileModifiedDate: Date?

    /// Parse error if file couldn't be fully parsed
    var parseError: RecipeParseError?

    // MARK: - Convenience Accessors

    var title: String { recipe.title }
    var tags: [String] { recipe.tags }
    var description: String? { recipe.description }
    var instructions: String? { recipe.instructions }
    var ingredientGroups: [IngredientGroup] { recipe.ingredientGroups }
    var yield: Yield { recipe.yield }

    /// Filename without extension
    var filename: String {
        filePath.deletingPathExtension().lastPathComponent
    }

    /// All ingredients flattened from all groups
    var allIngredients: [Ingredient] {
        recipe.ingredientGroups.flatMap { $0.allIngredients }
    }

    /// Primary tag for display (first tag if available)
    var primaryTag: String? {
        tags.first
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        filePath: URL,
        recipe: Recipe,
        fileModifiedDate: Date? = nil,
        parseError: RecipeParseError? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.recipe = recipe
        self.fileModifiedDate = fileModifiedDate
        self.parseError = parseError
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RecipeFile, rhs: RecipeFile) -> Bool {
        lhs.id == rhs.id
    }
}
