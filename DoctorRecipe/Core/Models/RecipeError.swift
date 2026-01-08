//
//  RecipeError.swift
//  DoctorRecipe
//
//  Error types for recipe file operations
//

import Foundation

/// Errors that can occur when writing recipe files
enum RecipeWriteError: LocalizedError {
    case folderNotAccessible
    case invalidFilename
    case writeError(underlying: Error)
    case serializationError

    var errorDescription: String? {
        switch self {
        case .folderNotAccessible:
            return "Cannot access the recipe folder. Please check your iCloud Drive settings."
        case .invalidFilename:
            return "Could not create a valid filename for this recipe."
        case .writeError(let error):
            return "Failed to save recipe: \(error.localizedDescription)"
        case .serializationError:
            return "Failed to convert recipe to markdown format."
        }
    }
}

/// Errors that can occur when deleting recipe files
enum RecipeDeleteError: LocalizedError {
    case fileNotFound
    case permissionDenied
    case fileLocked
    case deleteError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Recipe file not found. It may have been deleted externally."
        case .permissionDenied:
            return "Permission denied. Cannot delete this recipe file."
        case .fileLocked:
            return "Recipe file is in use by another application."
        case .deleteError(let error):
            return "Failed to delete recipe: \(error.localizedDescription)"
        }
    }
}
