# Feature Spec: Delete Recipe

**Priority**: P1 (Should Have)
**Feature ID**: F007

## Description
Allow users to delete recipes from their collection, removing the file from iCloud Drive.

## User Stories

### US-013: Remove unwanted recipes
**As a** user
**I want** to remove recipes I no longer use
**So that** my collection stays organized

## Acceptance Criteria

- [ ] Delete action available in recipe detail view or swipe action in list
- [ ] Confirmation dialog before deletion
- [ ] File permanently removed from iCloud folder
- [ ] Return to list view after deletion
- [ ] Show error if deletion fails

## Technical Requirements

### Implementation Details
- FileManager delete operation with error handling
- SwiftUI swipe actions or context menu
- Alert confirmation dialog
- Remove from in-memory recipe list after successful deletion

### Delete Methods
Two entry points for delete:
1. **Detail View**: Delete button in toolbar/menu
2. **List View**: Swipe left on recipe card → Delete button

### File Operations
- Use FileManager.default.removeItem(at: url)
- Handle errors gracefully
- Update UI only after successful deletion
- No undo functionality in v1.0 (file is permanently deleted)

### Error Handling
- File not found → show warning, remove from list anyway
- Permission denied → show error with instructions
- File locked → show error explaining file is in use

## UI/UX Requirements

### Confirmation Dialog
```
┌─────────────────────────────┐
│  Delete Recipe?             │
│                             │
│  Are you sure you want to   │
│  delete "[Recipe Name]"?    │
│  This action cannot be      │
│  undone.                    │
│                             │
│  [Cancel]  [Delete]         │
└─────────────────────────────┘
```

### Delete Button Styling
- Detail view: Show in toolbar menu (3-dot menu or Edit menu)
- List view: Swipe action with red background
- Both show destructive style (red color)

### Post-Delete Behavior
- If in detail view → navigate back to list with animation
- If in list view → remove card with fade animation
- Show brief toast: "Recipe deleted"
- No undo option (v1.0)

## Dependencies
- FileManager
- SwiftUI navigation coordination (pop to list after delete from detail)

## Test Cases

### TC-036: Delete from detail view
1. Open recipe detail
2. Tap menu button (...)
3. Tap "Delete Recipe"
4. Verify confirmation dialog appears
5. Tap "Delete"
6. Verify navigation to list view
7. Verify recipe removed from list
8. Verify file deleted from iCloud folder

### TC-037: Delete from list swipe
1. View recipe list
2. Swipe left on recipe card
3. Tap red "Delete" button
4. Verify confirmation dialog
5. Confirm deletion
6. Verify recipe removed from list with animation
7. Verify file deleted

### TC-038: Cancel deletion
1. Start delete flow
2. See confirmation dialog
3. Tap "Cancel"
4. Verify recipe NOT deleted
5. Verify file still exists
6. Verify UI unchanged

### TC-039: Delete with file error
1. Manually delete recipe file outside app
2. In app, try to delete same recipe
3. Verify warning shown
4. Verify recipe removed from list anyway

### TC-040: Delete last recipe
1. Have only 1 recipe in collection
2. Delete it
3. Verify empty state shown
4. Verify file deleted

### TC-041: Delete while file is locked
1. Lock recipe file externally (permissions)
2. Try to delete in app
3. Verify error message shown
4. Verify recipe NOT removed from list

## Accessibility Requirements
- Confirmation dialog accessible via VoiceOver
- Delete buttons clearly labeled
- VoiceOver announces "Recipe deleted" after successful deletion

## Security Considerations
- No "trash" or recycle bin in v1.0
- Files permanently deleted from iCloud Drive
- Consider warning users in onboarding that deletions are permanent
- Users can recover from iCloud backup if needed

## Future Enhancements (v2.0)
- Undo deletion (move to trash temporarily)
- Bulk delete (select multiple recipes)
- Archive instead of delete
- Confirm deletion with typed recipe name (for extra safety)
- iCloud trash bin integration

## Open Questions
- Should there be a "Recently Deleted" folder? (Like Photos app)
  - Recommendation: Not for v1.0 (adds complexity)
- Require additional authentication for delete? (Face ID/Touch ID)
  - Recommendation: No, too intrusive for this use case
- Batch delete support?
  - Recommendation: v2.0 feature
