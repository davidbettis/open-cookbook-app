# Task Breakdown: Multi-Photo Import

**Feature Spec**: [docs/specs/import.md](../specs/import.md)
**Scope**: Phase 1 — Multiple photo selection from library

---

## Task 1: Update AnthropicAPIService for multi-image support
**File:** `Core/Services/AnthropicAPIService.swift` (modify)
**Complexity:** Medium
**Dependencies:** None

Replace `extractRecipeFromImage` with `extractRecipeFromImages` that accepts an array of images. Each image becomes a separate `image` content block in the API request.

- Rename method to `extractRecipeFromImages(images:apiKey:model:tagPrompt:)`
  - `images` parameter type: `[(data: Data, mediaType: String)]`
  - Build content blocks by mapping each image to an `image` content block, then appending the text prompt block
- Update `buildPhotoPrompt` to accept an `imageCount: Int` parameter:
  - Single image: `"Extract the recipe from this photo into structured markdown format."`
  - Multiple images: `"These photos show different parts of the same recipe (e.g., a multi-page cookbook spread). Combine them into a single complete recipe in structured markdown format."`
- Remove the old `extractRecipeFromImage` method

**Acceptance Criteria:**
- [ ] `extractRecipeFromImages` sends N image content blocks + 1 text block
- [ ] Prompt preamble adapts for single vs. multiple images
- [ ] Old single-image method removed
- [ ] Build succeeds

---

## Task 2: Update ImportRecipeViewModel for multi-image state
**File:** `Features/Import/ViewModels/ImportRecipeViewModel.swift` (modify)
**Complexity:** Medium
**Dependencies:** Task 1

Change the view model from single-image to multi-image state.

- Replace `selectedImageData: Data?` and `selectedImageMediaType: String` with `selectedImages: [(data: Data, mediaType: String)]`
- Add `static let maxPhotos = 5`
- Add computed property `canAddMorePhotos: Bool` (`selectedImages.count < maxPhotos`)
- Add `func addImage(_ image: UIImage)`:
  - Guard `canAddMorePhotos`
  - Call `resizeImageIfNeeded` and append to `selectedImages`
- Add `func removeImage(at index: Int)`
- Update `statusMessage` for multiple photos: `"Extracting recipe from N photos..."`
- Update `importFromPhoto()`:
  - Guard `!selectedImages.isEmpty` instead of checking single image
  - Call `extractRecipeFromImages(images: selectedImages, ...)`
- Keep `resizeImageIfNeeded` static method unchanged (applied per image)

**Acceptance Criteria:**
- [ ] `selectedImages` array replaces single-image properties
- [ ] `addImage` resizes and appends; respects `maxPhotos` limit
- [ ] `removeImage` removes by index
- [ ] `statusMessage` shows count for multiple photos
- [ ] `importFromPhoto` sends all images to the API
- [ ] Build succeeds

---

## Task 3: Update ImportRecipeView for multi-photo UI
**File:** `Features/Import/Views/ImportRecipeView.swift` (modify)
**Complexity:** Medium
**Dependencies:** Task 2

Replace the single-photo preview with a scrollable thumbnail row supporting add/remove.

- Replace `@State private var selectedImage: UIImage?` with `@State private var selectedUIImages: [UIImage]` (kept for thumbnail display)
- Update `PhotosPicker` to use `maxSelectionCount: 5` and bind to `@State private var selectedPhotoItems: [PhotosPickerItem]`
- Replace single photo preview with a horizontal `ScrollView` of thumbnails:
  - Each thumbnail ~80x80pt, clipped to `RoundedRectangle`
  - Each has an "x" overlay button (top-trailing) calling `removeImage(at:)`
  - If `viewModel.canAddMorePhotos`, show a "+" button at the end that presents `PhotosPicker` or camera
- Update `loadPhoto` to handle array of `PhotosPickerItem`:
  - Load each item, convert to `UIImage`, call `viewModel.addImage(_:)` for each
  - Append to `selectedUIImages` for display
