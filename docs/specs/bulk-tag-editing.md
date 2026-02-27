# Feature Spec: Bulk Tag Editing

**Priority**: P1 (Should Have)
**Feature ID**: F010
**Related Specs**: [Tag Management](tag-management.md), [Edit Recipe](edit-recipe.md), [Recipe Library View](recipe-library-view.md)

## Description
Allow users to add or remove tags from multiple recipes at once using standard iOS edit mode selection in the recipe list. This eliminates the need to open and edit each recipe individually when reorganizing a collection.

## User Stories

### US-001: Add tags to multiple recipes
**As a** user organizing my recipe library
**I want** to select several recipes and add a tag to all of them at once
**So that** I can categorize recipes in bulk without editing each one

### US-002: Remove tags from multiple recipes
**As a** user cleaning up my tags
**I want** to select several recipes and remove a tag from all of them
**So that** I can fix tagging mistakes or reorganize without repetitive editing

### US-003: Filter then bulk-edit
**As a** user with a large library
**I want** to search or filter my list before selecting recipes for bulk editing
**So that** I can quickly find and select the recipes I want to change

## Design

### Edit Mode Flow

1. User taps **"Select"** button in the toolbar → list enters edit mode with selection circles on each row
2. Search field and tag filter bar remain functional — the user can narrow the list before or during selection
3. User taps recipes to select them (checkmarks appear)
4. A bottom toolbar appears showing **"N selected"** with **"Add Tags"** and **"Remove Tags"** buttons
5. Tapping either button opens a sheet with a tag picker
6. User picks tags and taps **"Apply"** → bulk operation runs → brief confirmation toast → edit mode exits

### Add Tags Sheet

Opens the existing `TagPickerView` component (same one used in the recipe form). Tags the user selects here are **added** to every selected recipe. Tags a recipe already has are left untouched — the operation is additive (set union).

### Remove Tags Sheet

Shows **only tags that exist on at least one of the selected recipes**, displayed as tappable chips (same chip styling as `TagPickerView`). Each chip shows how many of the selected recipes have that tag (e.g., "italian (3 of 5)"). Tags the user selects here are **removed** from every selected recipe that has them.

### Confirmation and Results

After applying:
- A brief toast/banner confirms the result: **"Added 2 tags to 8 recipes"** or **"Removed 1 tag from 5 recipes"**
- Edit mode exits and the list returns to normal view
- The tag filter bar and search results update to reflect changed tags

### Error Handling

- If some files fail to write (e.g., permission error, file locked), the operation completes for the recipes it can and shows an error: **"Updated 6 of 8 recipes. 2 recipes could not be updated."**
- Failed recipes are not modified — each file write is independent
- The user stays in edit mode if any writes fail, with the failed recipes still selected

## Acceptance Criteria

- [ ] "Select" button appears in the recipe list toolbar
- [ ] Tapping "Select" enters edit mode with selection circles on each recipe row
- [ ] Search field and tag filter bar remain functional during edit mode
- [ ] Bottom toolbar shows selected count and "Add Tags" / "Remove Tags" buttons
- [ ] Bottom toolbar only appears when at least one recipe is selected
- [ ] "Add Tags" opens tag picker sheet; selected tags are added to all selected recipes
- [ ] "Remove Tags" opens a sheet showing only tags present on selected recipes
- [ ] Remove tags sheet shows per-tag count (e.g., "3 of 5 selected")
- [ ] Bulk add is additive — existing tags on each recipe are preserved
- [ ] Bulk remove only removes specified tags — other tags on each recipe are preserved
- [ ] Confirmation toast shown after successful operation
- [ ] Edit mode exits after successful operation
- [ ] Partial failure shows error message and keeps edit mode active with failed recipes selected
- [ ] Each recipe's .md file is written atomically with security-scoped access
- [ ] Recipe list and tag filter bar update immediately after bulk operation

## UI/UX Requirements

### Toolbar Changes

In normal mode, the existing toolbar is unchanged. A **"Select"** button is added (leading placement). When tapped:
- "Select" button changes to **"Done"** (to cancel without acting)
- The add-recipe menu in the toolbar is hidden
- Bottom toolbar appears (initially empty until recipes are selected)

```
┌─────────────────────────────────────────────┐
│  Done              [icon]          (hidden)  │
├─────────────────────────────────────────────┤
│  🔍 Search Recipes...                       │
│  [tag1] [tag2] [tag3] ...                   │
├─────────────────────────────────────────────┤
│  ○  Recipe Card 1                           │
│  ●  Recipe Card 2  ✓                        │
│  ●  Recipe Card 3  ✓                        │
│  ○  Recipe Card 4                           │
├─────────────────────────────────────────────┤
│  2 Selected     [Add Tags] [Remove Tags]    │
└─────────────────────────────────────────────┘
```

### Add Tags Sheet

Reuses the existing `TagPickerView` component. Presented as a sheet with:
- Navigation bar: **"Cancel"** (leading) and **"Apply"** (trailing, disabled until tags selected)
- Title: **"Add Tags to N Recipes"**
- Full tag picker with categories, search, and custom tag support

### Remove Tags Sheet

Custom view showing only relevant tags. Presented as a sheet with:
- Navigation bar: **"Cancel"** (leading) and **"Apply"** (trailing, disabled until tags selected)
- Title: **"Remove Tags from N Recipes"**
- Tags displayed as tappable chips (same styling as `TagPickerView` chips)
- Each chip label includes count: **"italian (3 of 5)"**
- Selected chips highlighted with checkmark (same selected state as `TagPickerView`)

