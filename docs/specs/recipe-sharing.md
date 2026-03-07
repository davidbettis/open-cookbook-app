# Recipe Sharing Feature Spec

## Context

Users want to share recipes with friends/family. Since OpenCookbook has no central server and stores recipes as plain RecipeMD markdown files (~500-2000 bytes), sharing must work peer-to-peer via platform infrastructure. The approach must align with the app's privacy-first, no-accounts philosophy.

## Approaches Evaluated and Rejected

| Approach | Why not |
|----------|---------|
| **Universal links + web fallback** | Requires owning/maintaining a domain and hosting. Skipping for now — can revisit later. |
| **iCloud Drive sharing (CKShare)** | Requires both users have iCloud. UX is clunky (goes through Files). Already works via Files for power users. |
| **External service (S3)** | Contradicts privacy-first philosophy. Recipes are small enough that server infrastructure is unnecessary. |
| **CloudKit public database** | Overengineered. "No server" philosophy. |
| **Custom URL scheme** | No fallback when app isn't installed — link does nothing. Poor UX. |
| **ShareLink + Transferable** | Evaluated during implementation. `UIActivityViewController` was chosen instead because it allows per-target content adaptation (e.g., plain text for iMessage, file attachment for AirDrop/email). `ShareableRecipe` (Transferable conformance) was built but is unused dead code. |

---

## Implementation: Share Sheet + File Registration

### Custom File Type Registration (`.recipemd`)

A single extension `.recipemd` is used (not the compound `.recipe.md` originally considered). This avoids ambiguity with generic `.md` files while keeping the content as valid plain-text markdown.

**UTI**: `com.opencookbook.recipemd`, conforming to `public.text`

**Build**:
- `UTExportedTypeDeclarations` in `Info.plist` declares the UTI with extension `recipemd`
- `CFBundleDocumentTypes` registers the app as a "Viewer" (owner rank) for the custom UTI
- `UTType+Recipe.swift` provides a Swift extension `UTType.recipeMD` for programmatic access

### Share Sheet (Sending)

**Problem**: The original `ShareLink(item: filePath)` shared the raw file URL — useless to recipients without direct iCloud access.

**Solution**: `UIActivityViewController` with custom `UIActivityItemSource` adapters that tailor content per share target.

- **iMessage/Pasteboard**: Sends plain markdown text + promotional message with App Store link
- **AirDrop/Email**: Sends a `.recipemd` file attachment
- **Email**: Custom email body via `RecipeEmailBodySource` with promo link

Filename format: `{recipe-title}.recipemd`

Promotional message included in text shares: "Check out Open Cookbook to build a free recipe library. https://apps.apple.com/app/open-cookbook/id6740043751"

**Files**:
- `Features/Sharing/Views/RecipeShareSheet.swift` — `UIActivityViewController` wrapper with `RecipeActivitySource` and `RecipeEmailBodySource`
- `Features/Onboarding/RecipeDetail/Views/RecipeDetailView.swift` — share button presents `RecipeShareSheet` as a sheet with `.presentationDetents([.medium, .large])`. iOS only (`#if canImport(UIKit)`)

### Receiving Shared Recipes

**Flow**: Incoming `.recipemd` file -> `.onOpenURL` handler -> validation -> recipe edit form

- **`.onOpenURL` handler** in `OpenCookbookApp.swift` processes incoming `.recipemd` files
- **`IncomingRecipeHandler`** service (`Features/Sharing/Services/IncomingRecipeHandler.swift`) handles file reading and validation:
  - `handleIncomingFile(at:)` — reads file from URL (handles security-scoped resources for AirDrop)
  - `handleIncomingMarkdown(_:)` — validates markdown parses as a recipe with a non-empty title
  - Returns `IncomingRecipe` struct (raw markdown + parsed `Recipe`)
  - Error types: `.fileUnreadable`, `.notARecipe`
- **Import UX**: Routes through the recipe edit form (`RecipeFormView`), not a dedicated preview view. The user can review and edit before saving.

**Pre-onboarding edge case**: If the app isn't onboarded yet (no folder selected), the recipe markdown is queued in `UserDefaults` (key: `"pendingImportRecipeMarkdown"`). After folder selection, it's loaded and offered for import.

**Pending import plumbing**:
- `FolderManager.pendingImportMarkdown: String?` passes recipes from app entry point to recipe list
- `RecipeListView` watches this property, clears it, and routes through `handleImportedRecipe(markdown:)`

### Clipboard Import (Bonus)

Not in the original spec but implemented: a "Paste Recipe" menu option in the add-recipe menu (`RecipeListView`). Checks clipboard for valid recipe markdown via `IncomingRecipeHandler.handleIncomingMarkdown()` and routes to the edit form.

---

## Dead Code

The following files were built during development but are not used in the current flow:

- `Features/Sharing/Models/ShareableRecipe.swift` — `Transferable` conformance for `ShareLink`. Superseded by `UIActivityViewController` approach.
- `Features/Sharing/Views/RecipeImportPreviewView.swift` — dedicated import preview with Save/Cancel. Superseded by routing imports through the recipe edit form.

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Incoming `.recipemd` fails to parse | Error alert shown to user |
| App not onboarded (no folder selected) | Queue pending recipe in `UserDefaults`. After onboarding, prompt to save. |
| macOS compatibility | Share sheet is iOS-only (`#if canImport(UIKit)`). File receiving via `.onOpenURL` is cross-platform. |

---

## Future Considerations

These were planned but not yet implemented:

- **Duplicate detection**: Check if a recipe with the same title already exists when importing. Offer Replace / Keep Both / Cancel.
- **Share as image**: Generate a styled recipe card image for social media sharing using `ImageRenderer`.

---

## Tests

`OpenCookbookTests/IncomingRecipeHandlerTests.swift` — 12 test cases covering:
- Parse valid RecipeMD markdown
- Reject non-recipe text and empty strings
- Parse minimal recipes (title + ingredients only)
- File handling: valid files, missing files, non-recipe files

---

## Files

| File | Role |
|------|------|
| `src/Info.plist` | UTI and document type declarations |
| `Core/Extensions/UTType+Recipe.swift` | `UTType.recipeMD` extension |
| `Features/Sharing/Views/RecipeShareSheet.swift` | Share sheet (UIActivityViewController) |
| `Features/Sharing/Services/IncomingRecipeHandler.swift` | File reading and validation |
| `Features/Sharing/Models/ShareableRecipe.swift` | Unused Transferable model (dead code) |
| `Features/Sharing/Views/RecipeImportPreviewView.swift` | Unused import preview (dead code) |
| `Features/Onboarding/RecipeDetail/Views/RecipeDetailView.swift` | Share button in recipe detail |
| `App/OpenCookbookApp.swift` | `.onOpenURL` handler |
| `Core/Services/FolderManager.swift` | `pendingImportMarkdown` property |
| `Features/RecipeList/Views/RecipeListView.swift` | Pending import + clipboard import handling |
| `OpenCookbookTests/IncomingRecipeHandlerTests.swift` | Unit tests |
