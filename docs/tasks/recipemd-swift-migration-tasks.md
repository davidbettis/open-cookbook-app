# Migration Tasks: recipemd-swift Library Integration

**Source Spec**: docs/specs/recipe-detail-view.md
**Library**: https://github.com/davidbettis/recipemd-swift

## Overview

Replace the custom RecipeMD parser/serializer and align app models with the `recipemd-swift` library types. This is a larger refactor that simplifies the codebase and ensures full compliance with RecipeMD v2.4.0.

## Architectural Decision

**Align app models with library models** rather than creating adapters. This means:
- Use library's `Recipe`, `Ingredient`, `Amount`, `Yield`, `IngredientGroup` types directly
- Create a thin wrapper (`RecipeFile`) for app-specific concerns (file path, modification date)
- Update all consumers to use the new model structure

## Model Comparison

### Library Models (recipemd-swift)

```swift
// Recipe
struct Recipe: Sendable, Equatable, Codable {
    var title: String
    var description: String?
    var tags: [String]
    var yield: Yield
    var ingredientGroups: [IngredientGroup]
    var instructions: String?
}

// Ingredient
struct Ingredient: Sendable, Equatable, Codable {
    var name: String
    var amount: Amount?
    var link: String?  // Link to another recipe
}

// Amount
struct Amount: Sendable, Equatable, Codable {
    var amount: Double      // Computed numeric value
    var unit: String?       // e.g., "cups", "g"
    var rawText: String     // Original text: "1/2", "2"
}

// Yield
struct Yield: Sendable, Equatable, Codable {
    var amount: [Amount]    // Multiple yields supported
}

// IngredientGroup
struct IngredientGroup: Sendable, Equatable, Codable {
    var title: String?
    var ingredients: [Ingredient]
    var ingredientGroups: [IngredientGroup]  // Nested groups
}
```

### Current App Models

```swift
// Recipe (app)
struct Recipe {
    let id: UUID                    // → Keep (move to RecipeFile wrapper)
    let filePath: URL               // → Move to RecipeFile wrapper
    var title: String               // ✓ Same
    var description: String?        // ✓ Same
    var tags: [String]              // ✓ Same
    var yields: [String]            // → Change to Yield type
    var ingredients: [Ingredient]   // → Remove (use ingredientGroups only)
    var ingredientGroups: [IngredientGroup]  // ✓ Similar
    var instructions: String?       // ✓ Same
    var fileModifiedDate: Date?     // → Move to RecipeFile wrapper
    var parseError: RecipeParseError?  // → Move to RecipeFile wrapper
}

// Ingredient (app)
struct Ingredient {
    let id: UUID           // → Remove
    var quantity: String?  // → Change to Amount type
    var unit: String?      // → Change to Amount type
    var name: String       // ✓ Same
    var preparation: String?  // → Remove (not in spec, encode in name)
}

// IngredientGroup (app)
struct IngredientGroup {
    let id: UUID              // → Remove
    var name: String?         // → Rename to title
    var ingredients: [Ingredient]  // ✓ Same
    // Missing: nested ingredientGroups
}
```

---

## Tasks

### 1. Add Package Dependency
**File**: `OpenCookbook.xcodeproj`

Add Swift Package Manager dependency:
```
URL: https://github.com/davidbettis/recipemd-swift
Version Rule: Up to Next Major Version
```

**Acceptance**: `import RecipeMD` compiles successfully

---

### 2. Create RecipeFile Wrapper
**File**: `Core/Models/RecipeFile.swift` (new)

Create wrapper for app-specific concerns around library Recipe:

```swift
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

    /// Convenience accessors
    var title: String { recipe.title }
    var tags: [String] { recipe.tags }
    var description: String? { recipe.description }

    /// Filename without extension
    var filename: String {
        filePath.deletingPathExtension().lastPathComponent
    }

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
}
```

---

### 3. Delete App Model Files
**Files to delete**:
- `Core/Models/Recipe.swift`
- `Core/Models/Ingredient.swift`

**Keep**: `Core/Models/RecipeError.swift` (rename `RecipeParseError` or keep as-is)

The library's `Recipe`, `Ingredient`, `IngredientGroup`, `Amount`, `Yield` types replace these entirely.

---

### 4. Update RecipeMDParser.swift
**File**: `Core/Services/RecipeMDParser.swift`

Refactor to use library parser and return `RecipeFile`:

```swift
import Foundation
import RecipeMD

final class RecipeFileParser {
    private let parser = RecipeMDParser()

    /// Parse a RecipeMD file
    func parse(from url: URL) throws -> RecipeFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecipeParseError.fileNotFound
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let recipe = try parser.parse(content)

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attributes?[.modificationDate] as? Date

        return RecipeFile(
            filePath: url,
            recipe: recipe,
            fileModifiedDate: modDate
        )
    }
}
```

**Note**: Renamed class to `RecipeFileParser` to avoid conflict with library's `RecipeMDParser`

**Remove**: All private parsing methods - library handles everything

---

### 5. Update RecipeMDSerializer.swift
**File**: `Core/Services/RecipeMDSerializer.swift`

Refactor to use library generator:

```swift
import Foundation
import RecipeMD

final class RecipeMDSerializer {
    private let generator = RecipeMDGenerator()

    /// Serialize a Recipe to RecipeMD markdown
    func serialize(_ recipe: Recipe) -> String {
        return generator.generate(recipe)
    }

    /// Serialize a RecipeFile to markdown
    func serialize(_ recipeFile: RecipeFile) -> String {
        return generator.generate(recipeFile.recipe)
    }
}
```

---

### 6. Update RecipeStore.swift
**File**: `Core/Services/RecipeStore.swift`

Major refactor - change from `Recipe` to `RecipeFile`:

- Change `@Published var recipes: [Recipe]` → `[RecipeFile]`
- Update all parsing calls
- Update filtering/sorting logic
- Update save/delete methods

---

### 7. Update RecipeSearchService.swift
**File**: `Core/Services/RecipeSearchService.swift`

Update to work with `RecipeFile` and library `Recipe`:

- Search `recipeFile.recipe.title`
- Search `recipeFile.recipe.tags`
- Search ingredients via `recipe.ingredientGroups.flatMap { $0.allIngredients }`

---

### 8. Update RecipeFormViewModel.swift
**File**: `Features/RecipeForm/ViewModels/RecipeFormViewModel.swift`

Major refactor for new model structure:

**Key changes**:
- Form fields map to library types
- `quantity` + `unit` → `Amount`
- Remove `preparation` field (encode in ingredient name)
- Handle `Yield` type instead of `[String]`
- Build `IngredientGroup` structure

```swift
// Example: Creating an ingredient
let amount = Amount(rawText: quantityText, unit: unitText)
let ingredient = Ingredient(name: name, amount: amount)

// Example: Creating yield
let yield = Yield(amount: [Amount(servings, unit: "servings")])
```

---

### 9. Update Views

**Files**:
- `RecipeDetailView.swift` - Use `RecipeFile` and `Recipe` properties
- `RecipeCard.swift` - Update to `RecipeFile`
- `RecipeListView.swift` - Update to `[RecipeFile]`
- `RecipeLibraryContainerView.swift` - Update bindings
- `IngredientRowView.swift` - Use library `Ingredient` and `Amount`
- `RecipeFormView.swift` - Update form bindings

**Pattern**: Access recipe data via `recipeFile.recipe.propertyName`

---

### 10. Update All Tests

**Files**:
- `RecipeMDParserTests.swift` - Test `RecipeFile` output
- `RecipeMDSerializerTests.swift` - Test library generator
- `RecipeStoreTests.swift` - Use `RecipeFile`
- `RecipeSearchServiceTests.swift` - Update for new types
- `RecipeFormViewModelTests.swift` - Major updates for new model
- `RecipeDetailViewTests.swift` - Update for `RecipeFile`

**Approach**: Update test data factories to create library types

---

### 11. Update Sample Recipe Loader
**File**: `Core/Services/SampleRecipeLoader.swift`

Update to return `[RecipeFile]` using library parser.

---

### 12. Clean Up & Verify

1. Remove all unused code
2. Fix any remaining compiler errors
3. Run full build
4. Run all tests
5. Manual testing:
   - Load sample recipes
   - Create new recipe
   - Edit existing recipe
   - Delete recipe
   - Search and filter

---

## Files Summary

| File | Action |
|------|--------|
| `project.pbxproj` | Add package dependency |
| `RecipeFile.swift` | **New** |
| `Recipe.swift` | **Delete** |
| `Ingredient.swift` | **Delete** |
| `RecipeMDParser.swift` | Major refactor |
| `RecipeMDSerializer.swift` | Major refactor |
| `RecipeStore.swift` | Major refactor |
| `RecipeSearchService.swift` | Refactor |
| `RecipeFormViewModel.swift` | Major refactor |
| `RecipeDetailView.swift` | Update |
| `RecipeCard.swift` | Update |
| `RecipeListView.swift` | Update |
| `RecipeLibraryContainerView.swift` | Update |
| `IngredientRowView.swift` | Update |
| `RecipeFormView.swift` | Update |
| `SampleRecipeLoader.swift` | Update |
| All test files | Update |

## Breaking Changes

1. **`Recipe` type** - Now from library, different structure
2. **`Ingredient` type** - Now from library, uses `Amount` instead of `quantity`/`unit`
3. **No more `preparation` field** - Encode in ingredient name (e.g., "onion, diced")
4. **No more standalone `ingredients`** - All ingredients in `ingredientGroups`
5. **`yields` → `yield`** - Now `Yield` type with `[Amount]`
6. **`Recipe` → `RecipeFile`** - App now uses `RecipeFile` wrapper (keeps UUID for identity)

## Acceptance Criteria

- [ ] recipemd-swift package added and importing
- [ ] `Recipe.swift` and `Ingredient.swift` deleted
- [ ] `RecipeFile.swift` created with file metadata
- [ ] All views use `RecipeFile` / library `Recipe`
- [ ] All existing recipes parse correctly
- [ ] New recipes serialize to valid RecipeMD
- [ ] All tests updated and passing
- [ ] No custom parsing/serialization logic remains
