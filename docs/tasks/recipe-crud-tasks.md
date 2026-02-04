# Task Breakdown: Recipe CRUD Operations

**Features**: Add New Recipe (F005), Edit Recipe (F006), Delete Recipe (F007)
**Created**: 2026-01-07
**Priority**: P0 (Add/Edit), P1 (Delete)

## Overview

This task breakdown covers the remaining CRUD operations for recipe management. These three features share significant code:
- Add and Edit share the same form UI (RecipeFormView)
- All three require RecipeStore modifications for write/delete operations
- Add and Edit require a new RecipeMD serializer

## Task Dependencies

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FOUNDATION LAYER                              │
├─────────────────────────────────────────────────────────────────────┤
│  Task 1: RecipeMD Serializer                                        │
│  Task 2: Filename Utilities                                         │
│  Task 3: RecipeStore Write/Delete Methods                           │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          FORM LAYER                                  │
├─────────────────────────────────────────────────────────────────────┤
│  Task 4: RecipeFormViewModel                                        │
│  Task 5: IngredientRowView                                          │
│  Task 6: RecipeFormView                                             │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       INTEGRATION LAYER                              │
├─────────────────────────────────────────────────────────────────────┤
│  Task 7: Add Recipe Flow                                            │
│  Task 8: Edit Recipe Flow                                           │
│  Task 9: Delete Recipe Flow                                         │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         TESTING LAYER                                │
├─────────────────────────────────────────────────────────────────────┤
│  Task 10: Unit Tests                                                │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Task 1: RecipeMD Serializer

**Complexity**: Medium
**Estimated Files**: 1 new file
**Dependencies**: None

### Description
Create a serializer that converts a Recipe model to valid RecipeMD markdown format. This is the inverse of the existing RecipeMDParser.

### Implementation Steps
1. Create `Core/Services/RecipeMDSerializer.swift`
2. Implement `serialize(_ recipe: Recipe) -> String` method
3. Generate markdown following RecipeMD v2.4.0 spec:
   - `# Title` (H1 heading)
   - Description paragraphs
   - `*tag1, tag2, tag3*` (italic tags)
   - `**serves 4, makes 12**` (bold yields)
   - `---` (horizontal rule)
   - Ingredient list with optional `*amount*` in italics
   - `---` (horizontal rule)
   - Instructions content
4. Handle edge cases:
   - Empty optional fields (skip them)
   - Special characters in text (preserve as-is)
   - Ingredient groups (H2 headings)

### Acceptance Criteria
- [ ] Serializer produces valid RecipeMD markdown
- [ ] Round-trip test: parse → serialize → parse produces same data
- [ ] Empty optional fields are omitted cleanly
- [ ] Output matches format shown in PRD example

### Test Cases
- Serialize recipe with all fields populated
- Serialize recipe with minimal fields (title + 1 ingredient)
- Serialize recipe with ingredient groups
- Round-trip test with existing sample recipes

---

## Task 2: Filename Utilities

**Complexity**: Low
**Estimated Files**: 1 new file
**Dependencies**: None

### Description
Create utilities for generating safe, unique filenames from recipe titles.

### Implementation Steps
1. Create `Core/Extensions/String+Slug.swift`
2. Implement `slugified` computed property:
   - Lowercase
   - Replace spaces with hyphens
   - Remove special characters (keep alphanumeric and hyphens)
   - Remove consecutive hyphens
   - Trim hyphens from start/end
3. Create `Core/Services/FilenameGenerator.swift`
4. Implement `generateFilename(for title: String, in folder: URL) -> String`:
   - Create slug from title
   - Check if file exists
   - If exists, append `-1`, `-2`, etc. until unique
   - Return filename with `.md` extension

### Acceptance Criteria
- [ ] Slugification handles special characters: `Mom's "Special" Cookies!` → `moms-special-cookies`
- [ ] Unicode characters converted or removed
- [ ] Duplicate detection works correctly
- [ ] Returns `.md` extension

### Test Cases
- `"Chocolate Chip Cookies"` → `"chocolate-chip-cookies.md"`
- `"Mom's \"Special\" Cookies!"` → `"moms-special-cookies.md"`
- Duplicate title generates `pancakes-1.md`, `pancakes-2.md`
- Empty title after sanitization throws error

