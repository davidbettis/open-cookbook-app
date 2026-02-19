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
- [ ] User can add ingredient groups with a title and a list of ingredients
- [ ] User can remove ingredient groups
- [ ] User can rename ingredient group titles
- [ ] Ingredients not in any group remain in a default ungrouped section
- [ ] Ingredient groups serialize to RecipeMD H2 headings with their ingredient lists
- [ ] Instructions entry (multi-line markdown text) with optional instruction groups
- [ ] User can add instruction groups with a title and instruction text
- [ ] User can remove instruction groups
- [ ] User can rename instruction group titles
- [ ] Ungrouped instructions remain in a default section at the top
- [ ] Instruction groups serialize to H2 headings within the freeform instructions string
- [ ] When editing, existing headings in instructions are parsed into instruction groups in the form
- [ ] Save button creates valid RecipeMD file in iCloud folder
- [ ] File naming convention (e.g., title-slugified.md)
- [ ] Validation for required fields (at minimum: title, ingredients)
- [ ] Cancel button with unsaved changes confirmation
- [ ] Success feedback when recipe saved
- [ ] User can toggle between structured form and raw markdown editor
- [ ] Raw markdown mode displays the full RecipeMD content in a single text editor
- [ ] Switching from form to markdown serializes current form state into markdown
- [ ] Switching from markdown to form parses markdown back into form fields
- [ ] Parse errors when switching to form mode show an alert and keep the user in markdown mode
- [ ] Save works in both form and markdown modes

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

### Form Validation
- Title: Required, non-empty, < 200 chars
- Ingredients: At least 1 required (across ungrouped + all groups)
- Ingredient group titles: Required, non-empty when a group exists
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

### Modal Presentation
- The add recipe form is presented as a **full-screen modal** using `.fullScreenCover` (or `.sheet` with `.presentationDetents([.large])` and `.interactiveDismissDisabled()`)
- This gives the form maximum vertical space, reducing scrolling and improving usability on smaller devices
- The modal includes its own `NavigationStack` with Cancel/Save toolbar buttons

### Tabbed Form Layout
The form is divided into **three tabs** using a segmented control (`Picker` with `.segmented` style) pinned below the navigation bar. Each tab is its own independently scrollable page. This eliminates nested scroll conflicts between the outer form and inner text editors.

**Tabs**:
1. **Details** — Title, description, tags, yields
2. **Ingredients** — Ungrouped ingredients and ingredient groups
3. **Instructions** — Ungrouped instructions and instruction groups

The segmented control is **not inside the scroll view** — it is pinned at the top so it remains visible while scrolling within a tab. Tab selection state is preserved when switching between tabs (no data loss).

