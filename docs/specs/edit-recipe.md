# Feature Spec: Edit Existing Recipe

**Priority**: P0 (Must Have)
**Feature ID**: F006

## Description
Edit all aspects of an existing recipe, preserving RecipeMD format. Changes save back to the original .md file in iCloud.

## User Stories

### US-011: Update recipe
**As a** user
**I want** to edit my recipes when I refine them
**So that** my collection stays up to date

### US-012: Preserve format compatibility
**As a** user
**I want** edits to preserve the RecipeMD format
**So that** my files remain portable

## Acceptance Criteria

- [ ] Edit button on recipe detail view opens edit mode
- [ ] Pre-populate form with existing recipe data (title, tags, yields, ingredients, instructions)
- [ ] Pre-populate ingredient groups with their titles and ingredients when recipe has groups
- [ ] Save updates original file (overwrite)
- [ ] Preserve RecipeMD structure and formatting
- [ ] Handle file write conflicts gracefully
- [ ] Unsaved changes warning if user navigates away
- [ ] User can add ingredient groups with a title and a list of ingredients
- [ ] User can remove ingredient groups
- [ ] User can rename ingredient group titles
- [ ] Ingredients not in any group remain in a default ungrouped section
- [ ] Ingredient groups serialize to RecipeMD H2 headings with their ingredient lists

## Technical Requirements

### Implementation Details
- Reuse Add Recipe form UI with edit mode
- Pre-fill all form fields from parsed recipe
- File overwrite with atomic write operation
- Preserve RecipeMD markdown structure on save
- Optimistic UI updates with rollback on error

### Edit Mode Behavior
- Same form as Add Recipe
- All fields pre-populated from existing recipe
- Title change → option to rename file or keep original filename
- Save button text: "Save Changes" instead of "Save"

### Ingredient Groups
Ingredient groups allow users to organize ingredients under titled sections (e.g., "For the Dough", "For the Filling"). Groups are optional — by default, ingredients appear in a flat ungrouped list.

**Data Model**:
- The form maintains an ordered list of ingredient sections
- Each section is either ungrouped (no title) or a named group (has a title)
- The first section is always the ungrouped/default section
- Named groups appear after the ungrouped section
- Groups are one level deep only — no nested groups

**Adding a Group**:
- "+ Add Ingredient Group" button appears below the ingredients section
- Tapping it appends a new group with an empty title and one empty ingredient row
- User enters a group title (e.g., "For the Frosting")
- Group title is required and validated to be non-empty

**Removing a Group**:
- Each group header has a delete button
- Deleting a group removes the group title and all its ingredients
- Confirmation dialog: "Delete group and its ingredients?"
- The ungrouped section cannot be deleted

**Editing a Group**:
- Group title is an editable text field in the group header
- Ingredients within a group use the same add/remove/edit behavior as ungrouped ingredients
- Each group has its own "+ Add Ingredient" button

**Pre-population from Existing Recipe**:
- If the recipe has a single unnamed `IngredientGroup`, ingredients appear in the ungrouped section (flat list, current behavior)
- If the recipe has multiple `IngredientGroup`s, or groups with titles, they are preserved as separate sections in the form
- Group titles map to RecipeMD H2 headings

**Serialization**:
- Ungrouped ingredients serialize as a plain list after the first `---`
- Each named group serializes as an H2 heading followed by its ingredient list
- Example output:
  ```markdown
  ---

  - *2 cups* all-purpose flour
  - *1 tsp* salt

  ## For the Filling

  - *1 cup* cream cheese
  - *1/2 cup* sugar

  ---
  ```

### File Operations
- Atomic write (write to temp file, then replace)
- Backup original file before overwrite (optional for v1.0)
- Handle case where file was modified externally (show conflict warning)
- Update modification date after save

### Error Handling
- File write fails → show error, don't modify in-memory recipe
- File deleted externally → show error, offer to save as new file
- File modified externally → show conflict dialog with options:
  - Overwrite external changes
  - Discard my changes
  - Save as new file

## UI/UX Requirements

### Navigation
- Detail view has "Edit" button in navigation bar
- Tap Edit → transition to edit form (slide or modal)
- Cancel button → return to detail view
- Save button → save changes and return to detail view

### Form Pre-population
- Parse existing recipe into form fields
- Ingredient list shows all existing ingredients with amounts
- Ingredient groups preserved with their titles and ingredient lists
- Tags and yields parsed and displayed in text fields
- Instructions loaded into text editor

### Ingredient Groups UI

```
┌─────────────────────────────────────┐
│ Ingredients *                       │
│                                     │
│ ┌───────────┬─────────────┐ ⊖      │
│ │ 2 cups    │ flour       │        │ ← Ungrouped ingredients
│ └───────────┴─────────────┘        │
│ ┌───────────┬─────────────┐ ⊖      │
│ │ 1 tsp     │ salt        │        │
│ └───────────┴─────────────┘        │
│ + Add Ingredient                    │
│                                     │
│ ┌───────────────────────────── ✕ ─┐ │
│ │ For the Filling              │ │ ← Group header (editable title + delete)
│ └─────────────────────────────────┘ │
│ ┌───────────┬─────────────┐ ⊖      │
│ │ 1 cup     │ cream cheese│        │ ← Group ingredients
│ └───────────┴─────────────┘        │
│ ┌───────────┬─────────────┐ ⊖      │
│ │ 1/2 cup   │ sugar       │        │
│ └───────────┴─────────────┘        │
│ + Add Ingredient                    │ ← Per-group add button
│                                     │
│ + Add Ingredient Group              │ ← Adds a new named group
└─────────────────────────────────────┘
```

