# Feature Spec: Recipe Library View

**Priority**: P0 (Must Have)
**Feature ID**: F002

## Description
Display all RecipeMD files from the selected iCloud folder in a scrollable list/grid view with recipe names, tags, and optional images.

## User Stories

### US-003: Browse recipe collection
**As a** user
**I want** to see all my recipes at a glance
**So that** I can quickly browse my collection

### US-004: View recipe metadata
**As a** user
**I want** to see recipe metadata (title, tags) without opening each recipe
**So that** I can quickly identify recipes

## Acceptance Criteria

- [ ] List view displays all .md files from iCloud folder
- [ ] Parse RecipeMD files to extract recipe title and tags
- [ ] Display recipe cards with title and primary tag(s)
- [ ] Support pull-to-refresh to reload from iCloud
- [ ] Handle parsing errors gracefully (skip invalid files with warning)
- [ ] Show empty state when no recipes exist

## Technical Requirements

### Implementation Details
- RecipeMD parser following v2.4.0 specification (CommonMark-based)
- SwiftUI List or LazyVGrid for recipe display
- @Observable ViewModel for recipe list state management
- File monitoring for real-time updates when recipes added externally
- CommonMark parser (consider swift-markdown or custom implementation)
- Platform-adaptive layout:
  - Use `NavigationSplitView` for iPad with two-column layout
  - Use `NavigationStack` for iPhone with standard navigation
  - Detect device idiom with `UIDevice.current.userInterfaceIdiom`
  - Share ViewModels between both layouts

### Performance
- Lazy loading for large collections (500+ recipes)
- Parse recipes on background thread
- Cache parsed metadata to avoid repeated file reads
- Smooth 60fps scrolling (120fps on ProMotion)

### Data Management
- Monitor iCloud folder for file additions/deletions/modifications
- Debounce file system events (300ms) to avoid excessive reloads
- Handle iCloud download placeholders gracefully

## UI/UX Requirements

### Platform-Specific Layout

#### iPad Layout
- Split view layout with:
  - Recipe list on the left (fixed width or 30-40% of screen)
  - Recipe detail view on the right
  - Selected recipe highlighted in list
  - Detail view updates when selecting different recipes
  - Persistent split view in landscape and portrait

#### iOS (iPhone) Layout
- Standard navigation stack
- Full-width recipe list
- Tap recipe to navigate to detail view
- Standard back button to return to list
- Single recipe view at a time (insufficient screen space for split view)

### List View Layout
- Recipe card shows:
  - Title (H2 size, bold)
  - Primary tag (small, colored chip)
  - Optional: first line of description (gray, italic)
- Cards have subtle shadow/border
- Tappable to open detail view (iOS) or update right pane (iPad)

### Empty State
- Friendly illustration
- "No recipes yet" message
- "Tap + to add your first recipe" subtitle
- CTA button to add recipe

### Loading State
- Show skeleton cards while loading
- Progress indicator for large collections

### Error Handling
- Invalid RecipeMD files shown with warning icon
- Tap warning to see parsing error details
- Option to open in text editor

## Dependencies
- RecipeMD parser (see Technical Architecture Notes in PRD)
- FileManager for folder monitoring
- swift-markdown or custom CommonMark parser

## Test Cases

### TC-004: Display recipe list
1. Add 5 valid RecipeMD files to iCloud folder
2. Launch app
3. Verify all 5 recipes appear in list
4. Verify titles are displayed correctly
5. Verify tags are shown

### TC-005: Empty state
1. Select empty iCloud folder
2. Verify empty state UI appears
3. Verify message is clear
4. Verify add button is present

### TC-006: Pull to refresh
1. View recipe list
2. Add recipe file externally (via Files app)
3. Pull down to refresh
4. Verify new recipe appears

### TC-007: Invalid file handling
1. Add invalid .md file to folder
2. Refresh list
3. Verify file appears with warning icon
4. Tap warning
5. Verify error details shown

### TC-008: Performance with large collection
1. Add 500 RecipeMD files to folder
2. Launch app and time load
3. Verify load completes < 3s
4. Scroll through list
5. Verify smooth scrolling (no lag)

### TC-009: iPad split view layout
1. Launch app on iPad
2. Verify recipe list appears on left side
3. Select a recipe from list
4. Verify detail view appears on right side
5. Verify selected recipe is highlighted in list
6. Select different recipe
7. Verify right pane updates without navigation
8. Rotate device to portrait and landscape
9. Verify split view persists in both orientations

### TC-010: iPhone navigation layout
1. Launch app on iPhone
2. Verify full-width recipe list appears
3. Tap a recipe
4. Verify navigation to detail view (list hidden)
5. Tap back button
6. Verify return to recipe list
7. Verify no split view on iPhone

## Open Questions
- List view vs. Grid view? List
- Show recipe image thumbnails? No
- Sort options? (Alphabetical, recently modified, recently added)