```
┌─────────────────────────────────────┐
│ Cancel    Add Recipe          Save  │
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

### Raw Markdown Mode

```
┌─────────────────────────────────────┐
│ Cancel    Add Recipe     Save  [...] │
├─────────────────────────────────────┤
│                                     │
│ # Chocolate Cake                    │
│                                     │
│ A rich, moist chocolate layer cake. │
│                                     │
│ *dessert, baking*                   │
│                                     │
│ **serves 12**                       │
│                                     │
│ ---                                 │
│                                     │
│ - *2 cups* all-purpose flour        │
│ - *1 cup* sugar                     │
│ - *3/4 cup* cocoa powder            │
│                                     │
│ ---                                 │
│                                     │
│ 1. Preheat oven to 350°F           │
│ 2. Mix dry ingredients              │
│ 3. Add wet ingredients and combine  │
│                                     │
└─────────────────────────────────────┘
```

- The `...` menu item reads "Switch to Form" (to switch back to form mode)
- The entire view is a single scrollable `TextEditor` with the raw RecipeMD content
- The tab bar (Details / Ingredients / Instructions) is hidden
- Syntax is not highlighted (plain text editing)

### Expandable Text Editors
Multi-line text fields (description, all instruction text areas) use a **fixed-height preview with expand-to-fullscreen** pattern:
- Text areas display at a compact fixed height (description: 3-4 lines, instructions: 4-6 lines)
- An expand button (`[↗]` / `arrow.up.left.and.arrow.down.right`) appears in the corner of each text area
- Tapping the expand button opens a **full-screen sheet** dedicated to editing that single text field
- The full-screen editor includes a "Done" button to dismiss and return to the form
- This eliminates nested scrolling — the outer form scrolls, but text areas never independently scroll
- Text content syncs immediately between the compact and full-screen views (shared binding)

### Field Specifications
- **Title**: Single-line text field, required indicator (*)
- **Description**: Multi-line text field, fixed height (3-4 lines) with expand button, optional
- **Tags**: Single-line, comma-separated, placeholder: "dessert, quick, vegetarian"
- **Yields**: Single-line, comma-separated, placeholder: "serves 4, makes 12 cookies"
- **Ingredients**: Dynamic list
  - Amount field (left, narrow, optional)
  - Name field (right, wide, required)
  - Delete button (swipe left or minus icon)
  - "+ Add Ingredient" button below list
- **Ingredient Groups**: Optional named sections
  - Each group has an editable title text field in the header
  - Group delete button (✕) in the header row
  - Each group has its own ingredient list and "+ Add Ingredient" button
  - "+ Add Ingredient Group" button at the bottom of the entire ingredients section
  - Groups are visually separated from ungrouped ingredients
- **Instructions**: Fixed height (4-6 lines) text areas with expand button, structured into instruction groups

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

### Raw Markdown Mode
The form includes a toggle to switch between the structured form UI and a raw markdown editor. This lets power users view and edit the full RecipeMD source directly.

**Toggle Placement**:
- The mode toggle is placed inside a `...` overflow menu (`ellipsis.circle`) in the navigation bar toolbar, keeping it accessible but out of the way for casual users
- Menu item: "Edit as Markdown" (with `chevron.left.forwardslash.chevron.right` icon) when in form mode, "Switch to Form" (with `list.bullet.rectangle` icon) when in markdown mode

**Form → Markdown**:
- When the user switches to markdown mode, the current form state is serialized into a full RecipeMD markdown string using the existing serializer
- The markdown is displayed in a full-height `TextEditor` that replaces the tabbed form
- The tab bar is hidden in markdown mode

**Markdown → Form**:
- When the user switches back to form mode, the raw markdown is parsed using the existing RecipeMD parser
- If parsing succeeds, the form fields are repopulated from the parsed result
- If parsing fails (invalid markdown structure), an alert is shown with the error message and the user stays in markdown mode to fix the issue
- Unsaved edits in the markdown editor are preserved until the user successfully switches or discards

**Saving in Markdown Mode**:
- Save writes the raw markdown string directly to the file (no serialization step needed)
- Validation in markdown mode only checks that the content is non-empty and starts with a valid H1 title line
- The full form-level validation (required title, at least one ingredient) is skipped in markdown mode since the user has direct control over the content

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

### TC-042: Add recipe with ingredient group
1. Tap + button to add recipe
2. Enter title: "Cinnamon Rolls"
3. Add ungrouped ingredients: "3 cups flour", "1 tsp salt"
4. Tap "+ Add Ingredient Group"
5. Enter group title: "For the Filling"
6. Add ingredients: "3/4 cup brown sugar", "2 tbsp cinnamon"
7. Tap Save
8. Verify recipe appears in list
9. Verify .md file contains `## For the Filling` heading followed by its ingredients

### TC-043: Add recipe with multiple ingredient groups
1. Tap + button to add recipe
2. Enter title: "Layer Cake"
3. Add ungrouped ingredients: "2 cups flour"
4. Add group "For the Frosting" with "1 cup butter", "2 cups powdered sugar"
5. Add group "For the Filling" with "1 cup jam"
6. Tap Save
7. Verify .md file has ungrouped list, then `## For the Frosting`, then `## For the Filling`

### TC-044: Remove ingredient group during add
1. Tap + button to add recipe
2. Enter title and ungrouped ingredients
3. Tap "+ Add Ingredient Group"
4. Tap the delete button (✕) on the group header
5. Verify confirmation dialog: "Delete group and its ingredients?"
6. Confirm deletion
7. Verify the group is removed from the form

### TC-045: Ingredient group with empty title validation
1. Tap + button to add recipe
2. Enter title: "Test Recipe"
3. Add an ungrouped ingredient
4. Tap "+ Add Ingredient Group"
5. Leave the group title empty
6. Add ingredients to the group
7. Tap Save
8. Verify validation error: "Group title is required"

