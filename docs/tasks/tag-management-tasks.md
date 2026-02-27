# Task Breakdown: Tag Management

**Feature Spec**: [docs/specs/tag-management.md](../specs/tag-management.md)

---

## Task 1: Create TagVocabulary model
**File:** `src/OpenCookbook/Core/Models/TagVocabulary.swift` (new)
**Complexity:** Low
**Dependencies:** None

Create a static model defining the built-in tag vocabulary:

- Define `TagCategory` enum with cases: `cuisine`, `meal`, `method`, `diet`, `protein`, `custom`
- Each case has a `displayName: String` and `tags: [String]` (except `custom`)
- Define `TagVocabulary` struct with:
  - `static let categories: [TagCategory]` — ordered list of built-in categories
  - `static let allBuiltInTags: Set<String>` — flat set for O(1) lookup
  - `static func isBuiltIn(_ tag: String) -> Bool`
- Populate with the vocabulary from the spec:
  - **Cuisine**: american, chinese, french, greek, indian, italian, japanese, korean, mediterranean, mexican, middle-eastern, thai, vietnamese
  - **Meal**: main, snack, dessert, breakfast, brunch, lunch, dinner
  - **Method**: baked, grilled, fried, slow-cooker, instant-pot, one-pot, no-cook, stir-fry, smoked, sous-vide
  - **Diet**: vegetarian, vegan, gluten-free, dairy-free
  - **Protein**: chicken, beef, pork, lamb, seafood, fish, shrimp, tofu, eggs

**Acceptance Criteria:**
- [ ] All built-in categories and tags defined as static data
- [ ] `isBuiltIn()` correctly identifies built-in vs custom tags
- [ ] Unit tests for vocabulary lookup

---

## Task 2: Add tag frequency calculation with vocabulary awareness to RecipeSearchService
**File:** `src/OpenCookbook/Core/Services/RecipeSearchService.swift` (modify)
**Complexity:** Medium
**Dependencies:** Task 1

Extend the existing `extractTags()` method to be vocabulary-aware:

- Add a new method `computeTagFrequencies(from recipes: [RecipeFile]) -> [TagFrequency]` that:
  - Counts occurrences of each tag across all recipes
  - Includes all built-in vocabulary tags (with 0 count if unused)
  - Collects tags not in the built-in vocabulary as custom tags with their frequency
  - Sorts by usage count descending, then alphabetically for ties
  - Returns a struct with tag name, count, category (built-in category or `.custom`), and `isBuiltIn` flag
- Define `TagFrequency` struct: `name: String`, `count: Int`, `category: TagCategory`
- Add a method `tagFrequencyPrompt(from recipes: [RecipeFile]) -> String` that formats the frequency data for the AI prompt per the spec format

**Acceptance Criteria:**
- [ ] Built-in tags always included (0 count if unused)
- [ ] Custom tags collected from recipes with correct counts
- [ ] Sorted by frequency descending, then alphabetically
- [ ] Prompt string matches spec format
- [ ] Unit tests for frequency computation and prompt generation

---

## Task 3: Update AI prompt with tag vocabulary
**File:** `src/OpenCookbook/Core/Services/AnthropicAPIService.swift` (modify)
**Complexity:** Medium
**Dependencies:** Task 2

Update `recipeExtractionInstructions` to include the tag vocabulary with frequency data:

- Modify the tag extraction instruction (currently line 3: "Tags: On the next line, add italicized tags separated by commas") to include the full vocabulary prompt
- Accept tag frequency data as a parameter (from `RecipeSearchService.tagFrequencyPrompt()`)
- Change `recipeExtractionInstructions` from a static `let` to a static method that accepts tag frequency string
- Update the instruction to say: "Select 2-4 tags from ONLY this list, preferring tags near the top" followed by the frequency-sorted tag list
- Include "Do NOT invent tags outside this list"
- Update all callers to pass the tag frequency data

**Acceptance Criteria:**
- [ ] AI prompt includes full vocabulary sorted by frequency
- [ ] Custom tags included with `[Custom]` prefix
- [ ] AI instructed to pick 2-4 tags only from the list
- [ ] Callers updated to provide frequency data

---

## Task 4: Update RecipeFormViewModel for structured tag selection
**File:** `src/OpenCookbook/Features/RecipeForm/ViewModels/RecipeFormViewModel.swift` (modify)
**Complexity:** Medium
**Dependencies:** Task 1

Replace `tagsText: String` with structured tag selection:

- Replace `tagsText: String` with `selectedTags: Set<String>`
- Add `customTagText: String` for the custom tag input field
- Add method `toggleTag(_ tag: String)` — adds/removes from `selectedTags`
- Add method `addCustomTag()` — validates, normalizes, and adds `customTagText` to `selectedTags`, clears input
- Update `populateFromRecipe()` (line ~598) to populate `selectedTags` from `recipe.tags`
- Update `buildRecipe()` (line ~697) to use `Array(selectedTags)` instead of comma-split parsing
- Add computed property `sortedSelectedTags: [String]` for display order

