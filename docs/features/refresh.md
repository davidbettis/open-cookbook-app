# Recipe Library Refresh Feature

**Status:** Implemented

## Problem Statement

When a user adds a new recipe via the form, the recipe does not appear instantly in the library view. Users must manually pull-to-refresh to see newly added recipes.

## Current Implementation Analysis

### Flow When Adding a Recipe

1. User fills out `RecipeFormView` and taps Save
2. `RecipeFormViewModel.save()` calls `RecipeStore.saveNewRecipe()`
3. `saveNewRecipe()` writes file to disk and appends to `recipes` array (line 150)
4. Sheet dismisses via `dismiss()`
5. `onSave` callback calls `viewModel.syncSearchService()`
6. `onChange(of: viewModel.recipeStore.recipes)` should trigger `syncSearchService()`

### Identified Issues

1. **No Real-Time File Monitoring**: `RecipeFileMonitor` sets up an `onFilesChanged` callback but never actually monitors the file system. No `DispatchSource` or file system events are implemented.

2. **Potential Race Condition**: The save operation and view dismissal may complete before SwiftUI observes the `@Observable` change.

3. **Search Service Sync Timing**: `syncSearchService()` is called in `onSave`, but if `displayedRecipes` uses filtered results, the timing may be off.

4. **iPad Split View**: `RecipeListSplitView` may have separate observation issues not covered by iPhone testing.

## Proposed Solution

### Option A: Immediate UI Update (Recommended)

Ensure the existing in-memory update propagates correctly through SwiftUI's observation system.

**Changes Required:**

1. **RecipeStore.swift** - Verify `@Observable` triggers correctly:
   - The `recipes.append()` and `recipes.sort()` should trigger observation
   - Current implementation looks correct but may need `withAnimation` wrapper

2. **RecipeFormView.swift** - Ensure dismissal happens AFTER state update:
   ```swift
   // Current flow may dismiss before observation propagates
   onSave(savedRecipeFile)
   dismiss()

   // Proposed: Small delay or use Task to ensure update completes
   onSave(savedRecipeFile)
   try? await Task.sleep(for: .milliseconds(100))
   dismiss()
   ```

3. **RecipeListViewModel** - Force observation refresh:
   ```swift
   func forceRefresh() {
       // Trigger objectWillChange if needed
       let current = recipeStore.recipes
       searchService.updateRecipes(current)
   }
   ```

### Option B: File System Monitoring (Future Enhancement)

Implement proper file system monitoring using `DispatchSource` for external changes (e.g., files added via Finder, iCloud sync).

**Changes Required:**

1. **RecipeFileMonitor.swift** - Add real monitoring:
   ```swift
   private var folderSource: DispatchSourceFileSystemObject?

   func startMonitoring(folder: URL) {
       monitoredFolder = folder
       scanFolder()

       // Set up DispatchSource for folder changes
       let descriptor = open(folder.path, O_EVTONLY)
       guard descriptor >= 0 else { return }

       let source = DispatchSource.makeFileSystemObjectSource(
           fileDescriptor: descriptor,
           eventMask: .write,
           queue: .main
       )

       source.setEventHandler { [weak self] in
           // Debounce and trigger refresh
           self?.debouncedRefresh()
       }

       source.setCancelHandler {
           close(descriptor)
       }

       source.resume()
       folderSource = source
   }
   ```

2. **Debounce Logic** - Prevent excessive refreshes:
   ```swift
   private var debounceTask: Task<Void, Never>?

   private func debouncedRefresh() {
       debounceTask?.cancel()
       debounceTask = Task {
           try? await Task.sleep(for: .milliseconds(500))
           guard !Task.isCancelled else { return }
           await MainActor.run {
               onFilesChanged?()
           }
       }
   }
   ```

### Option C: Notification-Based Refresh

Use NotificationCenter to signal recipe changes across the app.

**Changes Required:**

1. **Define notification**:
   ```swift
   extension Notification.Name {
       static let recipesDidChange = Notification.Name("recipesDidChange")
   }
   ```