- Each group is visually separated with a header row containing the editable title
- The group delete button (✕) is in the header row
- Each group has its own "+ Add Ingredient" button
- "+ Add Ingredient Group" appears at the bottom of the entire ingredients section

### Visual Feedback
- Show loading indicator while parsing
- Show saving indicator while writing file
- Success toast: "Recipe updated"
- Error alert if save fails

## Dependencies
- RecipeMD parser (read existing recipe)
- RecipeMD serializer (write updated recipe)
- Add Recipe form component (reused)

## Test Cases

### TC-028: Edit recipe title
1. Open recipe detail view
2. Tap Edit button
3. Verify form pre-populated with existing data
4. Change title from "Pancakes" to "Fluffy Pancakes"
5. Tap Save
6. Verify recipe updated in list
7. Verify file content updated

### TC-029: Edit ingredients
1. Open recipe and tap Edit
2. Modify ingredient: "2 cups flour" → "3 cups flour"
3. Add new ingredient: "1 tsp vanilla"
4. Remove ingredient: delete "salt"
5. Save changes
6. Verify changes reflected in detail view
7. Verify .md file updated correctly

### TC-030: Edit with no changes
1. Open recipe and tap Edit
2. Don't modify anything
3. Tap Save
4. Verify no error
5. Verify file modification date updated (or not? TBD)

### TC-031: Cancel with unsaved changes
1. Open recipe and tap Edit
2. Modify title
3. Tap Cancel
4. Verify confirmation: "Discard changes?"
5. Tap Discard
6. Verify returned to detail view
7. Verify changes not saved

### TC-032: Save with validation error
1. Open recipe and tap Edit
2. Delete title (make empty)
3. Tap Save
4. Verify validation error shown
5. Re-enter title
6. Save successfully

### TC-033: File modified externally
1. Open recipe in OpenCookbook
2. Tap Edit
3. Externally edit same file (via Files app or another app)
4. Make changes in OpenCookbook
5. Tap Save
6. Verify conflict warning shown
7. Choose "Overwrite"
8. Verify app's changes saved

### TC-034: File deleted externally
1. Open recipe and tap Edit
2. Delete file externally (via Files app)
3. Make changes in form
4. Tap Save
5. Verify error: "Original file not found"
6. Verify option to save as new file

### TC-035: Atomic write verification
1. Edit large recipe
2. During save, force quit app (simulated crash)
3. Relaunch app
4. Verify file is either old version or new version (not corrupted)

### TC-036: Add ingredient group during edit
1. Open a recipe with a flat ingredient list and tap Edit
2. Tap "+ Add Ingredient Group"
3. Enter group title: "For the Sauce"
4. Add ingredients: "1 cup" / "tomato sauce", "1 tsp" / "oregano"
5. Tap Save
6. Verify detail view shows "For the Sauce" group heading
7. Verify .md file contains `## For the Sauce` heading followed by its ingredients

### TC-037: Edit recipe with existing ingredient groups
1. Open a recipe that has ingredient groups (e.g., "For the Dough", "For the Filling")
2. Tap Edit
3. Verify each group appears as a separate section with its title pre-populated
4. Verify ingredients appear under their respective group
5. Modify an ingredient in one group
6. Tap Save
7. Verify groups preserved in .md file with correct H2 headings

### TC-038: Remove ingredient group during edit
1. Open a recipe with ingredient groups and tap Edit
2. Tap the delete button (✕) on a group header
3. Verify confirmation dialog: "Delete group and its ingredients?"
4. Confirm deletion
5. Verify the group and its ingredients are removed from the form
6. Tap Save
7. Verify the group no longer appears in the .md file

### TC-039: Rename ingredient group
1. Open a recipe with ingredient groups and tap Edit
2. Change a group title from "For the Dough" to "Dough Ingredients"
3. Tap Save
4. Verify .md file contains `## Dough Ingredients` instead of `## For the Dough`

### TC-040: Ingredient group with empty title validation
1. Open recipe and tap Edit
2. Add a new ingredient group
3. Leave the group title empty
4. Add ingredients to the group
5. Tap Save
6. Verify validation error: "Group title is required"

### TC-041: Mixed ungrouped and grouped ingredients
1. Open recipe and tap Edit
2. Add ungrouped ingredients: "2 cups flour", "1 tsp salt"
3. Add a group "For the Glaze" with "1 cup powdered sugar"
4. Tap Save
5. Verify .md file has ungrouped ingredients as a plain list, followed by `## For the Glaze` with its ingredients

## Accessibility Requirements
- Same as Add Recipe form
- Announce "Editing [Recipe Name]" when edit mode opens
- VoiceOver support for all form fields

## Open Questions
- Should title change rename the file? Keep original filename
- Show edit history/versions? (v2.0 with git integration)
- Allow editing raw markdown? (Advanced mode for power users)
- Should users be able to reorder ingredient groups via drag-and-drop? (v2.0)
- Should users be able to move ingredients between groups? (v2.0)
