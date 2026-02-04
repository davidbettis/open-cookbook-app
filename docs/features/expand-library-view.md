# Expand Recipe Library View (iPad)

**Status:** Implemented

## Overview

Allow iPad users to expand the recipe library sidebar to full screen width for easier browsing, and collapse it back to the standard split view layout.

## Current Implementation

- iPad uses `NavigationSplitView` with sidebar (~33%) and detail pane (~67%)
- `columnVisibility` state controls visibility (`.all`, `.detailOnly`)
- Sidebar width is constrained: `min: 300, ideal: 350, max: 500`
- When a recipe is selected, view switches to `.detailOnly`
- Uses `.prominentDetail` style

## Decisions

| Question | Decision |
|----------|----------|
| Icon placement | Toolbar (far left, top navigation bar) |
| Recipe tap in expanded mode | Show recipe detail, remember expanded state |
| Card layout when expanded | Single column (wider cards) |
| Persist state | Yes - remember last state across sessions |
| Animation | Animated transition |

## Feature Behavior

### Normal Mode (Default)
- Split view: sidebar (~33%) + detail pane (~67%)
- Expand icon visible in toolbar

### Expanded Mode
- Library takes 100% width
- Detail pane hidden
- Collapse icon visible in toolbar
- Recipe cards stretch to fill width (single column)
- Tapping a recipe auto-collapses and shows detail

### Icons
- **Expand**: `arrow.up.left.and.arrow.down.right` or `rectangle.expand.horizontal`
- **Collapse**: `arrow.down.right.and.arrow.up.left` or `rectangle.compress.horizontal`

---

## Implementation Plan

### Approach
Use `NavigationSplitViewVisibility` to control the layout:
- `.all` = normal split view
- `.doubleColumn` with sidebar prominent = expanded (sidebar only)

### State Management
```swift
@AppStorage("isLibraryExpanded") private var isLibraryExpanded = false

// Toggle function
func toggleLibraryExpansion() {
    withAnimation {
        isLibraryExpanded.toggle()
        if isLibraryExpanded {
            columnVisibility = .all
        }
    }
}
```

### Toolbar Button (Far Left)
```swift
ToolbarItem(placement: .topBarLeading) {
    Button {
        toggleLibraryExpansion()
    } label: {
        Image(systemName: isLibraryExpanded
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right")
    }
    .accessibilityLabel(isLibraryExpanded ? "Collapse Library" : "Expand Library")
}
```

### Recipe Selection (Preserves Expanded State)
```swift
.onChange(of: selectedRecipeFile) { _, newValue in
    if newValue != nil {
        withAnimation {
            columnVisibility = .detailOnly
        }
    }
}
```

### Dynamic Sidebar Width
```swift
.navigationSplitViewColumnWidth(
    min: 300,
    ideal: isLibraryExpanded ? .infinity : 350,
    max: isLibraryExpanded ? .infinity : 500
)
```

## Files to Modify

| File | Changes |
|------|---------|
| `RecipeListSplitView.swift` | Add `isLibraryExpanded` state, toolbar button, width logic |

## Testing Checklist

- [ ] Expand button shows in toolbar (far left)
- [ ] Tapping expand hides detail pane, library fills width
- [ ] Collapse button shows when expanded
- [ ] Tapping collapse restores split view
- [ ] Tapping recipe while expanded shows detail (state preserved)
- [ ] Recipe cards display correctly at full width
- [ ] Search and tag filters work in expanded mode
- [ ] State persists across app relaunch
- [ ] Animations are smooth