2. **Post from RecipeStore**:
   ```swift
   func saveNewRecipe(...) async throws -> RecipeFile {
       // ... existing code ...
       NotificationCenter.default.post(name: .recipesDidChange, object: nil)
       return savedRecipeFile
   }
   ```

3. **Observe in views**:
   ```swift
   .onReceive(NotificationCenter.default.publisher(for: .recipesDidChange)) { _ in
       viewModel.syncSearchService()
   }
   ```

## Recommended Implementation Plan

### Phase 1: Fix Immediate Refresh (Priority: High)

1. Debug the current `@Observable` flow to understand why changes aren't propagating
2. Add logging to `RecipeStore.saveNewRecipe()` to verify `recipes` array is updated
3. Verify `displayedRecipes` computed property returns updated array
4. Test if issue is with `searchService.hasActiveFilters` returning true incorrectly

**Diagnostic Steps:**
```swift
// Add to RecipeStore.saveNewRecipe() after line 152
print("[RecipeStore] Added recipe: \(savedRecipeFile.title), total: \(recipes.count)")

// Add to RecipeListViewModel.displayedRecipes
print("[ViewModel] hasActiveFilters: \(searchService.hasActiveFilters), count: \(displayedRecipes.count)")
```

### Phase 2: Ensure Proper Observation (Priority: High)

1. Wrap array mutations in `MainActor.run` if not already on main thread
2. Consider using `withAnimation` for smoother list updates:
   ```swift
   withAnimation {
       recipes.append(savedRecipeFile)
       recipes.sort { ... }
   }
   ```

### Phase 3: Add File System Monitoring (Priority: Medium)

1. Implement `DispatchSource` monitoring in `RecipeFileMonitor`
2. Add debouncing to prevent excessive refreshes
3. Handle iCloud download placeholders gracefully

### Phase 4: Pull-to-Refresh Enhancement (Priority: Low)

1. Add visual feedback (haptic) when refresh completes
2. Show "Updated just now" timestamp
3. Add toolbar refresh button as alternative to pull gesture

## Testing Checklist

- [ ] Add new recipe → appears immediately in list
- [ ] Add new recipe → searchable immediately
- [ ] Add new recipe with tags → appears in tag filter
- [ ] Edit recipe → changes appear immediately
- [ ] Delete recipe → removed immediately
- [ ] External file added (Finder/iCloud) → appears after monitor delay
- [ ] Pull-to-refresh → shows all current recipes
- [ ] iPad split view → same behavior as iPhone

## Files to Modify

| File | Changes |
|------|---------|
| `RecipeStore.swift` | Verify observation, add animation wrapper |
| `RecipeFileMonitor.swift` | Add DispatchSource monitoring |
| `RecipeListViewModel.swift` | Add forceRefresh method |
| `RecipeFormView.swift` | Ensure proper dismissal timing |
| `RecipeListView.swift` | Add notification observer if needed |
| `RecipeListSplitView.swift` | Mirror iPhone changes |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| File monitoring battery drain | Aggressive debouncing (500ms+) |
| iCloud sync conflicts | Use file coordination APIs |
| Memory pressure from frequent re-parsing | Existing cache should prevent re-parsing unchanged files |
| Race conditions | Use `@MainActor` consistently |

## Success Criteria

1. New recipes appear in list within 200ms of save completion
2. No visible flicker or jump when recipe appears
3. Search index includes new recipe immediately
4. Pull-to-refresh still works as fallback
5. External file changes detected within 1 second

---

## v1 — Real-time monitoring & animated updates

### RecipeFileMonitor.swift
- `DispatchSource.makeFileSystemObjectSource` for real-time folder monitoring
- Monitors `.write`, `.delete`, `.rename`, `.extend` events
- 500 ms debounce batches rapid file-system events
- Security-scoped resource access for iCloud Drive folders

