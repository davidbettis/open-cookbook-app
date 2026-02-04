# Feature Spec: Add New Recipe

**Priority**: P0 (Must Have)
**Feature ID**: F005

## Description
Create new recipes using a form-based UI that maps to RecipeMD format structure. Save as .md file in selected iCloud folder.

## User Stories

### US-009: Add recipe to collection
**As a** user
**I want** to add a new recipe with a simple form
**So that** I can grow my collection

### US-010: Maintain RecipeMD compatibility
**As a** user
**I want** my new recipes saved in RecipeMD format
**So that** they're compatible with other tools

## Acceptance Criteria

- [ ] Form with fields for: title, description, tags, yields
- [ ] Ingredients entry with amount and name fields (list with add/remove rows)
- [ ] Optional ingredient grouping with group titles
- [ ] Instructions entry (multi-line markdown text)
- [ ] Save button creates valid RecipeMD file in iCloud folder
- [ ] File naming convention (e.g., title-slugified.md)
- [ ] Validation for required fields (at minimum: title, ingredients)
- [ ] Cancel button with unsaved changes confirmation
- [ ] Success feedback when recipe saved

## Technical Requirements

### RecipeMD Serializer
Generate valid markdown following specification:
- H1 heading for title
- Plain paragraphs for description
- Italic text for tags: `*tag1, tag2, tag3*`
- Bold text for yields: `**serves 4, makes 12 cookies**`
- Horizontal rule (---) separator
- List items with optional italic amounts for ingredients
- Remaining content for instructions

### Form Validation
- Title: Required, non-empty, < 200 chars
- Ingredients: At least 1 required
- File name: Slug from title, ensure uniqueness
- Tags: Optional, comma-separated
- Yields: Optional, comma-separated
- Description: Optional
- Instructions: Optional

### File Operations
- Use Swift 6 typed throws for error handling
- Atomic write operation
- Handle file name conflicts (append number: recipe-1.md, recipe-2.md)
- Security-scoped bookmark for iCloud access
- Verify write success before showing success message

### Error Handling
- File write fails → show error alert with retry option
- Invalid characters in filename → sanitize automatically
- Duplicate filename → auto-increment

## UI/UX Requirements

### Form Layout
```
┌─────────────────────────────┐
│ Cancel                 Save │
├─────────────────────────────┤
│ Title *                     │
│ ┌─────────────────────────┐ │
│ │ Recipe Name             │ │
│ └─────────────────────────┘ │
│                             │
│ Description                 │
│ ┌─────────────────────────┐ │
│ │ Brief description...    │ │
│ └─────────────────────────┘ │
│                             │
│ Tags                        │
│ ┌─────────────────────────┐ │
│ │ dessert, quick, easy    │ │
│ └─────────────────────────┘ │
│                             │
│ Yields                      │
│ ┌─────────────────────────┐ │
│ │ serves 4, makes 12      │ │
│ └─────────────────────────┘ │
│                             │
│ Ingredients *               │
│ ┌───────────┬─────────────┐ │
│ │ 2 cups    │ flour       │ │ ← Row 1
│ └───────────┴─────────────┘ │
│ ┌───────────┬─────────────┐ │
│ │ 1 tsp     │ salt        │ │ ← Row 2
│ └───────────┴─────────────┘ │
│ + Add Ingredient            │
│                             │
│ Instructions                │
│ ┌─────────────────────────┐ │
│ │ 1. Preheat oven...      │ │
│ │ 2. Mix ingredients...   │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

### Field Specifications
- **Title**: Single-line text field, required indicator (*)
- **Description**: Multi-line text field (3-4 lines), optional
- **Tags**: Single-line, comma-separated, placeholder: "dessert, quick, vegetarian"
- **Yields**: Single-line, comma-separated, placeholder: "serves 4, makes 12 cookies"
- **Ingredients**: Dynamic list
  - Amount field (left, narrow, optional)
  - Name field (right, wide, required)
  - Delete button (swipe left or minus icon)
  - "+ Add Ingredient" button below list
- **Instructions**: Multi-line text editor, supports markdown

### Form Behavior
- Auto-save draft to prevent data loss (optional for v1.0)
- Show validation errors inline (red text below field)
- Disable Save button until form is valid
- Cancel shows confirmation if changes made

### Ingredient List Management
- Dynamic add/remove rows
- Reorder ingredients (drag handles) - v2.0 feature
- Focus next field after adding ingredient

## Dependencies
- RecipeMD serializer
- File naming/slugification utility
- Form validation framework

## Test Cases

### TC-021: Create simple recipe
1. Tap + button to add recipe
2. Enter title: "Chocolate Cake"
3. Add ingredients: "2 cups flour", "1 cup sugar"
4. Enter instructions: "Mix and bake"
5. Tap Save
6. Verify success message
7. Verify file created in iCloud folder
8. Verify recipe appears in list

### TC-022: Validation - missing title
1. Open add recipe form
2. Leave title empty
3. Add ingredients
4. Tap Save
5. Verify error message: "Title is required"
6. Verify Save button disabled

### TC-023: Validation - no ingredients
1. Open add recipe form
2. Enter title
3. Leave ingredients empty
4. Tap Save
5. Verify error: "At least one ingredient required"

### TC-024: Cancel with changes
1. Start adding recipe
2. Enter some data
3. Tap Cancel
4. Verify confirmation dialog
5. Tap "Discard Changes"
6. Verify returns to list

### TC-025: File name conflict
1. Create recipe titled "Pancakes"
2. Create another recipe titled "Pancakes"
3. Verify second file saved as "pancakes-1.md"
4. Verify both recipes appear in list

### TC-026: RecipeMD format validation
1. Create recipe with all fields
2. Save recipe
3. Open resulting .md file in text editor
4. Verify format matches RecipeMD spec:
   - Title as H1
   - Tags in italics
   - Yields in bold
   - HR separator
   - Ingredients as list with italic amounts
   - Instructions after second HR

### TC-027: Special characters in title
1. Enter title: "Mom's "Special" Cookies!"
2. Save recipe
3. Verify filename sanitized: "moms-special-cookies.md"
4. Verify title preserved exactly in file content

## Open Questions
- Auto-save drafts? (Prevent data loss)
- Ingredient groups in add form? (v1.0: flat list, v2.0: groups)
- Markdown preview for instructions? (v2.0)
- Import from clipboard? (Parse text and pre-fill form)
- Photo upload? (RecipeMD supports markdown images)