### TC-046: Add recipe with ingredients only in groups
1. Tap + button to add recipe
2. Enter title: "Simple Sauce"
3. Leave ungrouped ingredients empty
4. Add group "Base" with "1 can tomatoes", "1 tsp salt"
5. Tap Save
6. Verify recipe saves successfully
7. Verify .md file contains `## Base` heading with its ingredients

### TC-047: Add recipe with instruction groups
1. Tap + button to add recipe
2. Enter title: "Cinnamon Rolls"
3. Add ingredients: "3 cups flour", "1 tsp salt"
4. Enter ungrouped instructions: "Preheat oven to 375°F."
5. Tap "+ Add Instruction Group"
6. Enter group title: "Make the Dough"
7. Enter group instructions: "1. Mix flour and salt\n2. Knead until smooth"
8. Tap Save
9. Verify .md file instructions contain ungrouped text followed by `## Make the Dough` heading and its text

### TC-048: Add recipe with multiple instruction groups
1. Tap + button to add recipe
2. Enter title: "Layer Cake"
3. Add ingredients
4. Add instruction group "Make the Cake" with instructions
5. Add instruction group "Make the Frosting" with instructions
6. Tap Save
7. Verify .md file instructions contain `## Make the Cake` then `## Make the Frosting`, each followed by their text

### TC-049: Remove instruction group during add
1. Tap + button to add recipe
2. Enter title and ingredients
3. Tap "+ Add Instruction Group"
4. Tap the delete button (✕) on the group header
5. Verify confirmation dialog: "Delete group and its instructions?"
6. Confirm deletion
7. Verify the group is removed from the form

### TC-050: Instruction group with empty title validation
1. Tap + button to add recipe
2. Enter title and ingredients
3. Tap "+ Add Instruction Group"
4. Leave the group title empty
5. Enter instructions in the group
6. Tap Save
7. Verify validation error: "Group title is required"

### TC-051: Add recipe with instructions only in groups
1. Tap + button to add recipe
2. Enter title: "Simple Sauce"
3. Add ingredients
4. Leave ungrouped instructions empty
5. Add group "Steps" with "1. Simmer tomatoes\n2. Add seasoning"
6. Tap Save
7. Verify recipe saves successfully
8. Verify .md file instructions contain `## Steps` heading with its text

### TC-058: Switch to raw markdown mode
1. Tap + button to add recipe
2. Enter title: "Test Recipe"
3. Add an ingredient: "1 cup flour"
4. Tap the `...` menu and select "Edit as Markdown"
5. Verify the tabbed form is replaced by a single text editor
6. Verify the text editor contains valid RecipeMD with the title and ingredient
7. Verify the `...` menu now shows "Switch to Form"

### TC-059: Edit in raw markdown mode and save
1. Switch to markdown mode
2. Edit the raw markdown to add a new ingredient line: `- *2 cups* sugar`
3. Tap Save
4. Verify the recipe is saved successfully
5. Verify the saved .md file contains the added ingredient

### TC-060: Switch from markdown back to form mode
1. Enter a complete recipe in markdown mode
2. Tap the `...` menu and select "Switch to Form"
3. Verify the form repopulates with parsed data (title, ingredients, instructions in correct tabs)
4. Verify tab bar reappears

### TC-061: Invalid markdown prevents switch to form
1. Switch to markdown mode
2. Delete the title line (remove the `# ...` heading)
3. Tap the Form toggle button
4. Verify an alert is shown indicating the markdown could not be parsed
5. Verify the user stays in markdown mode with their text preserved

### TC-062: Round-trip form → markdown → form preserves data
1. Enter title: "Round Trip Test", description, tags, ingredients, and instructions in form mode
2. Switch to markdown mode
3. Switch back to form mode
4. Verify all fields (title, description, tags, yields, ingredients, instructions) match the original values

## Open Questions
- Auto-save drafts? (Prevent data loss)
- Import from clipboard? (Parse text and pre-fill form)
- Photo upload? (RecipeMD supports markdown images)
- Should users be able to reorder ingredient groups via drag-and-drop? (v2.0)
- Should users be able to move ingredients between groups? (v2.0)
- Should users be able to reorder instruction groups via drag-and-drop? (v2.0)
