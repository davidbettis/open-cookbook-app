# Task Breakdown: Recipe Detail View (F004)

**Spec**: [docs/specs/recipe-detail-view.md](../specs/recipe-detail-view.md)
**Priority**: P0 (Must Have)

---

## Task 1: Add MarkdownUI Package Dependency

**Complexity**: Low
**Dependencies**: None

### Description
Add the MarkdownUI Swift package to the project for rendering RecipeMD content.

### Implementation Steps
1. Add MarkdownUI package via Swift Package Manager
   - URL: `https://github.com/gonzalezreal/swift-markdown-ui`
   - Version: Latest stable (5.x)
2. Verify package resolves and builds successfully
3. Import MarkdownUI in a test file to confirm integration

### Acceptance Criteria
- [ ] MarkdownUI package added to project
- [ ] Project builds without errors
- [ ] Package visible in Xcode's Package Dependencies

---

## Task 2: Create Custom MarkdownUI Theme

**Complexity**: Medium
**Dependencies**: Task 1

### Description
Create a custom MarkdownUI theme optimized for recipe display with proper typography hierarchy and ingredient amount styling.

### Implementation Steps
1. Create `Core/Extensions/MarkdownTheme+Recipe.swift`
2. Define custom theme with:
   - H1: 32pt bold (recipe title)
   - H2: 22pt bold (section headers)
   - H3: 20pt semibold (ingredient groups)
   - Body: 17pt regular
   - Ingredients: Uniform styling for amount and name
3. Configure list styling with proper indentation
4. Ensure Dynamic Type support via relative font sizing
5. Set appropriate spacing between sections

### Acceptance Criteria
- [ ] Custom `.recipe` theme extension created
- [ ] Typography hierarchy matches spec
- [ ] Amount and name use uniform font styling
- [ ] Dynamic Type scales all text appropriately

---

## Task 3: Create RecipeDetailView

**Complexity**: Medium
**Dependencies**: Task 1, Task 2

### Description
Create the main RecipeDetailView that displays full recipe content using MarkdownUI.

### Implementation Steps
1. Create `Features/RecipeDetail/Views/RecipeDetailView.swift`
2. Accept `Recipe` model as input
3. Implement ScrollView containing Markdown view
4. Apply custom recipe theme
5. Extract H1 title for navigation bar display
6. Add navigation bar with title and back button
7. Handle recipes with missing optional sections gracefully

### Acceptance Criteria
- [ ] View displays full RecipeMD content
- [ ] Recipe title shown in navigation bar
- [ ] ScrollView enables viewing long recipes
- [ ] Missing sections (description, tags, yields) don't break layout
- [ ] Markdown formatting renders correctly (bold, italic, links, lists)

---

## Task 4: Add Navigation from Recipe List to Detail

**Complexity**: Low
**Dependencies**: Task 3

### Description
Implement navigation from RecipeListView to RecipeDetailView using NavigationStack.

### Implementation Steps
1. Add `Route.recipeDetail(Recipe)` case to navigation router (if exists) or create one
2. Update RecipeCard to navigate on tap
3. Configure `.navigationDestination(for:)` in parent view
4. Ensure back navigation returns to list at same scroll position
5. Add smooth transition animation

### Acceptance Criteria
- [ ] Tapping recipe card opens detail view
- [ ] Back button returns to list view
- [ ] Scroll position preserved on return
- [ ] Transition animation smooth

---

## Task 5: Add Edit and Share Buttons

**Complexity**: Low
**Dependencies**: Task 3

### Description
Add Edit and Share toolbar buttons to the recipe detail navigation bar.

### Implementation Steps
1. Add toolbar with Edit and Share buttons
2. Edit button: Navigate to edit view (placeholder for now, will implement in F006)
3. Share button: Use ShareLink to share recipe file or text content
4. Position buttons appropriately in navigation bar

### Acceptance Criteria
- [ ] Edit button visible in toolbar
- [ ] Share button visible in toolbar
- [ ] Share presents system share sheet with recipe content
- [ ] Edit button ready for future edit view integration

---

## Task 6: Implement Accessibility Support

**Complexity**: Medium
**Dependencies**: Task 3

### Description
Ensure RecipeDetailView is fully accessible with VoiceOver and Dynamic Type support.

### Implementation Steps
1. Add semantic headers for section navigation (`.accessibilityAddTraits(.isHeader)`)
2. Verify VoiceOver reads ingredients and instructions clearly
3. Test with largest Dynamic Type setting
4. Ensure high contrast mode support via system colors
5. Add accessibility labels where MarkdownUI defaults insufficient

### Acceptance Criteria
- [ ] VoiceOver navigates sections via headers
- [ ] All content readable by VoiceOver
- [ ] Layout doesn't break at largest text size
- [ ] Contrast ratios meet WCAG 2.1 AA

