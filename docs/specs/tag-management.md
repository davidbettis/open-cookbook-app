# Feature Spec: Tag Management

**Priority**: P1 (Should Have)
**Feature ID**: F003
**Related Specs**: [Add New Recipe](add-new-recipe.md), [Edit Recipe](edit-recipe.md), [Import Recipe](import.md)

## Description
Improve recipe tagging by shipping a curated tag vocabulary built into the app and dynamically biasing AI tag suggestions toward tags the user already uses. Tags that appear more frequently in the user's library are weighted higher in AI prompts, so suggestions naturally converge on what's meaningful to each user.

## User Stories

### US-001: Consistent tagging from AI import
**As a** user importing recipes
**I want** the AI to choose from a known set of tags
**So that** my library stays consistently organized without manual cleanup

### US-002: Frequency-biased suggestions
**As a** user with an established library
**I want** the AI to prefer tags I already use frequently
**So that** new recipes fit naturally into my existing organization

## Design

### Curated Tag Vocabulary

The app ships with a fixed vocabulary organized by category. This vocabulary is built into the app and is not user-customizable. Tags are the only values the AI may assign, and the tag picker in the recipe form draws from this list.

| Category | Tags |
|----------|------|
| **Cuisine** | american, asian, chinese, french, greek, indian, italian, japanese, korean, mediterranean, mexican, middle-eastern, thai, vietnamese |
| **Meal** | appetizer, main, snack, dessert, breakfast, brunch, lunch, dinner |
| **Method** | baked, grilled, fried, slow-cooker, instant-pot, one-pot, no-cook, stir-fry, smoked, sous-vide |
| **Diet** | vegetarian, vegan, gluten-free, dairy-free |
| **Protein** | chicken, beef, pork, lamb, seafood, fish, shrimp, tofu, eggs |

The vocabulary can be updated in future app releases.

In addition to the built-in categories, a **Custom** category allows users to create their own free-form tags. Custom tags are derived at runtime from the user's recipe library — any tag on a recipe that is not in the built-in vocabulary automatically appears under Custom. No separate storage is needed.

### AI Prompt Integration

When the AI imports a recipe, the prompt includes the full tag vocabulary with usage counts from the user's library:

```
Tags: Select 2-4 tags from ONLY this list, preferring tags near the top:
- italian (12 recipes)
- weeknight (9 recipes)
- chicken (8 recipes)
- one-pot (5 recipes)
- vegetarian (4 recipes)
- ...
- sous-vide (0 recipes)
- paleo (0 recipes)
- [Custom] date-night (3 recipes)
- [Custom] kid-friendly (2 recipes)
Do NOT invent tags outside this list.
```

**Weighting rules:**
- Tags are sorted by usage count (descending), then alphabetically for ties
- Tags with 0 uses are listed last (available but not preferred)
- Custom tags from the user's library are included with their frequency counts
- The AI is strictly constrained to this list — no invented tags

### Frequency Calculation

Tag frequency is computed from the loaded recipe library at runtime:
- Count occurrences of each tag across all recipes
- Built-in vocabulary tags are always included (with 0 count if unused)
- Tags not in the built-in vocabulary are collected as custom tags with their frequency
- Both built-in and custom tags are included in the AI prompt, sorted by frequency
- No persistence needed — derived from the recipes themselves

## Acceptance Criteria

- [ ] App ships with a built-in tag vocabulary (categories and tags listed above)
- [ ] AI import prompt includes the vocabulary sorted by usage frequency
- [ ] AI is instructed to pick 2-4 tags from the combined built-in + custom list
- [ ] Recipe form shows tag picker with vocabulary (grouped by category) instead of free-text field
- [ ] Tag picker shows usage counts next to each tag
- [ ] Tags with higher usage counts appear more prominently
- [ ] Tags not in the built-in vocabulary appear under a "Custom" category in the tag picker
- [ ] Users can type new custom tags in the recipe form via a text field in the Custom section
- [ ] Custom tags are included in the AI prompt with their frequency counts

## UI/UX Requirements

### Recipe Form: Tag Picker
Replace the current free-text comma-separated field with a structured picker:
- Show built-in tags grouped by category as tappable chips (multi-select — users can pick multiple tags per category)
- Selected tags highlighted with checkmark
- Usage count displayed as badge on each tag
- Search/filter field at top for quick lookup
- Selected tags shown as removable chips above the picker
- **Custom** category at the bottom shows user's custom tags as tappable chips
- Text field in the Custom section to add a new free-form tag (added to the recipe and appears under Custom going forward)

### Import Flow
No changes to the import UI itself. The AI prompt is updated behind the scenes to include the vocabulary with frequency weighting. After import, the recipe form opens with AI-suggested tags pre-selected in the tag picker, where the user can adjust before saving.

## Technical Requirements

### New Files
- `TagVocabulary.swift` — Model defining the built-in vocabulary (categories and tags as static data)
- `TagPickerView.swift` — SwiftUI tag picker component for the recipe form

### Modified Files
- `AnthropicAPIService.swift` — Update `recipeExtractionInstructions` to include tag vocabulary with frequency data
- `RecipeFormViewModel.swift` — Replace `tagsText: String` with structured tag selection using vocabulary
- `RecipeFormView.swift` — Replace text field with `TagPickerView`
- `RecipeSearchService.swift` — Provide tag frequency data for the AI prompt

### Data Flow
1. App defines vocabulary as static data in `TagVocabulary.swift`
2. User imports recipe → `RecipeSearchService` computes tag frequencies → frequencies + vocabulary passed to `AnthropicAPIService`
3. AI returns recipe with tags from vocabulary → recipe form opens with tags pre-selected in picker
4. User adjusts tags in picker → saves recipe

## Test Cases

### TC-001: AI uses vocabulary in import
1. Add several recipes tagged "italian" and "weeknight"
2. Import a new Italian recipe
3. Verify AI suggests "italian" and "weeknight" (high-frequency tags)
4. Verify AI does not invent tags outside the vocabulary

### TC-002: Tag picker in recipe form
1. Open recipe form (new or edit)
2. Verify tag picker shows categories with tags
3. Tap tags to select/deselect
4. Verify selected tags saved to recipe

### TC-003: Frequency ordering in AI prompt
1. Have a library with varying tag usage counts
2. Import a new recipe
3. Verify AI prompt lists tags in descending frequency order

### TC-004: Custom tags in picker
1. Add a recipe with a custom tag "date-night" (not in built-in vocabulary)
2. Open another recipe in the form
3. Verify "date-night" appears under the Custom category in the tag picker
4. Verify it shows a usage count of 1

### TC-005: Add new custom tag via text field
1. Open recipe form
2. Type "kid-friendly" in the Custom section text field
3. Verify it is added to the recipe's tags
4. Open another recipe — verify "kid-friendly" now appears in the Custom category

### TC-006: Custom tags included in AI prompt
1. Have several recipes with custom tag "date-night"
2. Import a new recipe
3. Verify AI prompt includes "date-night" with its frequency count

### TC-007: Empty library uses vocabulary
1. Fresh install with no recipes
2. Import a recipe
3. Verify AI prompt includes full built-in vocabulary (all at 0 count)
4. Verify AI still selects appropriate tags