---

## Task 3: RecipeStore Write/Delete Methods

**Complexity**: Medium
**Estimated Files**: 1 existing file modified
**Dependencies**: Task 1, Task 2

### Description
Extend RecipeStore with methods to save new recipes, update existing recipes, and delete recipes.

### Implementation Steps
1. Add error types to Recipe.swift or new RecipeError.swift:
   ```swift
   enum RecipeWriteError: LocalizedError {
       case fileExists
       case writeError(underlying: Error)
       case folderNotAccessible
       case invalidFilename
   }

   enum RecipeDeleteError: LocalizedError {
       case fileNotFound
       case permissionDenied
       case deleteError(underlying: Error)
   }
   ```

2. Add methods to RecipeStore:
   ```swift
   func saveNewRecipe(_ recipe: Recipe, in folder: URL) async throws -> Recipe
   func updateRecipe(_ recipe: Recipe) async throws
   func deleteRecipe(_ recipe: Recipe) async throws
   ```

3. Implement save with:
   - Security-scoped bookmark access
   - Atomic write via temp file
   - Unique filename generation
   - Add to recipes array on success

4. Implement update with:
   - File existence check
   - Modification date conflict detection (optional v1.0)
   - Atomic write to existing path
   - Update cache

5. Implement delete with:
   - FileManager.removeItem
   - Remove from recipes array
   - Remove from cache
   - Handle file-not-found gracefully

### Acceptance Criteria
- [ ] saveNewRecipe creates file and updates store
- [ ] updateRecipe overwrites file atomically
- [ ] deleteRecipe removes file and updates store
- [ ] Errors propagate with user-friendly messages
- [ ] Security-scoped bookmark used for iCloud access

### Test Cases
- Save new recipe successfully
- Save recipe with duplicate name (auto-increment)
- Update existing recipe
- Delete existing recipe
- Delete recipe when file already gone (graceful handling)

---

## Task 4: RecipeFormViewModel

**Complexity**: Medium
**Estimated Files**: 1 new file
**Dependencies**: Task 1, Task 2, Task 3

### Description
Create the ViewModel for the recipe form, handling both add and edit modes with validation and save logic.

### Implementation Steps
1. Create `Features/RecipeForm/ViewModels/RecipeFormViewModel.swift`
2. Define form mode enum:
   ```swift
   enum RecipeFormMode {
       case add
       case edit(Recipe)
   }
   ```

3. Define editable form state:
   ```swift
   @Observable
   class RecipeFormViewModel {
       var title: String = ""
       var description: String = ""
       var tagsText: String = ""  // Comma-separated
       var yieldsText: String = ""  // Comma-separated
       var ingredients: [EditableIngredient] = []
       var instructions: String = ""

       var mode: RecipeFormMode
       var isSaving = false
       var hasUnsavedChanges: Bool { ... }
       var validationErrors: [ValidationError] = []
   }
   ```

4. Implement validation:
   - Title required, non-empty, < 200 chars
   - At least 1 ingredient with non-empty name
   - Return array of validation errors

5. Implement `save(to folder: URL, using store: RecipeStore)`:
   - Validate form
   - Create Recipe from form data
   - Call appropriate store method
   - Handle errors

6. Implement initialization from existing Recipe (for edit mode)

### Acceptance Criteria
- [ ] Form validates required fields
- [ ] hasUnsavedChanges tracks modifications
- [ ] Save converts form to Recipe model
- [ ] Edit mode pre-populates all fields
- [ ] Validation errors are user-friendly

### Test Cases
- Validation fails with empty title
- Validation fails with no ingredients
- Validation passes with minimal valid data
- hasUnsavedChanges detects edits

---

## Task 5: IngredientRowView

**Complexity**: Low
**Estimated Files**: 1 new file
**Dependencies**: None

### Description
Create a reusable ingredient row component for the dynamic ingredient list.

### Implementation Steps
1. Create `Features/RecipeForm/Views/IngredientRowView.swift`
2. Define EditableIngredient model:
   ```swift
   struct EditableIngredient: Identifiable {
       let id: UUID
       var amount: String  // Combined quantity + unit
       var name: String
   }
   ```

3. Create IngredientRowView:
   - Amount TextField (narrow, left)
   - Name TextField (wide, right)
   - Delete button (trailing swipe or minus icon)