- Camera `onChange(of: selectedImage)` → append to `selectedUIImages` and call `viewModel.addImage`
- Update import button disabled state: `selectedUIImages.isEmpty || viewModel.isImporting`
- Update section header text: `"Take photos of a recipe or choose from your library. Select multiple photos for multi-page recipes."`

**Acceptance Criteria:**
- [ ] `PhotosPicker` allows selecting up to 5 photos at once
- [ ] Thumbnails displayed in a horizontal scroll row
- [ ] Each thumbnail has a working "x" remove button
- [ ] Removing a thumbnail updates both `selectedUIImages` and `viewModel.selectedImages`
- [ ] "+" add-more button hidden when at 5 photos
- [ ] Camera captures append to the existing set
- [ ] Import button disabled when no photos selected
- [ ] Build succeeds

---

## Task 4: Unit tests for multi-image API and view model
**File:** `OpenCookbookTests/MultiPhotoImportTests.swift` (new)
**Complexity:** Medium
**Dependencies:** Tasks 1, 2

Write unit tests covering the multi-image changes. Use Swift Testing framework (`@Test`, `#expect`).

**AnthropicAPIService:**
- `buildPhotoPrompt(imageCount: 1)` returns single-image preamble
- `buildPhotoPrompt(imageCount: 3)` returns multi-image preamble

**ImportRecipeViewModel:**
- `addImage` appends to `selectedImages`
- `addImage` is a no-op when at `maxPhotos`
- `removeImage(at:)` removes the correct image
- `canAddMorePhotos` returns `false` at limit, `true` below
- `statusMessage` says "photo" for 1 image, "N photos" for multiple
- `selectedImages` starts empty

**Acceptance Criteria:**
- [ ] All test cases pass
- [ ] All existing tests still pass

---

## Task 5: Build, test, and polish
**Complexity:** Low
**Dependencies:** Tasks 1-4

Build the project and verify multi-photo import works end-to-end.

1. Build with XcodeBuildMCP
2. Run all unit tests (existing + new)
3. Manual test scenarios:
   - Select 1 photo from library → import → verify recipe extracted
   - Select 3 photos of a multi-page recipe → import → verify single combined recipe
   - Select 5 photos → verify "+" button hidden → remove one → verify "+" reappears
   - Tap "x" on a thumbnail → verify it's removed from the row
   - Take a camera photo → verify it appends to existing library selections
   - Import with no photos → verify button is disabled
4. Fix any issues found

**Acceptance Criteria:**
- [ ] App builds without warnings
- [ ] All unit tests pass
- [ ] Single photo import still works as before
- [ ] Multi-photo import produces a single combined recipe
- [ ] Add/remove photo interactions work correctly
- [ ] Photo limit of 5 is enforced

---

## Summary

| Task | Complexity | Dependencies | Status |
|------|------------|--------------|--------|
| 1. Update AnthropicAPIService for multi-image | Medium | None | Done |
| 2. Update ImportRecipeViewModel for multi-image | Medium | Task 1 | Done |
| 3. Update ImportRecipeView for multi-photo UI | Medium | Task 2 | Done |
| 4. Unit tests | Medium | Tasks 1, 2 | Done |
| 5. Build, test, and polish | Low | Tasks 1-4 | Done |

**Implementation Order**: 1 → 2 → 3 + 4 (parallel) → 5

**Critical Path**: Tasks 1 → 2 → 3

**Files Modified:**
| File | Tasks |
|------|-------|
| `Core/Services/AnthropicAPIService.swift` | Task 1 |
| `Features/Import/ViewModels/ImportRecipeViewModel.swift` | Task 2 |
| `Features/Import/Views/ImportRecipeView.swift` | Task 3 |
| `OpenCookbookTests/MultiPhotoImportTests.swift` | Task 4 (new) |
