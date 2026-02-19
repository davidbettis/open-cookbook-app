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
- [ ] Pre-populate instruction groups by parsing headings from existing instructions text
- [ ] User can add instruction groups with a title and instruction text
- [ ] User can remove instruction groups
- [ ] User can rename instruction group titles
- [ ] Ungrouped instructions remain in a default section at the top
- [ ] Instruction groups serialize to H2 headings within the freeform instructions string

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

### Instruction Groups
**Tracking**: [GitHub Issue #4](https://github.com/davidbettis/open-cookbook-app/issues/4)

Instruction groups allow users to organize instructions under titled sections (e.g., "Prepare the Dough", "Make the Filling"). Groups are optional — by default, instructions appear as a single freeform text block.

**Not modeled in the Recipe**: Unlike ingredient groups, instruction groups are not a separate field in the data model. Instructions remain a single freeform markdown string. The form UI provides structured editing that reads from and writes to this string.

**Parsing from Freeform Text**:
- When loading instructions into the form, headings (H2, H3, etc.) in the markdown are detected and split into groups
- Text before the first heading becomes the ungrouped/default section
- Each heading starts a new group whose title is the heading text
- A group's content is all text between its heading and the next heading (or end of string)

**Data Model (Form Only)**:
- The form maintains an ordered list of instruction sections
- Each section is either ungrouped (no title) or a named group (has a title)
- The first section is always the ungrouped/default section (may be empty)
- Named groups appear after the ungrouped section
- Groups are one level deep only — headings are not nested

**Adding a Group**:
- "+ Add Instruction Group" button appears below the instructions section
- Tapping it appends a new group with an empty title and an empty text area
- User enters a group title (e.g., "Prepare the Filling")
- Group title is required and validated to be non-empty

**Removing a Group**:
- Each group header has a delete button
- Deleting a group removes the group title and its instructions text
- Confirmation dialog: "Delete group and its instructions?"
- The ungrouped section cannot be deleted

**Editing a Group**:
- Group title is an editable text field in the group header
- Instructions within a group use the same multi-line text editor as ungrouped instructions
- Each group has its own text area

**Pre-population from Existing Recipe**:
- If the instructions contain no headings, all text appears in the ungrouped section (current behavior)
- If the instructions contain headings, each heading and its subsequent text become a separate group in the form
- Text before the first heading populates the ungrouped section

**Serialization**:
- Ungrouped instructions serialize as plain text at the start of the instructions block
- Each named group serializes as an H2 heading followed by its instruction text
- Example output:
  ```markdown
  ---

  Preheat the oven to 350°F.

  ## Make the Dough

  1. Mix flour and salt in a bowl
  2. Add butter and knead until smooth

  ## Prepare the Filling

  1. Combine cream cheese and sugar
  2. Beat until smooth
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

### Modal Presentation
- The edit form is presented as a **full-screen modal** using `.fullScreenCover` (or `.sheet` with `.presentationDetents([.large])` and `.interactiveDismissDisabled()`)
- This gives the form maximum vertical space, reducing scrolling and improving usability on smaller devices
- The modal includes its own `NavigationStack` with Cancel/Save toolbar buttons

### Navigation
- Detail view has "Edit" button in navigation bar
- Tap Edit → transition to full-screen edit form
- Cancel button → return to detail view
- Save button → save changes and return to detail view

### Tabbed Form Layout
The form is divided into **three tabs** using a segmented control (`Picker` with `.segmented` style) pinned below the navigation bar. Each tab is its own independently scrollable page. This eliminates nested scroll conflicts between the outer form and inner text editors.

**Tabs**:
1. **Details** — Title, description, tags, yields
2. **Ingredients** — Ungrouped ingredients and ingredient groups
3. **Instructions** — Ungrouped instructions and instruction groups

The segmented control is **not inside the scroll view** — it is pinned at the top so it remains visible while scrolling within a tab. Tab selection state is preserved when switching between tabs (no data loss).

```
┌─────────────────────────────────────┐
│ Cancel    Edit Recipe         Save  │
├─────────────────────────────────────┤
│ ┌──────────┬─────────────┬────────┐ │
│ │ Details  │ Ingredients │ Instruc│ │ ← Segmented control (pinned)
│ └──────────┴─────────────┴────────┘ │
├─────────────────────────────────────┤
│                                     │
│   (Tab content scrolls here)        │
│                                     │
└─────────────────────────────────────┘
```

### Form Pre-population
- Parse existing recipe into form fields
- Ingredient list shows all existing ingredients with amounts
- Ingredient groups preserved with their titles and ingredient lists
- Tags and yields parsed and displayed in text fields
- Instructions parsed for headings and loaded into instruction group sections
- If instructions contain no headings, all text appears in the ungrouped section

### Details Tab

```
┌─────────────────────────────────────┐
│ Title *                             │
│ ┌─────────────────────────────────┐ │
│ │ Recipe Name                     │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Description                         │
│ ┌─────────────────────────────────┐ │
│ │ Brief description...      [↗]  │ │ ← Fixed height (3-4 lines)
│ │                                 │ │   Tap [↗] to expand full-screen
│ └─────────────────────────────────┘ │
│                                     │
│ Tags                                │
│ ┌─────────────────────────────────┐ │
│ │ dessert, quick, vegetarian      │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Yields                              │
│ ┌─────────────────────────────────┐ │
│ │ serves 4, makes 12 cookies     │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Ingredients Tab

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

### Instructions Tab

```
┌─────────────────────────────────────┐
│ Instructions                        │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Preheat oven to 350°F.   [↗]  │ │ ← Fixed height (4-6 lines)
│ │                                 │ │   Tap [↗] to expand full-screen
│ └─────────────────────────────────┘ │
│                                     │
│ ┌───────────────────────────── ✕ ─┐ │
│ │ Make the Dough                  │ │ ← Group header (editable title + delete)
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ 1. Mix flour and salt     [↗]  │ │ ← Fixed height with expand button
│ │ 2. Add butter and knead        │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌───────────────────────────── ✕ ─┐ │
│ │ Prepare the Filling             │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ 1. Combine cream cheese   [↗]  │ │
│ │ 2. Beat until smooth            │ │
│ └─────────────────────────────────┘ │
│                                     │
│ + Add Instruction Group             │ ← Adds a new named group
└─────────────────────────────────────┘
```

- Each instruction group is visually separated with a header row containing the editable title
- The group delete button (✕) is in the header row
- Each group has its own text editor area with a fixed height and expand button
- "+ Add Instruction Group" appears at the bottom of the instructions section
- The ungrouped section always appears first and cannot be deleted

### Expandable Text Editors
Multi-line text fields (description, all instruction text areas) use a **fixed-height preview with expand-to-fullscreen** pattern:
- Text areas display at a compact fixed height (description: 3-4 lines, instructions: 4-6 lines)
- An expand button (`[↗]` / `arrow.up.left.and.arrow.down.right`) appears in the corner of each text area
- Tapping the expand button opens a **full-screen sheet** dedicated to editing that single text field
- The full-screen editor includes a "Done" button to dismiss and return to the form
- This eliminates nested scrolling — the outer form scrolls, but text areas never independently scroll
- Text content syncs immediately between the compact and full-screen views (shared binding)

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

### TC-052: Add instruction group during edit
1. Open a recipe with plain instructions (no headings) and tap Edit
2. Verify all instructions appear in the ungrouped section
3. Tap "+ Add Instruction Group"
4. Enter group title: "Final Steps"
5. Enter group instructions: "1. Let cool\n2. Serve warm"
6. Tap Save
7. Verify .md file instructions contain original text followed by `## Final Steps` heading and its text

### TC-053: Edit recipe with existing instruction groups
1. Open a recipe whose instructions contain headings (e.g., `## Prep` and `## Cook`)
2. Tap Edit
3. Verify each heading appears as a separate instruction group with its title pre-populated
4. Verify text under each heading appears in the respective group's text area
5. Verify text before the first heading appears in the ungrouped section
6. Modify text in one group
7. Tap Save
8. Verify groups preserved in .md file with correct H2 headings

### TC-054: Remove instruction group during edit
1. Open a recipe with instruction groups and tap Edit
2. Tap the delete button (✕) on an instruction group header
3. Verify confirmation dialog: "Delete group and its instructions?"
4. Confirm deletion
5. Verify the group and its instructions are removed from the form
6. Tap Save
7. Verify the group heading and text no longer appear in the .md file

### TC-055: Rename instruction group
1. Open a recipe with instruction groups and tap Edit
2. Change a group title from "Prep" to "Preparation"
3. Tap Save
4. Verify .md file contains `## Preparation` instead of `## Prep`

### TC-056: Instruction group with empty title validation
1. Open recipe and tap Edit
2. Add a new instruction group
3. Leave the group title empty
4. Enter instructions in the group
5. Tap Save
6. Verify validation error: "Group title is required"

### TC-057: Mixed ungrouped and grouped instructions
1. Open recipe and tap Edit
2. Enter ungrouped instructions: "Preheat oven to 350°F."
3. Add instruction group "Bake" with "1. Place in oven\n2. Bake for 30 min"
4. Tap Save
5. Verify .md file instructions start with ungrouped text, followed by `## Bake` heading and its text

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
- Should users be able to reorder instruction groups via drag-and-drop? (v2.0)
