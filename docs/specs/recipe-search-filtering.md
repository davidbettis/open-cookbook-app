# Feature Spec: Recipe Search & Filtering

**Priority**: P0 (Must Have)
**Feature ID**: F003

## Description
Search recipes by title, ingredients, tags, or recipe content. Filter by tags defined in RecipeMD format.

## User Stories

### US-005: Search by ingredient
**As a** user
**I want** to search for recipes by name or ingredient
**So that** I can quickly find what I'm looking for

### US-006: Filter by tags
**As a** user
**I want** to filter by tags (e.g., "vegetarian", "quick")
**So that** I can narrow down my options

## Acceptance Criteria

- [ ] Search bar filters recipes in real-time as user types
- [ ] Search matches recipe title, tags, ingredients, and instructions
- [ ] Tag filter UI displays all available tags from recipe collection
- [ ] Multiple tag filters can be applied simultaneously (AND logic)
- [ ] Clear search/filters button to reset view
- [ ] Search is case-insensitive

## Technical Requirements

### Implementation Details
- Implement search using Predicate or custom filtering logic
- Index tags from all recipes for filter UI
- Debounced search input to avoid excessive filtering (250ms delay)
- Efficient text search algorithm (consider Fuse.swift for fuzzy matching if needed)

### Search Behavior
- Search scope: title, description, tags, ingredient names, instructions
- Real-time filtering as user types
- Highlight matching text in results (optional for v1.0)
- Case-insensitive matching
- Support partial word matching

### Tag Filtering
- Extract all unique tags from recipe collection
- Display as selectable chips/pills
- Multi-select with AND logic (all selected tags must match)
- Show count badge on each tag (# of recipes)
- Clear all filters button

### Performance
- Debounce search input (250ms)
- Index recipes for fast search (in-memory)
- Search should complete < 100ms for 500 recipes

## UI/UX Requirements

### Search Bar
- Prominent at top of recipe list
- Placeholder text: "Search recipes..."
- Clear button (X) to reset search
- Search icon on left

### Tag Filter UI
- Horizontal scrolling tag bar below search
- Tappable tag chips with toggle state
- Active tags highlighted (colored background)
- Inactive tags gray outline
- Show "All Tags" button to see full list if many tags

### Search Results
- Show result count: "42 recipes found"
- If no results: "No recipes match your search"
- Maintain list view layout
- Option to clear filters from empty state

## Dependencies
- Recipe indexing service
- Tag extraction from RecipeMD parser

## Test Cases

### TC-009: Search by title
1. Enter "chocolate" in search bar
2. Verify only recipes with "chocolate" in title appear
3. Verify results update in real-time
4. Clear search
5. Verify all recipes reappear

### TC-010: Search by ingredient
1. Enter "flour" in search bar
2. Verify recipes with "flour" in ingredients appear
3. Verify case-insensitive (FLOUR, Flour, flour all match)

### TC-011: Tag filtering
1. Tap "dessert" tag
2. Verify only dessert recipes appear
3. Tap "quick" tag (in addition to dessert)
4. Verify only recipes with BOTH tags appear
5. Tap "dessert" again to deselect
6. Verify only "quick" recipes appear

### TC-012: Combined search and filter
1. Enter "chicken" in search
2. Select "quick" tag
3. Verify results have "chicken" AND "quick" tag
4. Clear all filters
5. Verify full list restored

### TC-013: No results
1. Search for "asdfghjkl"
2. Verify "No recipes match" message
3. Verify clear filters option shown

### TC-014: Search performance
1. Load 500 recipes
2. Type search query
3. Measure time to first result
4. Verify < 300ms response time

## Open Questions
- Fuzzy search (typo tolerance)? (Nice to have for v2.0)
- Search history? (Out of scope for v1.0)
- Filter by yield? (e.g., "serves 4+") - Future enhancement
- OR logic for tags? (v1.0 is AND only)
