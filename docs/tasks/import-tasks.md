# Task Breakdown: Import Recipe — Photo Import (F009)

**Spec**: [docs/specs/import.md](../specs/import.md)
**Priority**: P1
**Builds on**: Existing website import (Tasks 1–8 from `import-recipe-from-website-tasks.md` — all complete)

This task plan covers adding **photo import** to the existing import feature. The website import flow, `AnthropicAPIService`, `KeychainService`, `ImportRecipeViewModel`, `ImportRecipeView`, and Settings UI are already implemented and shipping in v1.0.2.

---

## Task 1: Refactor AnthropicAPIService — Shared Prompt and Image Method

**Complexity**: Medium
**Dependencies**: None

### Description
Factor the recipe extraction prompt into a shared constant with source-specific preambles, and add a new `extractRecipeFromImage` method that sends a base64-encoded image to the Anthropic Messages API.

### Implementation Steps
1. Modify `Core/Services/AnthropicAPIService.swift`
2. Extract the formatting instructions (steps 1–8, rules) from `buildPrompt(url:)` into a shared `private static let recipeExtractionInstructions` string
3. Refactor `buildPrompt(url:)` to use the shared instructions with a website-specific preamble: `"Fetch the following URL and extract the recipe into structured markdown format:\n\n{url}\n\n"`
4. Add `buildPhotoPrompt()` that uses the shared instructions with a photo-specific preamble: `"Extract the recipe from this photo into structured markdown format.\n\n"`
5. Add `extractRecipeFromImage(imageData:mediaType:apiKey:model:)`:
   - Base64-encode the image data
   - Build the request body with an `image` content block (`type: "base64"`, `media_type`, `data`) followed by a `text` content block with the photo prompt
   - No `tools` array needed (unlike website import which uses `web_fetch`)
   - Call existing `sendRequest(apiKey:body:)` — reuse the shared HTTP/error handling
   - Parse response: find last `text` content block (same as website flow)
   - Check for `NOT_A_RECIPE` sentinel
   - Strip image syntax and return cleaned markdown
6. Add `imageTooLarge` case to `APIError`:
   - Error description: `"The image is too large. Try a smaller photo or lower resolution."`

### Code Example
```swift
// Shared formatting instructions
private static let recipeExtractionInstructions = """
    Format the recipe with these exact specifications:
    1. Title: Use H1 heading (single #)
    2. Tags: On the next line, add italicized tags separated by commas ...
    ...
    Output ONLY the recipe markdown, with no preamble or commentary.
    """

// Refactored website prompt
static func buildPrompt(url: String) -> String {
    """
    Fetch the following URL and extract the recipe into structured markdown format:

    \(url)

    \(recipeExtractionInstructions)
    """
}

// New photo prompt
static func buildPhotoPrompt() -> String {
    """
    Extract the recipe from this photo into structured markdown format.

    \(recipeExtractionInstructions)
    """
}

// New image extraction method
func extractRecipeFromImage(
    imageData: Data,
    mediaType: String,
    apiKey: String,
    model: ClaudeModel
) async throws(APIError) -> String {
    let base64Image = imageData.base64EncodedString()
    let prompt = Self.buildPhotoPrompt()

    let body: [String: Any] = [
        "model": model.rawValue,
        "max_tokens": 8192,
        "messages": [
            [
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": mediaType,
                            "data": base64Image
                        ]
                    ] as [String: Any],
                    [
                        "type": "text",
                        "text": prompt
                    ] as [String: Any]
                ]
            ] as [String: Any]
        ]
    ]

    let data = try await sendRequest(apiKey: apiKey, body: body)

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let content = json["content"] as? [[String: Any]] else {
        throw .decodingError
    }

    guard let text = content.last(where: { $0["type"] as? String == "text" })?["text"] as? String else {
        throw .decodingError
    }

    if text.trimmingCharacters(in: .whitespacesAndNewlines) == "NOT_A_RECIPE" {
        throw .notARecipe
    }

    return Self.stripImageSyntax(text)
}
```

