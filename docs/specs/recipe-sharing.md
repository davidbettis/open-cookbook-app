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

---

## Phase 1: Share Sheet + File Registration (3-5 days)

### 1a. Enhanced Share Sheet

**Problem**: The current `ShareLink(item: filePath)` in `RecipeDetailView.swift:82` shares the raw file URL — useless to recipients without direct iCloud access to that file.

**Solution**: Share the recipe as a `.recipe.md` file via `Transferable`. The file is plain text, so it's human-readable even without the app. Recipients with OpenCookbook installed can tap to open and import directly.

- **Sender**: Tap share → iOS share sheet → iMessage, email, AirDrop, Notes, etc.
- **Receiver (with app)**: Gets a `.recipe.md` file → taps → "Open in OpenCookbook" → import preview → save.
- **Receiver (without app)**: Gets a `.recipe.md` file they can open in any text editor — it's valid markdown.

**Note**: The system determines how the `Transferable` representations are used by each share target. iMessage/email may send the file as an attachment rather than inline text. This is fine — the file is readable in any text editor.

**Build**:
- Modify `ShareLink` in `RecipeDetailView.swift` to use a custom `Transferable` type
- Implement `Transferable` conformance with `fileRepresentation` (as `.recipe.md`) and `plainText` fallback
- Use `RecipeFileSerializer().serialize(recipeFile)` to generate the markdown content

### 1b. Custom File Type Registration (`.recipe.md`)

Use a compound extension `.recipe.md` so OpenCookbook only handles recipe files, not all markdown. Files remain valid markdown (any text editor opens them via the `.md` outer extension), while the compound extension signals "this is a recipe" to both humans and iOS.

Example filename: `Chocolate Chip Cookies.recipe.md`

- **Sender**: AirDrop/share sends a `.recipe.md` file (via `Transferable` in Phase 1a)
- **Receiver**: Gets `.recipe.md` file → taps → "Open in OpenCookbook" → sees recipe preview → "Save to My Recipes"

**Build**:
- Declare an exported UTI (`com.opencookbook.recipemd`) with compound extension `recipe.md`, conforming to `public.plain-text`
- Add `CFBundleDocumentTypes` to Info.plist for the custom UTI
- Add `.onOpenURL` handler to `OpenCookbookApp.swift`
- New `RecipeImportPreviewView` — shows parsed recipe with Save/Cancel buttons
- Validate content parses as RecipeMD; show friendly error if not
- Edge case: if app isn't onboarded yet, queue recipe in `@AppStorage`, prompt to save after folder selection
- Verify early: confirm iOS 17 correctly matches compound extensions in `UTExportedTypeDeclarations`

**Files modified:**
- `Features/Onboarding/RecipeDetail/Views/RecipeDetailView.swift` — change ShareLink to use Transferable
- `App/OpenCookbookApp.swift` — add `.onOpenURL` handler
- `Info.plist` — add `UTExportedTypeDeclarations` and `CFBundleDocumentTypes`
- New: `Features/Sharing/Views/RecipeImportPreviewView.swift`
- New: `Features/Sharing/Services/IncomingRecipeHandler.swift`

---

## Phase 2: Polish (2-3 days)

### 2a. Duplicate Detection
When importing a shared recipe, check if a recipe with the same title already exists. Offer "Replace," "Keep Both" (appends number), or "Cancel."

### 2b. Share as Image (optional stretch)
Generate a nice-looking image/card of the recipe for sharing on social media or messaging apps where markdown renders poorly. Use SwiftUI's `ImageRenderer` to create a shareable image from a styled recipe card view.

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Incoming `.recipe.md` fails to parse | "This doesn't appear to be a valid recipe" error with OK to dismiss |
| App not onboarded (no folder selected) | Queue pending recipe in `@AppStorage` as raw markdown. After onboarding, prompt to save. |
| Recipe with same title exists | Phase 2: Replace / Keep Both / Cancel dialog |
| macOS compatibility | `ShareLink`, `Transferable`, and `.onOpenURL` are cross-platform SwiftUI APIs — no platform-specific code needed |

---

## Verification

- **Phase 1 — Send**: Share a recipe via iMessage → verify recipient gets a `.recipe.md` file attachment that is readable as plain text.
- **Phase 1 — Receive via AirDrop**: AirDrop a `.recipe.md` file → verify "Open in OpenCookbook" appears → verify import preview shows correctly → save and verify it appears in library.
- **Phase 1 — Non-recipe .md**: Verify that regular `.md` files (READMEs, notes) do NOT show "Open in OpenCookbook."
- **Phase 1 — Invalid .recipe.md**: Open a malformed `.recipe.md` in OpenCookbook → verify friendly error message, no crash.
- **Phase 2 — Duplicate**: Import a recipe with existing title → verify Replace/Keep Both/Cancel dialog.