```
┌─────────────────────────────────────────────┐
│  Cancel    Remove Tags from 5 Recipes  Apply│
├─────────────────────────────────────────────┤
│                                             │
│  [italian (3 of 5)]  [✓ dinner (5 of 5)]   │
│  [chicken (2 of 5)]  [baked (1 of 5)]      │
│  [date-night (1 of 5)]                      │
│                                             │
└─────────────────────────────────────────────┘
```

### Confirmation Toast

A temporary banner at the top or bottom of the list (consistent with iOS conventions):
- Appears for ~2 seconds then fades
- Text: "Added N tags to N recipes" or "Removed N tags from N recipes"

## Technical Requirements

### New Files
- `BulkTagAddView.swift` — Sheet wrapping `TagPickerView` with Apply/Cancel and title
- `BulkTagRemoveView.swift` — Sheet showing only tags from selected recipes with counts

### Modified Files
- `RecipeListView.swift` — Add "Select" toolbar button, edit mode state, bottom toolbar, sheet presentation
- `RecipeListViewModel.swift` — Add selection state, bulk add/remove tag methods
- `RecipeStore.swift` — Add `bulkAddTags(_:to:)` and `bulkRemoveTags(_:from:)` methods

### Data Flow

1. User enters edit mode → `RecipeListViewModel` tracks `selectedRecipeIDs: Set<UUID>`
2. User taps "Add Tags" → sheet opens with `TagPickerView`
3. User picks tags and taps "Apply" → `RecipeListViewModel.bulkAddTags()` called
4. For each selected recipe: load current tags → add new tags (set union) → build updated `RecipeFile` → `RecipeStore.updateRecipe()`
5. On completion: reset selection, exit edit mode, show toast
6. Search service re-indexes to update tag counts and filter bar

### Bulk Update Logic (RecipeStore)

```
bulkAddTags(_ tags: Set<String>, to recipeIDs: Set<UUID>):
    for each recipeID in recipeIDs:
        find recipe in store
        add tags to recipe.tags (union, skip duplicates)
        serialize to markdown
        write file atomically with security-scoped access
        update store array
    return (successCount, failureCount)

bulkRemoveTags(_ tags: Set<String>, from recipeIDs: Set<UUID>):
    for each recipeID in recipeIDs:
        find recipe in store
        remove tags from recipe.tags (difference)
        serialize to markdown
        write file atomically with security-scoped access
        update store array
    return (successCount, failureCount)
```

## Test Cases

### TC-001: Enter and exit edit mode
1. Open recipe list with recipes loaded
2. Tap "Select"
3. Verify selection circles appear on each row
4. Verify bottom toolbar appears (empty/disabled)
5. Tap "Done"
6. Verify list returns to normal mode

### TC-002: Select recipes
1. Enter edit mode
2. Tap 3 recipes
3. Verify checkmarks appear on tapped recipes
4. Verify bottom toolbar shows "3 Selected"
5. Tap a selected recipe again
6. Verify it deselects and count updates to "2 Selected"

### TC-003: Bulk add tags
1. Have 3 recipes, none tagged "vegetarian"
2. Enter edit mode, select all 3
3. Tap "Add Tags", select "vegetarian", tap "Apply"
4. Verify all 3 recipes now have "vegetarian" tag
5. Verify confirmation toast appears
6. Verify edit mode exits

### TC-004: Bulk add preserves existing tags
1. Have a recipe tagged "italian, dinner"
2. Select it and bulk-add "vegetarian"
3. Verify recipe now has "italian, dinner, vegetarian"

### TC-005: Bulk remove tags
1. Have 3 recipes all tagged "dinner"
2. Enter edit mode, select all 3
3. Tap "Remove Tags", select "dinner", tap "Apply"
4. Verify "dinner" removed from all 3 recipes
5. Verify other tags on each recipe are unchanged

### TC-006: Remove sheet shows only relevant tags
1. Have 2 recipes: one tagged "italian, dinner", one tagged "mexican, dinner"
2. Select both, tap "Remove Tags"
3. Verify sheet shows: "italian (1 of 2)", "dinner (2 of 2)", "mexican (1 of 2)"
4. Verify no other tags appear

### TC-007: Filter then bulk edit
1. Have 10 recipes, 4 tagged "italian"
2. Filter by "italian" tag in the tag filter bar
3. Enter edit mode — only 4 recipes visible
4. Select all 4, bulk-add "dinner"
5. Verify all 4 Italian recipes now also have "dinner"

### TC-008: Search then bulk edit
1. Have recipes including "Pasta Carbonara" and "Pasta Bolognese"
2. Search for "pasta"
3. Enter edit mode, select both results
4. Bulk-add "quick" tag
5. Verify both recipes updated

### TC-009: Partial write failure
1. Select 3 recipes for bulk tag add
2. Simulate one file being inaccessible
3. Verify 2 recipes updated successfully
4. Verify error message shown with failure count
5. Verify edit mode remains active with failed recipe still selected

### TC-010: Empty selection disables actions
1. Enter edit mode
2. Verify "Add Tags" and "Remove Tags" buttons are disabled
3. Select a recipe — verify buttons become enabled
4. Deselect all — verify buttons disable again