4. Add focus management for keyboard flow

### Acceptance Criteria
- [ ] Two text fields side by side
- [ ] Amount field optional
- [ ] Name field has placeholder
- [ ] Delete action works
- [ ] Accessible labels

### Test Cases
- Render with amount and name
- Render with name only
- Delete removes row
- Focus moves to name after amount

---

## Task 6: RecipeFormView

**Complexity**: High
**Estimated Files**: 1 new file
**Dependencies**: Task 4, Task 5

### Description
Create the main recipe form view used by both Add and Edit flows.

### Implementation Steps
1. Create `Features/RecipeForm/Views/RecipeFormView.swift`
2. Implement form layout in Form/List:
   - Title Section: TextField with required indicator
   - Description Section: TextEditor (3-4 lines)
   - Tags Section: TextField with placeholder
   - Yields Section: TextField with placeholder
   - Ingredients Section: Dynamic list with IngredientRowView + Add button
   - Instructions Section: TextEditor

3. Implement toolbar:
   - Cancel button (leading)
   - Save button (trailing, disabled when invalid)

4. Show validation errors inline (red text)
5. Implement cancel confirmation alert when hasUnsavedChanges
6. Show saving progress indicator
7. Handle save success/error

### Acceptance Criteria
- [ ] All RecipeMD fields have inputs
- [ ] Required fields marked with *
- [ ] Dynamic ingredient list works
- [ ] Cancel shows confirmation when dirty
- [ ] Save disabled until valid
- [ ] Loading state during save
- [ ] Error alert on failure

### Test Cases
- Form renders correctly
- Add ingredient button works
- Remove ingredient swipe works
- Cancel with changes shows alert
- Cancel without changes dismisses
- Save shows loading then success

---

## Task 7: Add Recipe Flow

**Complexity**: Medium
**Estimated Files**: 2 files modified
**Dependencies**: Task 6

### Description
Wire up the Add Recipe button in RecipeListView to present the form and handle completion.

### Implementation Steps
1. Modify RecipeListView.swift:
   - Add `@State private var showingAddRecipe = false`
   - Connect + button to toggle sheet
   - Present RecipeFormView in sheet with mode: .add

2. Create add recipe entry point:
   - Sheet presentation
   - Pass RecipeStore and FolderManager
   - Handle dismiss on success

3. Refresh recipe list after successful add

### Acceptance Criteria
- [ ] + button presents add form as sheet
- [ ] New recipe appears in list after save
- [ ] Sheet dismisses on save
- [ ] Sheet dismisses on cancel (with confirmation if needed)

### Test Cases
- TC-021: Create simple recipe
- TC-022: Validation - missing title
- TC-023: Validation - no ingredients
- TC-024: Cancel with changes
- TC-025: File name conflict
- TC-026: RecipeMD format validation
- TC-027: Special characters in title

---

## Task 8: Edit Recipe Flow

**Complexity**: Medium
**Estimated Files**: 1 file modified
**Dependencies**: Task 6

### Description
Wire up the Edit button in RecipeDetailView to present the form pre-populated with recipe data.

### Implementation Steps
1. Modify RecipeDetailView.swift:
   - Add `@State private var showingEditRecipe = false`
   - Connect edit button to toggle sheet
   - Present RecipeFormView in sheet with mode: .edit(recipe)

2. Handle edit completion:
   - Reload recipe content after save
   - Dismiss sheet

3. Handle file conflicts (optional for v1.0):
   - Check modification date before save
   - Show conflict alert if changed externally

### Acceptance Criteria
- [ ] Edit button presents form as sheet
- [ ] Form pre-populated with recipe data
- [ ] Changes reflected in detail view after save
- [ ] File updated on disk

### Test Cases
- TC-028: Edit recipe title
- TC-029: Edit ingredients
- TC-030: Edit with no changes
- TC-031: Cancel with unsaved changes
- TC-032: Save with validation error

---

## Task 9: Delete Recipe Flow

**Complexity**: Medium
**Estimated Files**: 2 files modified
**Dependencies**: Task 3

### Description
Implement delete functionality from both list view (swipe) and detail view (menu).

