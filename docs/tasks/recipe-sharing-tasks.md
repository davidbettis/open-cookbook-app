# Task Breakdown: Recipe Sharing

**Feature Spec**: [docs/specs/recipe-sharing.md](../specs/recipe-sharing.md)

---

## Task 1: Register custom UTI for `.recipe.md`
**Files:** `Info.plist` (modify)
**Complexity:** Low
**Dependencies:** None

Declare a custom UTI so iOS recognizes `.recipe.md` files as belonging to OpenCookbook. This must land first so that Transferable file representations and file-open handling reference a registered type.

- Add `UTExportedTypeDeclarations` entry:
  - Identifier: `com.opencookbook.recipemd`
  - Description: "RecipeMD Recipe"
  - Conforms to: `public.plain-text`
  - Extension: `recipe.md`
- Add `CFBundleDocumentTypes` entry:
  - Content types: `com.opencookbook.recipemd`
  - Role: Viewer
- **Verify early**: Build, install on device/simulator, confirm that tapping a `.recipe.md` file in Files shows "Open in OpenCookbook" (even if the app doesn't handle it yet — just confirm the UTI is recognized)

**Acceptance Criteria:**
- [ ] UTI declared in Info.plist with correct identifier, extension, and conformance
- [ ] CFBundleDocumentTypes references the custom UTI
- [ ] iOS recognizes `.recipe.md` files as associated with OpenCookbook
- [ ] Regular `.md` files do NOT show "Open in OpenCookbook"
- [ ] Build succeeds

---

## Task 2: Implement Transferable type for recipe sharing
**Files:** `Features/Sharing/Models/ShareableRecipe.swift` (new)
**Complexity:** Medium
**Dependencies:** Task 1

Create a `Transferable` type that provides a `.recipe.md` file representation and a plain-text fallback. This is the data model that `ShareLink` will use.

- Define `ShareableRecipe` struct with `title: String` and `markdown: String` properties
- Conform to `Transferable` protocol
- Primary representation: `FileRepresentation` exporting as `com.opencookbook.recipemd`
  - Write markdown to a temp file named `{title}.recipe.md`
  - Return the file URL
- Fallback representation: `ProxyRepresentation` using `markdown` string (plain text)
- Use `RecipeFileSerializer().serialize(recipeFile)` at the call site to generate the markdown

**Acceptance Criteria:**
- [ ] `ShareableRecipe` conforms to `Transferable`
- [ ] File representation creates a `.recipe.md` temp file with correct content
- [ ] Plain text representation returns the markdown string
- [ ] File is named `{recipe title}.recipe.md`
- [ ] Build succeeds

---

## Task 3: Update ShareLink in RecipeDetailView
**File:** `Features/Onboarding/RecipeDetail/Views/RecipeDetailView.swift` (modify)
**Complexity:** Low
**Dependencies:** Task 2

Replace the current `ShareLink(item: filePath)` with one that uses `ShareableRecipe`.

- Read the recipe's markdown content (already available as `markdownContent` state in the view)
- Construct a `ShareableRecipe` from the recipe title and markdown
- Replace the `ShareLink` at line 82 to use the new type
- Keep the same share button icon and accessibility label

**Acceptance Criteria:**
- [ ] Share button uses `ShareableRecipe` instead of file URL
- [ ] Sharing via iMessage/email sends a `.recipe.md` file attachment
- [ ] Sharing via AirDrop sends a `.recipe.md` file
- [ ] Shared file content is valid RecipeMD markdown
- [ ] Build succeeds

---

## Task 4: Add `.onOpenURL` handler to receive `.recipe.md` files
**File:** `App/OpenCookbookApp.swift` (modify)
**Complexity:** Medium
**Dependencies:** Task 1

Add URL handling so the app can receive `.recipe.md` files from AirDrop, Files, email attachments, etc.

- Add `.onOpenURL { url in ... }` modifier to the root `WindowGroup`
- Read the file contents from the incoming URL (handle security-scoped access if needed)
- Parse with `RecipeFileParser` to validate it's a real recipe
- Store the parsed result in app-level state (e.g., `@State private var pendingImportMarkdown: String?`)
- If the app isn't onboarded yet (no folder selected), persist the markdown in `@AppStorage("pendingImportRecipe")` and present it after onboarding completes
- If onboarded, trigger presentation of `RecipeImportPreviewView` (Task 5)

**Acceptance Criteria:**
- [ ] `.onOpenURL` handler added to `OpenCookbookApp`
- [ ] Incoming file is read and parsed
- [ ] Invalid/non-recipe files show a friendly error alert
- [ ] Pending import survives the onboarding flow
- [ ] Build succeeds

---

## Task 5: Create RecipeImportPreviewView
**File:** `Features/Sharing/Views/RecipeImportPreviewView.swift` (new)
**Complexity:** Medium
**Dependencies:** Task 4

Build the import confirmation screen shown when receiving a shared recipe.

- Accept the parsed recipe content (markdown string or `RecipeFile`)
- Display a read-only preview of the recipe: title, tags, ingredients, instructions
- Reuse existing `RecipeDetailContent` or a simplified version for the preview
- "Save to My Recipes" button: calls `RecipeStore.saveNewRecipeFromMarkdown()` with the current folder
- "Cancel" button: dismisses without saving
- Show a success confirmation (e.g., brief toast or dismiss with animation) after save
- Handle save errors with an alert

**Acceptance Criteria:**
- [ ] Preview shows recipe title, tags, ingredients, and instructions
- [ ] "Save to My Recipes" saves the recipe to the user's folder
- [ ] "Cancel" dismisses without side effects
- [ ] Save errors shown in an alert
- [ ] Build succeeds

---

## Task 6: Create IncomingRecipeHandler service
**File:** `Features/Sharing/Services/IncomingRecipeHandler.swift` (new)
**Complexity:** Low
**Dependencies:** None

Extract the file-reading and validation logic into a small service so `OpenCookbookApp` stays lean.

- `func handleIncomingFile(url: URL) -> Result<String, IncomingRecipeError>`
  - Start security-scoped access if needed
  - Read file contents as UTF-8 string
  - Validate it parses as RecipeMD (use `RecipeFileParser`)
  - Return the markdown string on success, or a typed error on failure
- Define `IncomingRecipeError`: `.fileUnreadable`, `.notARecipe`, `.parseError(String)`
- Each error case has a user-facing description

**Acceptance Criteria:**
- [ ] Reads file contents with proper security-scoped access
- [ ] Returns markdown string for valid recipes
- [ ] Returns typed error for invalid files
- [ ] Error descriptions are user-friendly
- [ ] Build succeeds

---

## Task 7: Add duplicate detection on import
**File:** `Core/Services/RecipeStore.swift` (modify), `Features/Sharing/Views/RecipeImportPreviewView.swift` (modify)
**Complexity:** Medium
**Dependencies:** Task 5

When importing a shared recipe, check for title conflicts.

- Add `func findRecipeByTitle(_ title: String) -> RecipeFile?` to `RecipeStore`
  - Case-insensitive comparison against `recipes` array
- In `RecipeImportPreviewView`, before saving, check for duplicates
- If duplicate found, show a confirmation dialog:
  - "A recipe named '{title}' already exists."
  - "Replace" — overwrites the existing file
  - "Keep Both" — saves with a modified filename (e.g., appends " 2")
  - "Cancel" — dismisses without saving
- "Replace" uses `RecipeStore.updateRecipe()` on the existing file
- "Keep Both" uses `RecipeStore.saveNewRecipeFromMarkdown()` (FilenameGenerator handles uniqueness)

**Acceptance Criteria:**
- [ ] `findRecipeByTitle` returns matching recipe (case-insensitive)
- [ ] Duplicate triggers confirmation dialog with three options
- [ ] "Replace" overwrites existing recipe file
- [ ] "Keep Both" saves with a unique filename
- [ ] "Cancel" dismisses without saving
- [ ] No dialog when title is unique
- [ ] Build succeeds

---

## Task 8: Unit tests for sharing
**File:** `OpenCookbookTests/RecipeSharingTests.swift` (new)
**Complexity:** Medium
**Dependencies:** Tasks 2, 6, 7

Write unit tests covering the sharing and import logic:

**ShareableRecipe:**
- Transferable file representation creates a valid `.recipe.md` file
- File is named correctly from recipe title
- Plain text representation matches the markdown content
- Handles special characters in title (slashes, quotes, unicode)

**IncomingRecipeHandler:**
- Valid `.recipe.md` file returns success with markdown string
- Non-recipe markdown returns `.notARecipe` error
- Unreadable file returns `.fileUnreadable` error

**RecipeStore.findRecipeByTitle:**
- Finds recipe by exact title
- Finds recipe case-insensitively
- Returns nil when no match

Use Swift Testing framework (`@Test`, `#expect`, `@Suite`).

**Acceptance Criteria:**
- [ ] All test cases pass
- [ ] Edge cases covered: empty files, special characters, missing files
- [ ] All existing tests still pass

---

## Task 9: Integration testing and polish
**Complexity:** Low
**Dependencies:** Tasks 1–8

End-to-end manual testing of the full sharing flow:

1. Build with XcodeBuildMCP
2. Run all unit tests
3. Manual test — **send flow**:
   - Open a recipe → tap Share → send via iMessage → verify recipient gets `.recipe.md` file
   - Open a recipe → tap Share → AirDrop to another device → verify file received
4. Manual test — **receive flow**:
   - Receive a `.recipe.md` via AirDrop → "Open in OpenCookbook" → preview → save → verify in library
   - Open a `.recipe.md` from Files app → same flow
5. Manual test — **edge cases**:
   - Open a regular `.md` file → verify OpenCookbook does NOT appear in "Open in" menu
   - Receive a malformed `.recipe.md` → verify friendly error
   - Import a recipe with a duplicate title → verify Replace/Keep Both/Cancel dialog
   - Receive a recipe before onboarding → complete onboarding → verify recipe is offered for import
6. Fix any issues found

**Acceptance Criteria:**
- [ ] App builds without warnings
- [ ] All unit tests pass
- [ ] Send via iMessage/AirDrop works end-to-end
- [ ] Receive and import works end-to-end
- [ ] Regular `.md` files not associated with the app
- [ ] Error handling works for invalid files
- [ ] Duplicate detection works correctly
- [ ] Pre-onboarding import queuing works

---

## Summary

| Task | Complexity | Dependencies | Status |
|------|------------|--------------|--------|
| 1. Register custom UTI for `.recipe.md` | Low | None | Pending |
| 2. Implement Transferable type | Medium | Task 1 | Pending |
| 3. Update ShareLink in RecipeDetailView | Low | Task 2 | Pending |
| 4. Add `.onOpenURL` handler | Medium | Task 1 | Pending |
| 5. Create RecipeImportPreviewView | Medium | Task 4 | Pending |
| 6. Create IncomingRecipeHandler service | Low | None | Pending |
| 7. Add duplicate detection | Medium | Task 5 | Pending |
| 8. Unit tests | Medium | Tasks 2, 6, 7 | Pending |
| 9. Integration testing and polish | Low | Tasks 1–8 | Pending |

**Implementation Order**: 1 + 6 (parallel) → 2 + 4 (parallel) → 3 + 5 (parallel) → 7 → 8 → 9

**Critical Path**: Tasks 1 → 2 → 3 (send flow), Tasks 1 → 4 → 5 (receive flow)

**Files Modified:**
| File | Tasks |
|------|-------|
| `Info.plist` | Task 1 |
| `Features/Sharing/Models/ShareableRecipe.swift` | Task 2 (new) |
| `Features/Onboarding/RecipeDetail/Views/RecipeDetailView.swift` | Task 3 |
| `App/OpenCookbookApp.swift` | Task 4 |
| `Features/Sharing/Views/RecipeImportPreviewView.swift` | Tasks 5, 7 (new) |
| `Features/Sharing/Services/IncomingRecipeHandler.swift` | Task 6 (new) |
| `Core/Services/RecipeStore.swift` | Task 7 |
| `OpenCookbookTests/RecipeSharingTests.swift` | Task 8 (new) |