---

## Task 7: Write Unit Tests for RecipeDetailView

**Complexity**: Medium
**Dependencies**: Task 3

### Description
Create unit tests covering recipe detail display scenarios.

### Implementation Steps
1. Create `OpenCookbookTests/RecipeDetailViewTests.swift`
2. Test: Simple recipe displays all sections (TC-015)
3. Test: Recipe with ingredient groups shows hierarchy (TC-016)
4. Test: Minimal recipe (title + ingredients only) handles gracefully (TC-017)
5. Test: Title extraction for navigation bar works correctly
6. Use Swift Testing framework (@Test, #expect)

### Acceptance Criteria
- [ ] Tests for simple recipe display
- [ ] Tests for ingredient groups
- [ ] Tests for minimal recipe
- [ ] Tests for title extraction
- [ ] All tests pass

---

## Task 8: Create RecipeDetailViewModel (Optional Enhancement)

**Complexity**: Low
**Dependencies**: Task 3

### Description
Extract view logic into an @Observable ViewModel if complexity warrants.

### Implementation Steps
1. Evaluate if ViewModel needed (may be simple enough without)
2. If needed, create `Features/RecipeDetail/ViewModels/RecipeDetailViewModel.swift`
3. Move title extraction logic to ViewModel
4. Move any tag/yield parsing for enhanced UI to ViewModel
5. Keep view focused on presentation

### Acceptance Criteria
- [ ] View logic appropriately separated (if ViewModel created)
- [ ] View remains clean and focused on UI
- [ ] ViewModel is @Observable and testable

---

## Summary

| Task | Complexity | Dependencies | Est. LOC |
|------|------------|--------------|----------|
| 1. Add MarkdownUI Package | Low | None | ~5 |
| 2. Custom MarkdownUI Theme | Medium | Task 1 | ~50 |
| 3. RecipeDetailView | Medium | Tasks 1, 2 | ~80 |
| 4. Navigation Integration | Low | Task 3 | ~30 |
| 5. Edit/Share Buttons | Low | Task 3 | ~25 |
| 6. Accessibility | Medium | Task 3 | ~20 |
| 7. Unit Tests | Medium | Task 3 | ~100 |
| 8. ViewModel (Optional) | Low | Task 3 | ~40 |

**Recommended Implementation Order**: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

**Critical Path**: Tasks 1-4 are required for basic functionality.

---

# iPad Split Layout Enhancement

The following tasks implement the iPad-specific split layout where ingredients (25%) and instructions (75%) display side-by-side.

**Key Insight**: The RecipeMD library already parses recipes into structured data:
- `recipe.ingredientGroups: [IngredientGroup]` - parsed ingredient groups with amounts
- `recipe.instructions: String?` - raw markdown for instructions section
- `recipe.title`, `recipe.description`, `recipe.tags`, `recipe.yield` - header metadata

This eliminates the need for custom markdown section parsing. We can render ingredients from structured data and instructions via MarkdownUI.

---

## Task 9: Create IngredientsListView Component

**Complexity**: Medium
**Dependencies**: Task 3 (RecipeDetailView exists)

### Description
Create a SwiftUI view that renders `[IngredientGroup]` from the RecipeMD parser as a styled ingredients list, matching the MarkdownUI theme.

### Implementation Steps
1. Create `Features/RecipeDetail/Views/IngredientsListView.swift`
2. Accept `ingredientGroups: [IngredientGroup]` as input
3. Render each ingredient group:
   - Group title as H2/H3 heading (if group has title)
   - Ingredients as styled list items
   - Amount and ingredient name on single line with uniform styling
4. Handle nested groups via recursion (`IngredientGroup.subgroups`)
5. Match typography from `.recipe` MarkdownUI theme:
   - Amount and name: Same font style (body text)
   - Group headings: 20pt semibold
   - Ingredient text: 17pt regular
6. Support Dynamic Type scaling
7. Handle empty groups gracefully

### Code Reference
```swift
// RecipeMD types available:
struct IngredientGroup {
    var title: String?
    var ingredients: [Ingredient]
    var subgroups: [IngredientGroup]
    var allIngredients: [Ingredient]  // flattened
}

struct Ingredient {
    var amount: String?  // e.g., "2 cups"
    var name: String     // e.g., "all-purpose flour"
}
```

### Acceptance Criteria
- [ ] Renders all ingredient groups with proper hierarchy
- [ ] Amount and name display in uniform format on single line
- [ ] Group titles display as section headers
- [ ] Handles nested subgroups correctly
- [ ] Dynamic Type scales appropriately
- [ ] Empty groups/ingredients handled gracefully

---

## Task 10: Create RecipeDetailSplitContent View

**Complexity**: Medium
**Dependencies**: Task 9

### Description
Create a view component that displays ingredients and instructions side-by-side with 33%/67% split for iPad, using RecipeMD parsed data.

### Implementation Steps
1. Create `Features/RecipeDetail/Views/RecipeDetailSplitContent.swift`
2. Accept inputs from RecipeMD parser:
   - `ingredientGroups: [IngredientGroup]` (from `recipe.ingredientGroups`)
   - `instructions: String?` (from `recipe.instructions`)
3. Use `GeometryReader` to calculate panel widths:
   - Ingredients: 33% of available width
   - Instructions: 67% of available width
4. Create `HStack` layout:
   ```swift
   HStack(spacing: 0) {
       // Left panel: Ingredients
       ScrollView {
           IngredientsListView(ingredientGroups: ingredientGroups)
       }
       .frame(width: geometry.size.width * 0.33)

       Divider()

       // Right panel: Instructions
       ScrollView {
           Markdown(instructions ?? "")
               .markdownTheme(.recipe)
       }
       .frame(width: geometry.size.width * 0.67)
   }
   ```
5. Add section headers above each panel ("Ingredients" / "Instructions")
6. Ensure independent scrolling for each panel

### Acceptance Criteria
- [ ] Split layout displays correctly with 33%/67% proportions
- [ ] Vertical divider visible between panels
- [ ] Each panel scrolls independently
- [ ] Section headers clearly label each panel
- [ ] Ingredients rendered via IngredientsListView
- [ ] Instructions rendered via MarkdownUI

---

## Task 11: Create RecipeHeaderView Component

**Complexity**: Low
**Dependencies**: None

### Description
Create a reusable view for recipe header content (title, description, tags, yields) using RecipeMD parsed data.

### Implementation Steps
1. Create `Features/RecipeDetail/Views/RecipeHeaderView.swift`
2. Accept inputs from RecipeMD parser:
   - `title: String`
   - `description: String?`
   - `tags: [String]`
   - `yield: Yield`
3. Render header elements:
   - Title: Large, bold heading (32pt)
   - Description: Body text paragraphs
   - Tags: Styled chips/pills or italic text
   - Yields: Bold text display
4. Match existing MarkdownUI theme styling
5. Handle missing optional fields gracefully

### Acceptance Criteria
- [ ] Title displays prominently
- [ ] Description paragraphs render correctly
- [ ] Tags display as styled elements
- [ ] Yields display clearly
- [ ] Missing sections don't break layout

---

## Task 12: Create Platform-Adaptive RecipeDetailContent View

**Complexity**: Medium
**Dependencies**: Tasks 9, 10, 11

### Description
Create a container view that switches between split (iPad) and stacked (iPhone) layouts based on horizontal size class, using RecipeMD parsed data.

### Implementation Steps
1. Create `Features/RecipeDetail/Views/RecipeDetailContent.swift`
2. Accept `RecipeFile` as input (provides all parsed data)
3. Use `@Environment(\.horizontalSizeClass)` to detect device type
4. Implement conditional layout:
   ```swift
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass

   var body: some View {
       if horizontalSizeClass == .regular {
           // iPad: Header + Split content
           VStack(spacing: 0) {
               RecipeHeaderView(
                   title: recipeFile.title,
                   description: recipeFile.description,
                   tags: recipeFile.tags,
                   yield: recipeFile.yield
               )
               Divider()
               RecipeDetailSplitContent(
                   ingredientGroups: recipeFile.ingredientGroups,
                   instructions: recipeFile.instructions
               )
           }
       } else {
           // iPhone: Full markdown in ScrollView (current behavior)
           Markdown(markdownContent)
               .markdownTheme(.recipe)
       }
   }
   ```
5. For iPhone, keep current raw markdown rendering (simpler, preserves formatting)
6. Header section always displays full-width on iPad

### Acceptance Criteria
- [ ] iPad shows split layout with full-width header
- [ ] iPhone shows current vertical markdown layout
- [ ] Transition works when device rotates or window resizes
- [ ] No layout issues on any screen size

---

## Task 13: Update RecipeDetailView for Split Layout

**Complexity**: Medium
**Dependencies**: Task 12

### Description
Integrate the platform-adaptive content view into RecipeDetailView.

### Implementation Steps
1. Update `RecipeDetailView` to use `RecipeDetailContent`
2. Pass `RecipeFile` (already available as `recipeFile` property)
3. Keep `markdownContent` for:
   - iPhone layout (full markdown rendering)
   - Share functionality
4. Update body to use new component:
   ```swift
   var body: some View {
       ScrollView {  // Only needed for iPhone; iPad handles own scrolling
           if let content = markdownContent {
               RecipeDetailContent(
                   recipeFile: recipeFile,
                   markdownContent: content
               )
           } else if let error = loadError {
               errorView(error)
           } else {
               loadingView
           }
       }
   }
   ```
5. Handle recipes with missing ingredients/instructions sections
6. Preserve all existing functionality (edit, delete, share)

### Acceptance Criteria
- [ ] RecipeDetailView uses new platform-adaptive layout
- [ ] iPad displays split ingredients/instructions
- [ ] iPhone displays current vertical layout
- [ ] Share functionality still works with full content
- [ ] Edit/Delete functionality preserved
- [ ] Loading and error states preserved

---

## Task 14: Add Accessibility for Split Layout

**Complexity**: Low
**Dependencies**: Task 13

### Description
Ensure the split layout is fully accessible with VoiceOver.

### Implementation Steps
1. Add accessibility to `IngredientsListView`:
   - Each ingredient readable with amount + name
   - Group titles announced as headers
2. Add accessibility to `RecipeDetailSplitContent`:
   - `.accessibilityElement(children: .contain)` on each panel
   - `.accessibilityLabel("Ingredients")` on left panel container
   - `.accessibilityLabel("Instructions")` on right panel container
3. Add accessibility to `RecipeHeaderView`:
   - `.accessibilityAddTraits(.isHeader)` on title
   - Tags read as "Tags: dessert, baking, quick"
4. Test VoiceOver navigation between panels
5. Ensure panel contents remain fully readable

### Acceptance Criteria
- [ ] VoiceOver identifies "Ingredients" and "Instructions" regions
- [ ] Users can navigate between panels with VoiceOver
- [ ] Section headers announced as headers
- [ ] All content within panels readable
- [ ] Ingredients read as "[amount] [name]"

---

## Task 15: Write Tests for iPad Split Layout

**Complexity**: Medium
**Dependencies**: Task 13

### Description
Add unit tests for the iPad split layout functionality.

### Implementation Steps
1. Create `OpenCookbookTests/IngredientsListViewTests.swift`:
   - Test rendering single group
   - Test rendering multiple groups
   - Test nested subgroups
   - Test empty groups
   - Test ingredients with/without amounts
2. Update `RecipeDetailViewTests.swift`:
   - Test split layout on iPad (mock horizontalSizeClass = .regular)
   - Test vertical layout on iPhone (mock horizontalSizeClass = .compact)
   - Test header rendering with all fields
   - Test header rendering with missing optional fields
3. Use Swift Testing framework (@Test, #expect)

### Acceptance Criteria
- [ ] IngredientsListView tests pass
- [ ] Layout switching tests pass
- [ ] Header component tests pass
- [ ] TC-021 and TC-022 from spec covered

---

## Updated Summary

| Task | Complexity | Dependencies | Status |
|------|------------|--------------|--------|
| 1. Add MarkdownUI Package | Low | None | ✅ Complete |
| 2. Custom MarkdownUI Theme | Medium | Task 1 | ✅ Complete |
| 3. RecipeDetailView | Medium | Tasks 1, 2 | ✅ Complete |
| 4. Navigation Integration | Low | Task 3 | ✅ Complete |
| 5. Edit/Share Buttons | Low | Task 3 | ✅ Complete |
| 6. Accessibility | Medium | Task 3 | ✅ Complete |
| 7. Unit Tests | Medium | Task 3 | ✅ Complete |
| 8. ViewModel (Optional) | Low | Task 3 | Skipped |
| **9. IngredientsListView** | Medium | Task 3 | ✅ Complete |
| **10. Split Content View** | Medium | Task 9 | ✅ Complete |
| **11. RecipeHeaderView** | Low | None | ✅ Complete |
| **12. Platform-Adaptive Container** | Medium | Tasks 9, 10, 11 | ✅ Complete |
| **13. Update RecipeDetailView** | Medium | Task 12 | ✅ Complete |
| **14. Split Accessibility** | Low | Task 13 | ✅ Complete |
| **15. Split Layout Tests** | Medium | Task 13 | ✅ Complete |

**iPad Split Layout Implementation Order**: 9 + 11 (parallel) → 10 → 12 → 13 → 14 → 15

**Critical Path for Split Layout**: Tasks 9, 10, 12, 13 are required for the feature.

**Note**: Tasks 9 and 11 can be developed in parallel as they have no dependencies on each other.

### Removed: String+RecipeSections Extension

The existing `String+RecipeSections.swift` extension that manually parses markdown sections is **no longer needed** for the iPad layout. The RecipeMD library provides structured access to all recipe components. Consider removing this extension if not used elsewhere to reduce code maintenance.