### Implementation Steps
1. Modify RecipeListView.swift:
   - Add swipe action to recipe rows
   - Show delete confirmation alert
   - Call RecipeStore.deleteRecipe
   - Handle errors

2. Modify RecipeDetailView.swift:
   - Add Delete to toolbar menu (...)
   - Show delete confirmation alert
   - Navigate back to list on success
   - Handle errors

3. Add delete confirmation alert:
   ```swift
   Alert(
       title: "Delete Recipe?",
       message: "Are you sure you want to delete \"\(recipe.title)\"? This cannot be undone.",
       primaryButton: .destructive(Text("Delete")) { ... },
       secondaryButton: .cancel()
   )
   ```

### Acceptance Criteria
- [ ] Swipe-to-delete in list view
- [ ] Delete menu option in detail view
- [ ] Confirmation dialog before delete
- [ ] Recipe removed from list after delete
- [ ] Navigate back from detail after delete
- [ ] Error alert on failure

### Test Cases
- TC-036: Delete from detail view
- TC-037: Delete from list swipe
- TC-038: Cancel deletion
- TC-039: Delete with file error
- TC-040: Delete last recipe

---

## Task 10: Unit Tests

**Complexity**: Medium
**Estimated Files**: 2-3 new test files
**Dependencies**: Tasks 1-9

### Description
Add comprehensive unit tests for all new functionality.

### Implementation Steps
1. Create `OpenCookbookTests/RecipeMDSerializerTests.swift`:
   - Test serialization of complete recipe
   - Test serialization of minimal recipe
   - Test round-trip (parse → serialize → parse)
   - Test special character handling

2. Create `OpenCookbookTests/FilenameGeneratorTests.swift`:
   - Test slugification
   - Test duplicate detection
   - Test edge cases (empty, unicode)

3. Create `OpenCookbookTests/RecipeFormViewModelTests.swift`:
   - Test validation logic
   - Test hasUnsavedChanges
   - Test form → Recipe conversion

4. Extend `RecipeStoreTests.swift`:
   - Test save new recipe
   - Test update recipe
   - Test delete recipe

### Acceptance Criteria
- [ ] RecipeMDSerializer fully tested
- [ ] FilenameGenerator fully tested
- [ ] RecipeFormViewModel validation tested
- [ ] RecipeStore CRUD operations tested
- [ ] All tests pass

---

## Implementation Order

For efficient development, implement tasks in this order:

### Phase 1: Foundation (Tasks 1-3)
Build the core services before any UI work.

1. **Task 1**: RecipeMD Serializer
2. **Task 2**: Filename Utilities
3. **Task 3**: RecipeStore Write/Delete Methods

### Phase 2: Form Components (Tasks 4-6)
Build the shared form UI.

4. **Task 5**: IngredientRowView (no dependencies)
5. **Task 4**: RecipeFormViewModel
6. **Task 6**: RecipeFormView

### Phase 3: Feature Integration (Tasks 7-9)
Wire up the features.

7. **Task 7**: Add Recipe Flow
8. **Task 8**: Edit Recipe Flow
9. **Task 9**: Delete Recipe Flow

### Phase 4: Quality (Task 10)
Add tests for all new code.

10. **Task 10**: Unit Tests

---

## Files to Create

| File | Task |
|------|------|
| `Core/Services/RecipeMDSerializer.swift` | 1 |
| `Core/Extensions/String+Slug.swift` | 2 |
| `Core/Services/FilenameGenerator.swift` | 2 |
| `Core/Models/RecipeError.swift` | 3 |
| `Features/RecipeForm/ViewModels/RecipeFormViewModel.swift` | 4 |
| `Features/RecipeForm/Views/IngredientRowView.swift` | 5 |
| `Features/RecipeForm/Views/RecipeFormView.swift` | 6 |
| `OpenCookbookTests/RecipeMDSerializerTests.swift` | 10 |
| `OpenCookbookTests/FilenameGeneratorTests.swift` | 10 |
| `OpenCookbookTests/RecipeFormViewModelTests.swift` | 10 |

## Files to Modify

| File | Task |
|------|------|
| `Core/Services/RecipeStore.swift` | 3 |
| `Features/RecipeList/Views/RecipeListView.swift` | 7, 9 |
| `Features/RecipeDetail/Views/RecipeDetailView.swift` | 8, 9 |