### RecipeStore.swift
- `withAnimation {}` wraps all array mutations for smooth list transitions
- `reloadFromMonitor()` reads files off the main actor via `Task.detached`

### RecipeListView.swift & RecipeListSplitView.swift
- `onSave` callback syncs search service immediately after save
- `onChange(of: recipeStore.recipes)` keeps search index in sync

---

## v2 — Background Loading with Progress

### Problem

On first launch with a large iCloud library:
- `String(contentsOf:)` on an iCloud placeholder file blocks the calling thread until iCloud downloads the content, which can take seconds per file.
- All files were read before checking the cache, so even unchanged files did full disk I/O.
- The only loading indicator was an indeterminate spinner — no sense of progress.

### Three-Phase Loading Architecture

`RecipeStore.reloadFromMonitor()` uses three distinct phases to keep all blocking I/O off the main actor and provide real-time progress:

#### Phase 1 — Metadata only (Task.detached)
For each `.md` file URL, read only:
- Modification date (`FileManager.attributesOfItem`) — used for cache validation
- iCloud download status (`url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])`) — used to detect placeholders

No file content is read in this phase. Returns `[(url, modDate, downloadStatus)]` — all `Sendable`.

#### Phase 2 — Cache check + download triggering (main actor, no I/O)
For each file using the metadata from Phase 1:
- **Cache hit** (`modDate` matches cached entry): immediately add to results and increment progress.
- **iCloud placeholder** (`.notDownloaded`): call `FileManager.startDownloadingUbiquitousItem(at:)` to request iOS download it; track in `pendingDownloadURLs`; count toward progress (as "deferred").
- **Cache miss / stale**: queue for Phase 3.

#### Phase 3 — Concurrent content reads (TaskGroup inside Task.detached)
Read file content for cache misses **concurrently** using `withTaskGroup`. Each completed read returns `(url, content, modDate)`. Results are handed back to the main actor for the CPU-only RecipeMD parse step. Progress is updated after each file completes.

### Progress State

`RecipeStore` exposes:

```swift
struct LoadingProgress {
    let total: Int      // total .md files in the folder
    let loaded: Int     // cache hits + parsed + deferred (everything settled)
    var remaining: Int { total - loaded }
    var fraction: Double { total > 0 ? Double(loaded) / Double(total) : 0 }
}
var loadingProgress: LoadingProgress? = nil   // nil when not loading
var pendingDownloadCount: Int = 0             // files waiting on iCloud
```

`loadingProgress` is set at the start of `reloadFromMonitor()`, updated incrementally, and cleared when loading finishes.

### UI

In `RecipeListView` and `RecipeListSplitView`:
- A determinate `ProgressView(value: progress.fraction)` bar replaces the indeterminate spinner during initial load (when the recipe list is still empty).
- A compact loading banner via `.safeAreaInset(edge: .top)` appears above the list when loading is in progress and some recipes are already visible.
- When `pendingDownloadCount > 0`, the loading view shows: **"Waiting for iCloud to download N recipe(s)"**

### iCloud Stall Detection

When `reloadFromMonitor()` finishes with `pendingDownloadCount > 0`, a stall timer fires after **15 seconds**. If files are still not downloaded, `startDownloadingUbiquitousItem` is re-called for each pending URL and the timer resets. The timer is cancelled when `refreshRecipes()` runs (meaning iCloud delivered a file and the file monitor fired).

The existing `DispatchSource` in `RecipeFileMonitor` automatically fires `onFilesChanged` when iCloud writes downloaded content to the folder — no polling needed for the happy path.

### Files Modified

| File | Changes |
|------|---------|
| `Core/Services/RecipeStore.swift` | `LoadingProgress` struct, `loadingProgress`/`pendingDownloadCount` state, three-phase `reloadFromMonitor()`, stall timer |
| `Features/RecipeList/Views/RecipeListView.swift` | Determinate progress bar, iCloud waiting label, top banner for in-progress loads |
| `Features/RecipeList/Views/RecipeListSplitView.swift` | Same |
