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
- [ ] Save updates original file (overwrite)
- [ ] Preserve RecipeMD structure and formatting
- [ ] Handle file write conflicts gracefully
- [ ] Unsaved changes warning if user navigates away

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
- Tags and yields parsed and displayed in text fields
- Instructions loaded into text editor

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

## Accessibility Requirements
- Same as Add Recipe form
- Announce "Editing [Recipe Name]" when edit mode opens
- VoiceOver support for all form fields

## Open Questions
- Should title change rename the file?
  - Option A: Keep original filename (simpler)
  - Option B: Offer to rename file (better organization)
  - Recommendation: Option A for v1.0, Option B for v2.0
- Show edit history/versions? (v2.0 with git integration)
- Allow editing raw markdown? (Advanced mode for power users)
