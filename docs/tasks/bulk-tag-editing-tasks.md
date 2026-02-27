# Task Breakdown: Bulk Tag Editing

**Feature Spec**: [docs/specs/bulk-tag-editing.md](../specs/bulk-tag-editing.md)

---

## Task 1: Create toast/banner component
**File:** `src/OpenCookbook/Core/Views/ToastView.swift` (new)
**Complexity:** Low
**Dependencies:** None

Create a reusable toast component for temporary confirmation messages. No existing toast/banner component exists in the codebase.

- Define `ToastView` — an overlay view that shows a brief message and auto-dismisses
- Accept a `message: String` and optional `style: ToastStyle` (`.success`, `.error`)
- Show as an overlay at the bottom of the screen with a capsule background
- Auto-dismiss after ~2 seconds with a fade animation
- Create a `ToastModifier` view modifier for easy attachment: `.toast(message:isPresented:style:)`
- Use `withAnimation` for slide-in/fade-out transitions

**Acceptance Criteria:**
- [ ] Toast appears with message text and dismisses automatically
- [ ] Success and error styles have distinct visual treatment
- [ ] View modifier allows easy attachment to any view
- [ ] Toast does not interfere with user interaction underneath

---

## Task 2: Add bulk tag operations to RecipeStore
**File:** `src/OpenCookbook/Core/Services/RecipeStore.swift` (modify)
**Complexity:** Medium
**Dependencies:** None

Add methods for bulk adding and removing tags from multiple recipes:

- Add `bulkAddTags(_ tags: Set<String>, to recipeIDs: Set<UUID>) async -> BulkOperationResult`
  - For each recipe ID: find recipe in `recipes`, compute union of existing tags + new tags, serialize to markdown, write file atomically with security-scoped access, update store array
  - Each write is independent — failures don't stop other writes
  - Return success count and list of failures with errors
- Add `bulkRemoveTags(_ tags: Set<String>, from recipeIDs: Set<UUID>) async -> BulkOperationResult`
  - Same pattern but computes set difference (existing tags minus removed tags)
- Define `BulkOperationResult` struct: `successCount: Int`, `failureCount: Int`, `failedRecipes: [(RecipeFile, Error)]`
- Use existing `RecipeFileSerializer` and security-scoped file access patterns already in `updateRecipe()`
- Wrap mutations in `withAnimation` to match existing RecipeStore patterns

**Acceptance Criteria:**
- [ ] Bulk add merges tags (set union) without duplicates
- [ ] Bulk remove only removes specified tags, preserving others
- [ ] Each file write is independent — partial failures handled
- [ ] Result includes success/failure counts
- [ ] Store's `recipes` array updated after each successful write
- [ ] Unit tests for bulk add and bulk remove

---

## Task 3: Add edit mode state to RecipeListViewModel
**File:** `src/OpenCookbook/Features/RecipeList/Views/RecipeListView.swift` (modify — ViewModel is nested)
**Complexity:** Medium
**Dependencies:** Task 2

Extend the nested `RecipeListViewModel` with selection and bulk edit state:

- Add `isEditMode: Bool` — tracks whether selection mode is active
- Add `selectedRecipeIDs: Set<UUID>` — tracked selected recipes
- Add `selectedCount: Int` computed property
- Add `toggleSelection(_ recipeID: UUID)` method
- Add `enterEditMode()` / `exitEditMode()` methods (exit clears selection)
- Add `bulkAddTags(_ tags: Set<String>) async -> BulkOperationResult` — delegates to `recipeStore.bulkAddTags()`, then calls `syncSearchService()`
- Add `bulkRemoveTags(_ tags: Set<String>) async -> BulkOperationResult` — same pattern
- Add `tagsOnSelectedRecipes() -> [(tag: String, count: Int)]` — scans selected recipes, returns tags with how many of the selected recipes have each tag, for the Remove Tags sheet

**Acceptance Criteria:**
- [ ] Edit mode toggles on/off correctly
- [ ] Selection tracks/untrack recipe IDs
- [ ] Exiting edit mode clears selection
- [ ] Bulk operations delegate to RecipeStore and refresh search index
- [ ] `tagsOnSelectedRecipes()` returns correct tag counts

---

## Task 4: Create BulkTagAddView sheet
**File:** `src/OpenCookbook/Features/RecipeList/Views/BulkTagAddView.swift` (new)
**Complexity:** Low
**Dependencies:** None (reuses existing `TagPickerView`)

Create the "Add Tags" sheet that wraps the existing `TagPickerView`:

- Presented as a sheet with navigation bar
- Title: **"Add Tags to N Recipes"** (N = selected count)
- Leading button: **"Cancel"** (dismisses sheet)
- Trailing button: **"Apply"** (disabled until at least one tag selected)
- Body: embed existing `TagPickerView` with a local `@State selectedTags: Set<String>` and `customTagText: String`
- Pass tag frequencies from `RecipeSearchService`
- On Apply: call a completion closure with the selected tags, then dismiss

**Acceptance Criteria:**
- [ ] Sheet shows TagPickerView with full vocabulary
- [ ] Apply button disabled until tags selected
- [ ] Cancel dismisses without action
- [ ] Apply returns selected tags via closure

---