### Acceptance Criteria
- [ ] `buildPrompt(url:)` still produces the same prompt as before (no behavior change for website import)
- [ ] `buildPhotoPrompt()` uses the shared formatting instructions with photo-specific preamble
- [ ] `extractRecipeFromImage` sends base64 image as `image` content block + text prompt
- [ ] No `tools` array in the photo request body
- [ ] Response parsing reuses the same logic: find last text block, check `NOT_A_RECIPE`, strip images
- [ ] `imageTooLarge` error case added to `APIError`
- [ ] Existing `extractRecipe(from:)` website method unchanged in behavior
- [ ] Build succeeds

---

## Task 2: Add Image Resizing Utility

**Complexity**: Low
**Dependencies**: None

### Description
Add a static utility method to compress and resize images before sending to the API. The Anthropic API has a practical limit of ~5MB for base64-encoded image data.

### Implementation Steps
1. Add `resizeImageIfNeeded(_:maxBytes:)` as a static method on `ImportRecipeViewModel`
2. Start at JPEG quality 0.8 and step down by 0.1 until under limit
3. If compression alone isn't enough, scale image dimensions by 50% and retry
4. Return `nil` if the image cannot be made small enough (extremely unlikely)
5. Default `maxBytes` is `3_750_000` (~5MB after base64 encoding's 33% expansion)

### Code Example
```swift
#if canImport(UIKit)
import UIKit

extension ImportRecipeViewModel {
    static func resizeImageIfNeeded(_ image: UIImage, maxBytes: Int = 3_750_000) -> Data? {
        var quality: CGFloat = 0.8
        while quality > 0.1 {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }

        // Scale down dimensions and retry
        let scale: CGFloat = 0.5
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
#endif
```

### Acceptance Criteria
- [ ] Returns JPEG data under `maxBytes` limit
- [ ] Tries compression first before scaling
- [ ] Uses `UIGraphicsImageRenderer` (not deprecated `UIGraphicsBeginImageContext`)
- [ ] Wrapped in `#if canImport(UIKit)` for macOS compatibility
- [ ] Build succeeds

---

## Task 3: Update ImportRecipeViewModel for Photo Import

**Complexity**: Medium
**Dependencies**: Tasks 1, 2

### Description
Extend `ImportRecipeViewModel` with an `ImportSource` enum, photo-related state properties, and a `importFromPhoto()` pipeline that mirrors the existing `importRecipe()` flow.

### Implementation Steps
1. Modify `Features/Import/ViewModels/ImportRecipeViewModel.swift`
2. Add `ImportSource` enum with `.website` and `.photo` cases
3. Add properties:
   - `var source: ImportSource = .website`
   - `var selectedImageData: Data? = nil`
   - `var selectedImageMediaType: String = "image/jpeg"`
4. Update `statusMessage` to be source-aware:
   - `.website`: `"Extracting recipe with Claude..."`
   - `.photo`: `"Extracting recipe from photo..."`
5. Rename existing `importRecipe()` to `importFromWebsite()` (private)
6. Add `importFromPhoto()` (private):
   - Guard `selectedImageData` is non-nil
   - Read API key from Keychain, model from AppStorage
   - Set state to `.extractingRecipe`
   - Call `AnthropicAPIService().extractRecipeFromImage(imageData:mediaType:apiKey:model:)`
   - Run result through `Self.cleanMarkdown()` and validate it starts with `# `
   - Set state to `.success(markdown)` or `.error(message)`
7. Add public `importRecipe()` that dispatches to the correct method based on `source`

### Code Example
```swift
enum ImportSource {
    case website
    case photo
}

var source: ImportSource = .website
var selectedImageData: Data? = nil
var selectedImageMediaType: String = "image/jpeg"

var statusMessage: String {
    switch state {
    case .extractingRecipe:
        return source == .website
            ? "Extracting recipe with Claude..."
            : "Extracting recipe from photo..."
    default: return ""
    }
}

func importRecipe() async {
    switch source {
    case .website:
        await importFromWebsite()
    case .photo:
        await importFromPhoto()
    }
}

private func importFromPhoto() async {
    guard let imageData = selectedImageData else {
        state = .error("No photo selected.")
        return
    }

    do {
        guard let apiKey = try KeychainService.read(key: "anthropic-api-key"), !apiKey.isEmpty else {
            state = .error("No API key configured. Add your key in Settings.")
            return
        }
        let model = AnthropicAPIService.ClaudeModel(rawValue: claudeModelRawValue) ?? .sonnet

        state = .extractingRecipe
        logger.debug("Importing recipe from photo using model \(model.rawValue)")

        let service = AnthropicAPIService()
        let rawMarkdown = try await service.extractRecipeFromImage(
            imageData: imageData,
            mediaType: selectedImageMediaType,
            apiKey: apiKey,
            model: model
        )

        let markdown = Self.cleanMarkdown(rawMarkdown)

        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("# ") else {
            state = .error("Could not extract a recipe from this photo. Try a different photo.")
            return
        }

        state = .success(markdown)
    } catch let error as AnthropicAPIService.APIError {
        logger.error("API error: \(error.errorDescription ?? "unknown")")
        state = .error(error.errorDescription ?? "An unknown error occurred.")
    } catch {
        logger.error("Import failed: \(error.localizedDescription)")
        state = .error("Could not extract a recipe from this photo. Try a different photo.")
    }
}
```

### Acceptance Criteria
- [ ] `ImportSource` enum with `.website` and `.photo` cases
- [ ] `source`, `selectedImageData`, `selectedImageMediaType` properties added
- [ ] `importRecipe()` dispatches to correct method based on source
- [ ] `importFromPhoto()` follows the same pattern as website: read key → call API → clean → validate → set state
- [ ] `statusMessage` is source-aware
- [ ] Existing website import behavior is unchanged
- [ ] Build succeeds

---

## Task 4: Create CameraView

**Complexity**: Low
**Dependencies**: None

### Description
Create a `UIViewControllerRepresentable` wrapper around `UIImagePickerController` for camera access. This is needed because SwiftUI's `PhotosPicker` does not support camera capture.

### Implementation Steps
1. Create `Features/Import/Views/CameraView.swift`
2. Wrap `UIImagePickerController` with `.camera` source type
3. Coordinator handles `imagePickerController(_:didFinishPickingMediaWithInfo:)` and `imagePickerControllerDidCancel`
4. Output the selected `UIImage` via a `@Binding`
5. Dismiss on selection or cancellation
6. Wrap in `#if canImport(UIKit)` for macOS compatibility

### Code Example
```swift
#if canImport(UIKit)
import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
```

### Acceptance Criteria
- [ ] `CameraView` wraps `UIImagePickerController` with `.camera` source
- [ ] Selected image passed via `@Binding var image: UIImage?`
- [ ] Dismisses on photo capture or cancellation
- [ ] Wrapped in `#if canImport(UIKit)`
- [ ] Build succeeds

---

## Task 5: Update ImportRecipeView — Add Photo Tab UI

**Complexity**: High
**Dependencies**: Tasks 3, 4

### Description
Evolve `ImportRecipeView` from a single URL-input form into a two-tab interface with a segmented picker. The "Website" tab preserves the existing URL input. The new "Photo" tab adds camera/library buttons, photo preview, and an Import button.

### Implementation Steps
1. Modify `Features/Import/Views/ImportRecipeView.swift`
2. Add `import PhotosUI` at top of file
3. Add state properties:
   - `@State private var selectedImage: UIImage? = nil`
   - `@State private var showCamera = false`
   - `@State private var selectedPhotoItem: PhotosPickerItem? = nil`
4. Accept an `initialSource: ImportRecipeViewModel.ImportSource` parameter (default `.website`) to control which tab is shown when the sheet opens
5. Set `viewModel.source` from `initialSource` on appear
6. Add a `Picker` (segmented style) at the top of the form to switch between `.website` and `.photo`
7. Show the appropriate section based on `viewModel.source`:
   - `.website`: existing `urlInputSection` (unchanged)
   - `.photo`: new `photoInputSection`
8. Implement `photoInputSection`:
   - Header text: "Take a photo of a recipe or choose one from your library."
   - If `selectedImage` is non-nil: show `Image(uiImage:)` preview (resizable, aspect fit, max height ~250)
   - Camera button: `Button("Take Photo")` / `"Retake"` — presents `CameraView` via `.fullScreenCover`
   - Photo Library button: `PhotosPicker(selection:matching:)` with label "Choose from Library" / "Choose Different"
   - Import button: same style as website, disabled until `selectedImage` is non-nil
9. When `selectedImage` changes, run `resizeImageIfNeeded()` and store result in `viewModel.selectedImageData`
10. When `selectedPhotoItem` changes, load the image data via `loadTransferable(type: Data.self)` and convert to `UIImage`
11. When switching tabs via the segmented picker, reset the other tab's state
12. Check camera availability with `UIImagePickerController.isSourceTypeAvailable(.camera)` — hide camera button if unavailable
13. The no-API-key state applies to both tabs (show guidance regardless of selected tab)
14. Add `NSCameraUsageDescription` to Info.plist: "OpenCookbook uses the camera to photograph recipes for import."

### Code Example
```swift
// Segmented picker
Picker("Source", selection: $viewModel.source) {
    Text("Website").tag(ImportRecipeViewModel.ImportSource.website)
    Text("Photo").tag(ImportRecipeViewModel.ImportSource.photo)
}
.pickerStyle(.segmented)
.listRowBackground(Color.clear)
.listRowInsets(EdgeInsets())

// Photo input section
private var photoInputSection: some View {
    Section {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 250)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        HStack {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label(selectedImage == nil ? "Take Photo" : "Retake",
                          systemImage: "camera")
                }
                .buttonStyle(.bordered)
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                Label(selectedImage == nil ? "Photo Library" : "Choose Different",
                      systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .center)

        Button {
            Task { await viewModel.importRecipe() }
        } label: {
            Text("Import Recipe")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedImage == nil || viewModel.isImporting)
    } header: {
        Text("Take a photo of a recipe or choose one from your library.")
    }
}
```

### Acceptance Criteria
- [ ] Segmented picker switches between Website and Photo tabs
- [ ] `initialSource` parameter controls which tab is shown on open
- [ ] Website tab: unchanged from current implementation
- [ ] Photo tab: Camera button, Photo Library picker, photo preview, Import button
- [ ] Camera button hidden when camera unavailable
- [ ] Button labels change after photo selection ("Retake" / "Choose Different")
- [ ] Import button disabled until photo is selected
- [ ] Photo preview shown with proper aspect ratio
- [ ] Image data passed to view model via `resizeImageIfNeeded()` when photo is selected
- [ ] `PhotosPicker` item loaded and converted to `UIImage`
- [ ] No-API-key state shown regardless of selected tab
- [ ] Loading state works for photo import ("Extracting recipe from photo...")
- [ ] Error alerts work for photo import
- [ ] Tab switching resets the other tab's state
- [ ] `NSCameraUsageDescription` added to Info.plist
- [ ] Build succeeds

---

## Task 6: Update + Button Menus — Add "Import from Photo"

**Complexity**: Low
**Dependencies**: Task 5

### Description
Add "Import from Photo" as a third option in the `+` button menu in both `RecipeListView` and `RecipeListSplitView`. Each import menu item opens `ImportRecipeView` with the appropriate `initialSource`.

### Implementation Steps
1. Modify `Features/RecipeList/Views/RecipeListView.swift`:
   - Change `showImportRecipe` to `showImportFromWebsite` and add `showImportFromPhoto`
   - Add "Import from Photo" button to the `Menu` with `systemImage: "camera"`
   - Update `.sheet` modifiers: present `ImportRecipeView(initialSource: .website)` or `ImportRecipeView(initialSource: .photo)`
   - Alternatively, use a single `@State var importSource: ImportRecipeViewModel.ImportSource?` and a single `.sheet(item:)` if cleaner
2. Repeat changes in `Features/RecipeList/Views/RecipeListSplitView.swift`

### Code Example
```swift
Menu {
    Button {
        showAddRecipe = true
    } label: {
        Label("New Recipe", systemImage: "square.and.pencil")
    }
    Button {
        showImportFromWebsite = true
    } label: {
        Label("Import from Website", systemImage: "globe")
    }
    Button {
        showImportFromPhoto = true
    } label: {
        Label("Import from Photo", systemImage: "camera")
    }
} label: {
    Image(systemName: "plus")
}
```

### Acceptance Criteria
- [ ] `+` menu in `RecipeListView` has three options: New Recipe, Import from Website, Import from Photo
- [ ] `+` menu in `RecipeListSplitView` has three options: New Recipe, Import from Website, Import from Photo
- [ ] "Import from Website" opens `ImportRecipeView` with Website tab selected
- [ ] "Import from Photo" opens `ImportRecipeView` with Photo tab selected
- [ ] SF Symbols: `square.and.pencil`, `globe`, `camera`
- [ ] Existing "New Recipe" and "Import from Website" behavior preserved
- [ ] Build succeeds

---

## Task 7: Unit Tests for Photo Import

**Complexity**: Medium
**Dependencies**: Tasks 1–6

### Description
Add unit tests for the new photo import functionality: prompt construction, image resizing, view model source dispatching, and API service method.

### Implementation Steps
1. Modify `OpenCookbookTests/AnthropicAPIServiceTests.swift`:
   - Test `buildPhotoPrompt()` includes formatting instructions and `NOT_A_RECIPE` rule
   - Test `buildPhotoPrompt()` does NOT contain URL-related text
   - Test `buildPrompt(url:)` still works as before (regression)
   - Test that shared instructions are consistent between both prompts
2. Create or modify `OpenCookbookTests/ImportRecipeViewModelTests.swift`:
   - Test `ImportSource` enum has `.website` and `.photo` cases
   - Test `statusMessage` returns correct text for each source when extracting
   - Test `importRecipe()` with `.photo` source and `nil` image data → error state
   - Test `resizeImageIfNeeded` returns data under the limit
   - Test `resizeImageIfNeeded` compresses a large image
3. Verify existing website import tests still pass

### Code Example
```swift
@Suite("AnthropicAPIService Photo Tests")
struct AnthropicAPIServicePhotoTests {
    @Test("Photo prompt includes formatting instructions")
    func photoPromptContent() {
        let prompt = AnthropicAPIService.buildPhotoPrompt()
        #expect(prompt.contains("Format the recipe with these exact specifications"))
        #expect(prompt.contains("NOT_A_RECIPE"))
        #expect(prompt.contains("Extract the recipe from this photo"))
    }

    @Test("Photo prompt does not contain URL-related text")
    func photoPromptNoURL() {
        let prompt = AnthropicAPIService.buildPhotoPrompt()
        #expect(!prompt.contains("Fetch the following URL"))
        #expect(!prompt.contains("Visit the following URL"))
    }

    @Test("Website prompt unchanged")
    func websitePromptRegression() {
        let prompt = AnthropicAPIService.buildPrompt(url: "https://example.com")
        #expect(prompt.contains("https://example.com"))
        #expect(prompt.contains("Fetch the following URL"))
    }
}

@Suite("ImportRecipeViewModel Photo Tests")
struct ImportRecipeViewModelPhotoTests {
    @Test("Status message for photo import")
    @MainActor
    func photoStatusMessage() {
        let vm = ImportRecipeViewModel()
        vm.source = .photo
        vm.state = .extractingRecipe
        #expect(vm.statusMessage == "Extracting recipe from photo...")
    }

    @Test("Status message for website import")
    @MainActor
    func websiteStatusMessage() {
        let vm = ImportRecipeViewModel()
        vm.source = .website
        vm.state = .extractingRecipe
        #expect(vm.statusMessage == "Extracting recipe with Claude...")
    }

    @Test("Import with no photo selected yields error")
    @MainActor
    func importNoPhoto() async {
        let vm = ImportRecipeViewModel()
        vm.source = .photo
        vm.selectedImageData = nil
        await vm.importRecipe()
        #expect(vm.state == .error("No photo selected."))
    }
}

#if canImport(UIKit)
@Suite("Image Resizing Tests")
struct ImageResizingTests {
    @Test("Small image returns data as-is")
    func smallImage() {
        let image = UIImage(systemName: "star")!
        let data = ImportRecipeViewModel.resizeImageIfNeeded(image)
        #expect(data != nil)
        #expect(data!.count < 3_750_000)
    }
}
#endif
```

### Acceptance Criteria
- [ ] Photo prompt tests pass (content, no URL text)
- [ ] Website prompt regression test passes
- [ ] ViewModel source-aware status message tests pass
- [ ] Import with no photo → error state test passes
- [ ] Image resizing tests pass
- [ ] All existing tests still pass
- [ ] All tests use Swift Testing framework (`@Test`, `#expect`, `@Suite`)

---

## Task 8: Integration Testing and Polish

**Complexity**: Low
**Dependencies**: Tasks 1–7

### Description
End-to-end manual testing of the photo import flow and final polish. Verify the full pipeline works on device.

### Implementation Steps
1. Build the app with XcodeBuildMCP
2. Run all unit tests with XcodeBuildMCP
3. Manual test on device/simulator:
   - Import from photo library: select a photo of a recipe, verify extraction and form pre-population
   - Import from camera (device only): take a photo, verify extraction
   - Verify error handling: import a non-recipe photo, verify "NOT_A_RECIPE" error
   - Verify large image compression: import a high-resolution photo, verify it's resized
   - Switch between Website and Photo tabs, verify state resets
   - Verify no-API-key state applies to Photo tab
   - Verify camera button hidden on simulator (no camera available)
4. Verify existing website import still works end-to-end
5. Fix any issues found during testing

### Acceptance Criteria
- [ ] App builds without warnings
- [ ] All unit tests pass
- [ ] Photo library import works end-to-end (select → extract → form → save)
- [ ] Camera import works on device
- [ ] Error states display correctly for photo import
- [ ] Large images are compressed before sending
- [ ] Tab switching works correctly
- [ ] Website import regression: still works as before
- [ ] No-API-key state shown for both tabs

---

## Summary

| Task | Complexity | Dependencies | Status |
|------|------------|--------------|--------|
| 1. Refactor API Service — Shared Prompt + Image Method | Medium | None | Pending |
| 2. Add Image Resizing Utility | Low | None | Pending |
| 3. Update ImportRecipeViewModel for Photo Import | Medium | Tasks 1, 2 | Pending |
| 4. Create CameraView | Low | None | Pending |
| 5. Update ImportRecipeView — Add Photo Tab UI | High | Tasks 3, 4 | Pending |
| 6. Update + Button Menus — Add "Import from Photo" | Low | Task 5 | Pending |
| 7. Unit Tests for Photo Import | Medium | Tasks 1–6 | Pending |
| 8. Integration Testing and Polish | Low | Tasks 1–7 | Pending |

**Implementation Order**: 1 + 2 + 4 (parallel) → 3 → 5 → 6 → 7 → 8

**Critical Path**: Tasks 1, 3, 5, 6 are required for end-to-end photo import.

**Parallelizable**: Tasks 1, 2, and 4 have no dependencies on each other and can be implemented simultaneously.

**Files Modified**:
| File | Tasks |
|------|-------|
| `Core/Services/AnthropicAPIService.swift` | Task 1 |
| `Features/Import/ViewModels/ImportRecipeViewModel.swift` | Tasks 2, 3 |
| `Features/Import/Views/CameraView.swift` | Task 4 (new) |
| `Features/Import/Views/ImportRecipeView.swift` | Task 5 |
| `Features/RecipeList/Views/RecipeListView.swift` | Task 6 |
| `Features/RecipeList/Views/RecipeListSplitView.swift` | Task 6 |
| `Info.plist` | Task 5 |
| `OpenCookbookTests/AnthropicAPIServiceTests.swift` | Task 7 |
| `OpenCookbookTests/ImportRecipeViewModelTests.swift` | Task 7 |

**Verification**:
- Build with XcodeBuildMCP after each task
- Run tests with XcodeBuildMCP after Task 7
- Manual test on device after Task 8: take photo of recipe, verify extraction and form pre-population
