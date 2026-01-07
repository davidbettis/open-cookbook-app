//
//  Recipe.swift
//  DoctorRecipe
//
//  Core data model representing a RecipeMD file
//

import Foundation

/// Represents a recipe parsed from a RecipeMD file
struct Recipe: Identifiable, Hashable {
    /// Unique identifier for the recipe
    let id: UUID

    /// File path to the source .md file
    let filePath: URL

    /// Recipe title (from first H1 or filename)
    var title: String

    /// Optional description (first paragraph)
    var description: String?

    /// Tags for categorization
    var tags: [String]

    /// Yields information (e.g., "4 servings")
    var yields: [String]

    /// Individual ingredients (ungrouped)
    var ingredients: [Ingredient]

    /// Grouped ingredients (e.g., "For the dough", "For the sauce")
    var ingredientGroups: [IngredientGroup]

    /// Cooking instructions
    var instructions: String?

    /// File modification date for cache invalidation
    var fileModifiedDate: Date?

    /// Optional parse error if file couldn't be fully parsed
    var parseError: RecipeParseError?

    /// Initialize with all properties
    init(
        id: UUID = UUID(),
        filePath: URL,
        title: String,
        description: String? = nil,
        tags: [String] = [],
        yields: [String] = [],
        ingredients: [Ingredient] = [],
        ingredientGroups: [IngredientGroup] = [],
        instructions: String? = nil,
        fileModifiedDate: Date? = nil,
        parseError: RecipeParseError? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.description = description
        self.tags = tags
        self.yields = yields
        self.ingredients = ingredients
        self.ingredientGroups = ingredientGroups
        self.instructions = instructions
        self.fileModifiedDate = fileModifiedDate
        self.parseError = parseError
    }

    /// Primary tag for display (first tag if available)
    var primaryTag: String? {
        tags.first
    }

    /// Filename without extension
    var filename: String {
        filePath.deletingPathExtension().lastPathComponent
    }

    /// Hash implementation for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Equality implementation for Hashable conformance
    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }
}

/// Errors that can occur during recipe parsing
enum RecipeParseError: Error, LocalizedError {
    case fileNotFound
    case fileNotReadable
    case invalidFormat(reason: String)
    case missingTitle
    case encodingError

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Recipe file not found"
        case .fileNotReadable:
            return "Unable to read recipe file"
        case .invalidFormat(let reason):
            return "Invalid RecipeMD format: \(reason)"
        case .missingTitle:
            return "Recipe is missing a title"
        case .encodingError:
            return "File encoding error"
        }
    }
}
