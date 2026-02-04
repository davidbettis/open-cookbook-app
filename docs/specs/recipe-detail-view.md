# Feature Spec: Recipe Detail View

**Priority**: P0 (Must Have)
**Feature ID**: F004

## Description
Shows ingredients, instructions, and metadata (yields, tags) with proper formatting, typography, and structure following RecipeMD spec v2.4.0. Use the library https://github.com/davidbettis/recipemd-swift to parse the RecipeMD format. To render the instructions, use MarkdownUI.  

## User Stories

### US-007: View recipe while cooking
**As a** user
**I want** to view a recipe's full details in a readable format
**So that** I can follow it while cooking

### US-008: View recipe metadata
**As a** user
**I want** to see recipe metadata like yields and tags clearly displayed
**So that** I know if the recipe fits my needs

## Acceptance Criteria

- [ ] Display recipe title prominently
- [ ] Show description paragraph(s) if present
- [ ] Display tags, if present
- [ ] Display yields, if present
- [ ] Display ingredients list with amounts and names in uniform format on single line
- [ ] Display ingredients grouped by headings (if groups present)
- [ ] Display instructions section
- [ ] Support markdown formatting in instructions
- [ ] Navigation to/from list view
- [ ] iPad: Display ingredients and instructions side-by-side (33%/67% split)
- [ ] iPhone: Display ingredients and instructions vertically stacked

## Technical Requirements

### Rationale for MarkdownUI
- RecipeMD is a Markdown-based format (spec v2.4.0)
- MarkdownUI natively handles all RecipeMD constructs
- Eliminates need for custom parser implementation
- Automatic support for links, emphasis, headings, lists, horizontal rules
- Simplifies codebase and reduces maintenance burden
- Provides consistent, tested markdown rendering

### Implementation Details
- Use MarkdownUI library for rendering RecipeMD content
- Minimal parsing for UI-specific elements (navigation title, tags chips)
- Extract title (H1) for navigation bar display
- Optional: Extract tags (italic paragraphs) for chip UI treatment
- ScrollView for long recipes
- @Observable model for recipe detail state
- Custom MarkdownUI theme for recipe-optimized typography

### Platform-Adaptive Layout (iPad vs iPhone)
- Use `@Environment(\.horizontalSizeClass)` to detect device type
- **iPad (regular width)**: Display ingredients and instructions in an `HStack` with:
  - Ingredients pane: 33% of available width (`.frame(width:)` calculated from `GeometryReader`)
  - Instructions pane: 67% of available width
  - Vertical divider between panes
  - Both panes independently scrollable
- **iPhone (compact width)**: Display ingredients and instructions in a `VStack` (current vertical layout)
- Parse recipe content to separate ingredients section from instructions section for split rendering
- Header content (title, description, tags, yields) remains full-width above the split on iPad

### MarkdownUI Integration
- Primary renderer: `Markdown(recipeContent)` displays full RecipeMD
- RecipeMD format is already valid Markdown
- MarkdownUI handles:
  - Headings (H1 title, H2/H3 ingredient groups)
  - Lists (ingredients with italic amounts, instruction steps)
  - Emphasis (italic amounts, bold yields, italic tags)
  - Links (recipe cross-references)
  - Horizontal rules (section separators)

### Optional Light Parsing
Only if enhanced UI needed:
- Title: Extract H1 for navigation bar
- Tags: Extract italic paragraphs before first HR for chip display
- Yields: Parse bold paragraphs for prominent display
- Default: Let MarkdownUI render everything as-is

### Styling with MarkdownUI Theme
```swift
Markdown(recipeContent)
    .markdownTheme(.recipe) // Custom theme
    .markdownTextStyle {
        FontFamily(.system(.default))
        FontSize(17)
    }
```

Custom theme requirements:
- Ingredients: Amount and name displayed in same font style on single line
- Headings: Clear hierarchy (H1: 32pt, H2: 22pt, H3: 20pt)
- Lists: Proper indentation and spacing
- Support Dynamic Type

## UI/UX Requirements