**Acceptance Criteria:**
- [ ] `tagsText` replaced with `selectedTags: Set<String>`
- [ ] Toggle, add custom tag methods work correctly
- [ ] Recipe population and building use new tag structure
- [ ] Existing form behavior preserved for non-tag fields

---

## Task 5: Create TagPickerView
**File:** `src/OpenCookbook/Features/RecipeForm/Views/TagPickerView.swift` (new)
**Complexity:** High
**Dependencies:** Task 1, Task 4

Build the SwiftUI tag picker component:

- **Search/filter field** at top for quick tag lookup across all categories
- **Selected tags summary** — removable chips showing currently selected tags above the category sections
- **Category sections** — each built-in category as a collapsible section with:
  - Category header (e.g., "Cuisine", "Meal")
  - Tags as tappable chips in a flowing layout (LazyVGrid or custom FlowLayout)
  - Selected tags highlighted with checkmark
  - Usage count badge on each tag
- **Custom section** at the bottom:
  - Existing custom tags as tappable chips (same style as built-in)
  - Text field to add a new custom tag with "Add" button
- Init params: `selectedTags: Binding<Set<String>>`, `tagFrequencies: [TagFrequency]`, `onAddCustomTag: (String) -> Void`

**Acceptance Criteria:**
- [ ] Tags grouped by category as tappable chips
- [ ] Multi-select with checkmark indicators
- [ ] Usage counts displayed as badges
- [ ] Search/filter narrows visible tags
- [ ] Selected tags shown as removable chips above picker
- [ ] Custom section shows non-vocabulary tags
- [ ] Text field for adding new custom tags

---

## Task 6: Replace tag text field with TagPickerView in RecipeFormView
**File:** `src/OpenCookbook/Features/RecipeForm/Views/RecipeFormView.swift` (modify)
**Complexity:** Low
**Dependencies:** Task 4, Task 5

Replace the current tags text field (lines 213-221) with `TagPickerView`:

- Remove the `Section` containing the `TextField("dessert, quick, vegetarian", ...)` for tags
- Add `TagPickerView` bound to `viewModel.selectedTags`
- Pass tag frequency data from `RecipeSearchService` to the picker
- Wire up `onAddCustomTag` to `viewModel.addCustomTag()`
- Ensure the tag picker receives the current recipe library's tag frequencies (inject via environment or pass through)

**Acceptance Criteria:**
- [ ] Text field replaced with TagPickerView in Details tab
- [ ] Tag picker receives frequency data
- [ ] Selected tags persist through tab switches
- [ ] Tags save correctly to recipe

---

## Task 7: Wire tag frequencies into import flow
**File:** `src/OpenCookbook/Features/Import/` (modify as needed)
**Complexity:** Medium
**Dependencies:** Task 2, Task 3

Connect the tag frequency data to the import flow so the AI receives the vocabulary prompt:

- Identify where `AnthropicAPIService` is called during import
- Pass the current recipe library to `RecipeSearchService.tagFrequencyPrompt()`
- Pass the resulting prompt string to the updated `recipeExtractionInstructions` method
- Verify the AI response uses only vocabulary tags

**Acceptance Criteria:**
- [ ] Import flow passes tag frequency data to AI prompt
- [ ] AI suggestions use only vocabulary + custom tags
- [ ] After import, recipe form opens with AI-selected tags pre-selected in picker

---

## Task 8: Add unit tests
**Files:** `src/OpenCookbookTests/TagVocabularyTests.swift` (new), `src/OpenCookbookTests/TagFrequencyTests.swift` (new)
**Complexity:** Medium
**Dependencies:** Tasks 1-4

Write unit tests for the tag management feature:

**TagVocabularyTests:**
- `isBuiltIn` returns true for built-in tags (e.g., "italian", "chicken")
- `isBuiltIn` returns false for custom tags (e.g., "date-night")
- `isBuiltIn` is case-insensitive
- `allBuiltInTags` count matches expected total
- All categories contain expected tags

**TagFrequencyTests:**
- Frequency computation with empty library returns all built-in at 0
- Frequency computation with recipes returns correct counts
- Custom tags collected with correct counts
- Sorting: descending by count, then alphabetical
- Prompt string format matches spec

**RecipeFormViewModel tag tests:**
- `toggleTag` adds/removes from `selectedTags`
- `addCustomTag` validates and adds
- `populateFromRecipe` sets `selectedTags` from recipe tags
- `buildRecipe` includes all selected tags

**Acceptance Criteria:**
- [ ] All test cases listed above pass
- [ ] Tests cover edge cases (empty library, all-custom tags, duplicate tags)

---

## Verification Checklist
1. Build succeeds
2. All tests pass
3. Manual: Open recipe form → tag picker shows categories with chips
4. Manual: Select/deselect tags → checkmarks toggle, selected chips update
5. Manual: Search field filters tags across categories
6. Manual: Add custom tag via text field → appears in Custom section
7. Manual: Import recipe → AI uses only vocabulary tags
8. Manual: Library with varied tag usage → AI prompt shows correct frequency ordering
9. Manual: Edit existing recipe → tags pre-selected in picker
10. Manual: Recipe with custom tags → custom tags appear under Custom category