## Task 5: Create BulkTagRemoveView sheet
**File:** `src/OpenCookbook/Features/RecipeList/Views/BulkTagRemoveView.swift` (new)
**Complexity:** Medium
**Dependencies:** None

Create the "Remove Tags" sheet showing only tags present on selected recipes:

- Presented as a sheet with navigation bar
- Title: **"Remove Tags from N Recipes"**
- Leading button: **"Cancel"**, Trailing button: **"Apply"** (disabled until tags selected)
- Accept `tagsWithCounts: [(tag: String, count: Int)]` and `totalSelected: Int`
- Display tags as tappable chips using same chip styling as `TagPickerView` (capsule with conditional highlight)
- Each chip label: **"tagname (X of Y)"** (e.g., "italian (3 of 5)")
- Selected chips show checkmark, same visual treatment as TagPickerView
- Use `FlowLayout` from TagPickerView for chip arrangement (may need to extract to shared location)
- On Apply: call completion closure with selected tag names

**Acceptance Criteria:**
- [ ] Only tags from selected recipes are shown
- [ ] Each tag shows count of selected recipes that have it
- [ ] Chip styling matches TagPickerView
- [ ] Apply button disabled until tags selected
- [ ] Apply returns selected tags via closure

---

## Task 6: Add edit mode UI to RecipeListView
**File:** `src/OpenCookbook/Features/RecipeList/Views/RecipeListView.swift` (modify)
**Complexity:** High
**Dependencies:** Tasks 1, 3, 4, 5

Wire up the full edit mode UI in the recipe list:

- **Toolbar changes:**
  - Add "Select" button (leading). In edit mode it shows "Done" instead
  - Hide the add-recipe menu when in edit mode
- **List changes:**
  - In edit mode, show selection circles on each recipe row
  - Tapping a row toggles selection (checkmark appears/disappears)
  - Disable navigation push when in edit mode (tap selects instead of navigating)
- **Bottom toolbar:**
  - Appears when in edit mode
  - Shows "N Selected" label
  - "Add Tags" and "Remove Tags" buttons, disabled when selection is empty
- **Sheet presentation:**
  - "Add Tags" button presents `BulkTagAddView` as sheet
  - "Remove Tags" button presents `BulkTagRemoveView` as sheet
  - On Apply from either sheet: call ViewModel bulk method, show toast, exit edit mode
- **Error handling:**
  - If `BulkOperationResult.failureCount > 0`: show error toast, stay in edit mode, keep failed recipes selected
- **Toast:**
  - Success: "Added N tags to N recipes" or "Removed N tags from N recipes"
  - Partial failure: "Updated X of Y recipes. Z recipes could not be updated."
- **Search/filter interaction:**
  - Search field and tag filter bar remain functional during edit mode
  - Selection applies only to currently visible/filtered recipes

**Acceptance Criteria:**
- [ ] "Select" button enters edit mode with selection circles
- [ ] "Done" button exits edit mode and clears selection
- [ ] Bottom toolbar shows count and action buttons
- [ ] Action buttons disabled when nothing selected
- [ ] Add Tags sheet opens and applies correctly
- [ ] Remove Tags sheet opens and applies correctly
- [ ] Toast shown after successful operation
- [ ] Edit mode exits on success, stays on partial failure
- [ ] Search and tag filter work during edit mode
- [ ] Add-recipe menu hidden during edit mode

---

## Task 7: Add unit tests for bulk tag editing
**Files:** `src/OpenCookbookTests/BulkTagEditingTests.swift` (new)
**Complexity:** Medium
**Dependencies:** Tasks 2, 3

Write unit tests covering bulk tag operations:

**RecipeStore bulk operations:**
- Bulk add tags to multiple recipes — all recipes get new tags
- Bulk add is additive — existing tags preserved (set union)
- Bulk add with tags already present — no duplicates
- Bulk remove tags from multiple recipes — specified tags removed
- Bulk remove preserves other tags on each recipe
- Bulk remove tag not present on a recipe — no error, no-op for that recipe
- Result returns correct success/failure counts

**RecipeListViewModel:**
- Enter/exit edit mode toggles state
- Selection tracking: toggle adds/removes IDs
- Exit edit mode clears selection
- `tagsOnSelectedRecipes()` returns correct tag-to-count mapping
- `tagsOnSelectedRecipes()` with no overlapping tags returns all tags at count 1

**Acceptance Criteria:**
- [ ] All test cases pass
- [ ] Edge cases covered: empty selection, no-op operations, all recipes fail
- [ ] Uses Swift Testing framework (`@Test`, `#expect`)

---

## Verification Checklist
1. Build succeeds
2. All tests pass
3. Manual: Open recipe list → tap "Select" → selection circles appear
4. Manual: Tap recipes → checkmarks toggle, count updates in bottom toolbar
5. Manual: "Add Tags" → tag picker sheet → select tags → "Apply" → tags added, toast shown, edit mode exits
6. Manual: "Remove Tags" → shows only tags from selected recipes with counts → select → "Apply" → tags removed
7. Manual: Search for recipes, enter edit mode, bulk edit filtered results
8. Manual: Filter by tag, enter edit mode, bulk edit filtered results
9. Manual: Verify "Done" cancels edit mode without changes
10. Manual: Verify add-recipe menu hidden during edit mode