### Layout Structure
```
┌─────────────────────────────┐
│ < Recipe Title  Edit  Share │ ← Navigation bar (title from H1)
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ Markdown(recipeContent) │ │ ← MarkdownUI renders:
│ │                         │ │   - Title (H1)
│ │ # Recipe Title          │ │   - Description paragraphs
│ │                         │ │   - *Tags* (italic)
│ │ Description text...     │ │   - **Yields** (bold)
│ │                         │ │   - HR separator
│ │ *tag1*, *tag2*          │ │   - Ingredient groups (H2/H3)
│ │ **Serves 4**            │ │   - Ingredient lists with
│ │                         │ │     *italic amounts*
│ │ ---                     │ │   - Instructions
│ │                         │ │
│ │ ## Ingredients          │ │
│ │ ### For the Dough       │ │
│ │ - *2 cups* flour        │ │
│ │ - *1 tsp* salt          │ │
│ │                         │ │
│ │ ## Instructions         │ │
│ │ 1. Preheat oven...      │ │
│ │ 2. Mix ingredients...   │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

**Alternative Enhanced Layout** (optional):
- Extract tags and render as colored chips above markdown content
- Extract title for navigation bar only
- Let MarkdownUI render rest of content naturally

### iPad Layout (Regular Width)
On iPad, ingredients and instructions display side-by-side for easier reference while cooking:

```
┌──────────────────────────────────────────────────────────────────────┐
│ < Recipe Title                                      Edit  Share  ••• │
├──────────────────────────────────────────────────────────────────────┤
│ # Recipe Title                                                       │
│ Description text...                                                  │
│ *tag1, tag2*                                                         │
│ **Serves 4**                                                         │
├────────────────┬─────────────────────────────────────────────────────┤
│   INGREDIENTS  │              INSTRUCTIONS                           │
│     (33%)      │                 (67%)                               │
├────────────────┼─────────────────────────────────────────────────────┤
│ ## For Dough   │ 1. Preheat oven to 375°F                            │
│ - *2 cups*     │                                                     │
│   flour        │ 2. Mix dry ingredients in a large bowl              │
│ - *1 tsp*      │                                                     │
│   salt         │ 3. Cream butter and sugars until fluffy             │
│                │                                                     │
│ ## For Filling │ 4. Add eggs one at a time, mixing well              │
│ - *1 cup*      │                                                     │
│   cream cheese │ 5. Gradually add flour mixture                      │
│ - *2 tbsp*     │                                                     │
│   sugar        │ 6. Fold in chocolate chips                          │
│                │                                                     │
│ [scrollable]   │ [scrollable]                                        │
└────────────────┴─────────────────────────────────────────────────────┘
```

- Header section (title, description, tags, yields) spans full width
- Ingredients panel: 33% width, independently scrollable
- Instructions panel: 67% width, independently scrollable
- Vertical divider separates the two panels
- Both panels maintain full MarkdownUI styling

### iPhone Layout (Compact Width)
On iPhone, content displays vertically (existing behavior):
- Full-width scrolling view
- Ingredients section followed by instructions section
- Standard RecipeMD markdown rendering

### Typography (via MarkdownUI Theme)
- H1 (Recipe Title): 32pt, bold
- H2 (Section headers): 22pt, bold
- H3 (Group headings): 20pt, semibold
- Body text: 17pt, regular
- Ingredients: 17pt regular, amount and name in same style
- All text supports Dynamic Type via MarkdownUI

### Styling Customization
Apply custom MarkdownUI theme:
- Ingredients: Uniform styling for amount and name (no italic/monospace differentiation)
- Links: Tappable, blue accent color
- Lists: Proper bullet/number styling
- Spacing: MarkdownUI default spacing with recipe-optimized padding

### Interactive Elements
- Links in markdown → MarkdownUI handles tap gestures
- Recipe cross-references → navigate to linked recipe (v2.0)
- Edit button → open edit mode
- Share button → share recipe file or text
- Back navigation

## Dependencies
- MarkdownUI library (https://github.com/gonzalezreal/swift-markdown-ui)
  - Add via Swift Package Manager
  - Handles all RecipeMD rendering
- Optional: Lightweight regex/string parsing for UI enhancements (title, tags)
- Navigation stack integration

## Test Cases

### TC-015: Display simple recipe
1. Open recipe with title, description, tags, yields, ingredients, instructions
2. Verify MarkdownUI renders all sections correctly
3. Verify markdown formatting (bold, italic, links) renders properly
4. Verify tags (italic text) display correctly (as-is or as chips if enhanced UI)
5. Verify yields (bold text) display clearly
6. Verify ingredients display amount and name in uniform format on single line

### TC-016: Display recipe with ingredient groups
1. Open recipe with multiple ingredient groups
2. Verify group headings displayed
3. Verify ingredients nested under correct groups
4. Verify visual hierarchy clear

### TC-017: Display minimal recipe
1. Open recipe with only title and ingredients (no description, tags, yields)
2. Verify missing sections handled gracefully
3. Verify no empty section headers shown

### TC-018: Long recipe scrolling
1. Open recipe with 20+ ingredients and 15+ instruction steps
2. Scroll through entire recipe
3. Verify smooth scrolling
4. Verify no content clipping

### TC-019: Dynamic Type
1. Open recipe detail
2. Change system text size to largest
3. Verify all text scales appropriately
4. Verify layout doesn't break
5. Verify still readable

### TC-020: Navigation
1. From recipe list, tap recipe
2. Verify detail view opens with smooth transition
3. Tap back button
4. Verify returns to list at same scroll position

### TC-021: iPad split layout
1. Open recipe detail view on iPad
2. Verify header section (title, description, tags, yields) displays full-width
3. Verify ingredients panel displays on left side at 33% width
4. Verify instructions panel displays on right side at 67% width
5. Verify vertical divider visible between panels
6. Scroll ingredients panel independently
7. Scroll instructions panel independently
8. Verify both panels scroll without affecting the other

### TC-022: iPhone vertical layout
1. Open recipe detail view on iPhone
2. Verify ingredients and instructions display vertically stacked
3. Verify no side-by-side split layout
4. Verify single scrollable view for entire recipe content

## Accessibility Requirements
- VoiceOver labels for all sections
- VoiceOver reads ingredients and instructions clearly
- Semantic headers for section navigation
- High contrast mode support
- Dynamic Type support
- iPad split layout: Both panels must be independently navigable with VoiceOver
- iPad split layout: Clear accessibility labels for "Ingredients" and "Instructions" regions

## Open Questions
- Should ingredient amounts be checkbox-able (for shopping)? (v2.0)
- Keep-screen-awake while viewing recipe? (Useful while cooking)
- Serving size adjustment (scale ingredients)? (v2.0)
