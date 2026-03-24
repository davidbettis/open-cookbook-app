# Feature Spec: Import Recipe

**Priority**: P1
**Feature ID**: F009

## Description
Import recipes from external sources — websites or photos — by sending content to the Anthropic Messages API (Claude) and pre-filling the recipe form with the extracted data. The user reviews and edits the recipe in the existing form before saving. Users provide their own Anthropic API key, stored securely in the iOS Keychain.

### Import Sources
1. **Website** (existing): Paste a URL. Claude fetches and processes the web page content directly using the `web_fetch` tool — the app only sends the URL, not the HTML.
2. **Photo** (new): Take a photo or choose from the photo library. The app sends the image to Claude as a base64-encoded image content block. Claude reads the recipe from the photo and extracts it into RecipeMD format.

Both sources use the same extraction prompt (with minor source-specific preamble) and flow into the same review → edit → save pipeline.

## User Stories

### US-023: Import a recipe from a website
**As a** user
**I want** to paste a recipe URL and have the app extract the recipe details
**So that** I can quickly add recipes I find online without manual data entry

### US-024: Configure AI settings
**As a** user
**I want** to enter my Anthropic API key and choose a Claude model
**So that** I can use the import feature with my own account

### US-025: Review imported recipe before saving
**As a** user
**I want** to review and edit the extracted recipe in the form before saving
**So that** I can correct any extraction errors and ensure accuracy

### US-026: Import a recipe from a photo
**As a** user
**I want** to take a photo of a recipe (from a cookbook, magazine, or handwritten card) and have the app extract the recipe details
**So that** I can digitize physical recipes without manual data entry

## Acceptance Criteria

### Settings
- [ ] New "Import Recipe" section in SettingsView between "Display" and "Feedback"
- [ ] Provider picker (default and only option: "Claude (Anthropic)") — designed for future on-device model support
- [ ] Model picker with options dependent on provider; for Claude: Haiku, Sonnet, Opus (default: Sonnet)
- [ ] API key field uses secure text entry (masked input) — only shown for Claude provider
- [ ] API key is stored in the iOS Keychain, not UserDefaults or AppStorage
- [ ] "Verify Key" button sends a lightweight API call and shows success/failure — only shown for Claude provider
- [ ] Provider and model selections persist via AppStorage

### Import Flow (Website — existing)
- [ ] Tapping `+` shows a menu with "New Recipe", "Import from Website", and "Import from Photo" options
- [ ] "Import from Website" presents a sheet with a URL text field and "Import" button
- [ ] URL validation: reject empty or malformed URLs before sending to API
- [ ] Shows loading indicator with status text while calling API
- [ ] On success, opens RecipeFormView in `.add` mode pre-populated with extracted data
- [ ] On error, shows alert with error description and retry option
- [ ] Import is disabled when no API key is configured (shows guidance to visit Settings)

### Import Flow (Photo)
- [ ] "Import from Photo" presents a sheet with platform-appropriate options:
  - **iOS**: Camera button + Photo Library button (via `PhotosPicker`)
  - **macOS**: "Choose Files" button only (via `.fileImporter()`, opens Finder picker for image files)
- [ ] Camera option (iOS only) uses `UIImagePickerController` (via `UIViewControllerRepresentable`) with `.camera` source
- [ ] Photo library option (iOS only) uses `PhotosPicker` from PhotosUI framework with `maxSelectionCount: 5`
- [ ] **macOS only**: "Choose Files" button opens a Finder file picker (via `.fileImporter()`) allowing selection of image files (.jpg, .png, .heic, etc.) from disk
- [ ] File picker allows multiple selection, respecting the same 5-photo maximum
- [ ] Security-scoped resource access is used to read selected file URLs
- [ ] User can select multiple photos (up to 5) for multi-page recipes (e.g., cookbook spreads)
- [ ] Selected images are displayed as a scrollable row of thumbnails in the import sheet
- [ ] Each thumbnail has an "x" button to remove it
- [ ] A "+" button at the end of the thumbnail row allows adding more photos (from library or camera)
- [ ] User taps "Import Recipe" to send all images to Claude in a single API call
- [ ] Each image is resized individually if needed to stay within API size limits (max 5MB per image after base64 encoding)
- [ ] Shows loading indicator with "Extracting recipe from photo..." (or "...photos" if multiple) while calling API
- [ ] On success, opens RecipeFormView in `.add` mode pre-populated with extracted data
- [ ] On error, shows alert with error description and retry option
- [ ] Import is disabled when no API key is configured (shows guidance to visit Settings)
- [ ] User can add/remove/replace photos before importing

### API Integration
- [ ] **Website**: URL sent directly to the Anthropic Messages API — Claude fetches the page content via `web_fetch` tool
- [ ] **Photo**: Images sent as base64-encoded `image` content blocks in the user message (one block per photo) — no tools needed
- [ ] API request includes proper headers: `x-api-key`, `anthropic-version`, `content-type`
- [ ] Claude response parsed into recipe fields (title, description, tags, yields, ingredients, instructions)
- [ ] If Claude responds with `NOT_A_RECIPE`, show an appropriate error
- [ ] Any markdown image syntax (`![...](...)`) is stripped from the response before parsing
- [ ] No third-party dependencies — uses URLSession, PhotosUI, and Security framework only

## Technical Design

### Architecture

```
Core/Services/
├── KeychainService.swift              (existing) — Keychain CRUD wrapper
├── AnthropicAPIService.swift          (MODIFIED) — Add extractRecipeFromImage method

Features/Settings/Views/
├── SettingsView.swift                 (existing) — Import Recipe section already present

Features/RecipeList/Views/
├── RecipeListView.swift               (MODIFIED) — + menu adds "Import from Photo"
├── RecipeListSplitView.swift          (MODIFIED) — + menu adds "Import from Photo"

Features/Import/Views/
├── ImportRecipeView.swift             (MODIFIED) — Add photo import tab/mode
├── CameraView.swift                   (NEW) — UIImagePickerController wrapper

Features/Import/ViewModels/
├── ImportRecipeViewModel.swift        (MODIFIED) — Add photo import support
```

### AnthropicAPIService Changes (`Core/Services/AnthropicAPIService.swift`)

The existing `extractRecipeFromImage` method is updated to accept multiple images. Each image becomes a separate `image` content block in the messages array, followed by a single `text` block with the extraction prompt.

```swift
/// Extract a recipe from one or more photos by sending the images to Claude.
func extractRecipeFromImages(
    images: [(data: Data, mediaType: String)],
    apiKey: String,
    model: ClaudeModel,
    tagPrompt: String = ""
) async throws(APIError) -> String {
    let prompt = Self.buildPhotoPrompt(tagPrompt: tagPrompt)

    var contentBlocks: [[String: Any]] = images.map { image in
        [
            "type": "image",
            "source": [
                "type": "base64",
                "media_type": image.mediaType,
                "data": image.data.base64EncodedString()
            ] as [String: Any]
        ] as [String: Any]
    }
    contentBlocks.append([
        "type": "text",
        "text": prompt
    ])

    let body: [String: Any] = [
        "model": model.rawValue,
        "max_tokens": 8192,
        "messages": [
            ["role": "user", "content": contentBlocks] as [String: Any]
        ]
    ]

    return try await extractRecipeFromResponse(apiKey: apiKey, body: body)
}
```

The old single-image `extractRecipeFromImage` method is removed; callers wrap a single image in an array.

**Note**: No `tools` array is needed for photo import — images are sent directly as content.

#### Shared Extraction Prompt

Factor the recipe formatting instructions into a shared constant used by both methods. The preamble differs per source:

- **Website preamble**: `"Fetch the following URL and extract the recipe into structured markdown format:\n\n{url}\n\n"`
- **Photo preamble (single)**: `"Extract the recipe from this photo into structured markdown format.\n\n"`
- **Photo preamble (multiple)**: `"These photos show different parts of the same recipe (e.g., a multi-page cookbook spread). Combine them into a single complete recipe in structured markdown format.\n\n"`

The formatting instructions (steps 1–9, rules) remain identical:

```
Format the recipe with these exact specifications:
1. Title: Use H1 heading (single #)
2. Description: A brief 1-2 sentence description of the dish on the next line
3. Tags: On the next line, add italicized tags separated by commas (e.g., *asian, slow-cooker*)
4. Servings: Bold text showing servings and portion size (e.g., **6 Servings, 1.5 cups**)
5. Separator: Add a horizontal rule (---)
6. Ingredients List:
   * Each ingredient on its own line starting with a dash
   * Italicize quantities (e.g., *2 1/2 lb*, *1/2 c*, *1 T*)
   * Use slash fractions (1/2, 1/4, 3/4) instead of unicode fractions
   * Follow quantity with ingredient description
   * Maintain original measurements and abbreviations
   * Do not include a heading that says "Ingredients" for this section.
7. Separator: Add another horizontal rule (---)
8. Instructions:
   * Number each step
   * Use clear, sequential formatting
   * Maintain original wording and details
   * Do not include a heading that says "Instructions" for this section.
9. Attribution: If source information is provided, add it at the end in the format: "*Attribution:* [Author Name], [URL]"
Preserve all recipe details including ingredient amounts, cooking times, temperatures, and special notes. Format any garnishes, serving suggestions, or optional ingredients as separate ingredient lines.

Important rules:
- Do NOT include any images, image links, or markdown image syntax (![...](...)). The output must be plain text and markdown only.
- If the content does not contain a recipe, respond with exactly: NOT_A_RECIPE
- Do not attempt to fabricate a recipe from non-recipe content.
- Do NOT wrap your response in code fences. Output the raw markdown directly.

Output ONLY the recipe markdown, with no preamble or commentary.
```

#### APIError Update

Add a new error case for photo-specific issues:

```swift
case imageTooLarge  // "The image is too large. Try a smaller photo or lower resolution."
```

### ImportRecipeViewModel Changes

The view model changes from single-image state to multi-image state:

```swift
@MainActor
@Observable
class ImportRecipeViewModel {
    // ... ImportSource, ImportState enums unchanged ...

    var source: ImportSource = .website
    var urlText: String = ""
    var selectedImages: [(data: Data, mediaType: String)] = []  // was single selectedImageData
    var state: ImportState = .idle

    static let maxPhotos = 5

    var canAddMorePhotos: Bool {
        selectedImages.count < Self.maxPhotos
    }

    var statusMessage: String {
        switch state {
        case .extractingRecipe:
            if source == .website {
                return "Extracting recipe with Claude..."
            }
            return selectedImages.count > 1
                ? "Extracting recipe from \(selectedImages.count) photos..."
                : "Extracting recipe from photo..."
        default: return ""
        }
    }

    func addImage(_ image: UIImage) {
        guard canAddMorePhotos else { return }
        if let data = Self.resizeImageIfNeeded(image) {
            selectedImages.append((data: data, mediaType: "image/jpeg"))
        }
    }

    func removeImage(at index: Int) {
        selectedImages.remove(at: index)
    }

    private func importFromPhoto() async {
        guard !selectedImages.isEmpty else {
            state = .error("No photo selected.")
            return
        }
        // ... read key, call extractRecipeFromImages(images: selectedImages, ...), clean, validate
    }
}
```

#### Image Resizing

Before sending to the API, resize the image if it exceeds the size limit:

```swift
/// Resize a UIImage to fit within maxBytes when JPEG-encoded.
static func resizeImageIfNeeded(_ image: UIImage, maxBytes: Int = 3_750_000) -> Data? {
    // Start at 0.8 quality, step down until under limit
    var quality: CGFloat = 0.8
    while quality > 0.1 {
        if let data = image.jpegData(compressionQuality: quality),
           data.count <= maxBytes {
            return data
        }
        quality -= 0.1
    }

    // If still too large, scale down the image dimensions
    let scale = 0.5
    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let resized = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return resized?.jpegData(compressionQuality: 0.7)
}
```

### CameraView (`Features/Import/Views/CameraView.swift`)

A `UIViewControllerRepresentable` wrapper around `UIImagePickerController` for camera access:

```swift
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

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

### ImportRecipeView Changes

The view evolves from a single URL-input form into a two-tab interface supporting both import sources.

#### Entry Point: `+` Button Menu

Update the menu in `RecipeListView` and `RecipeListSplitView`:

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

Each menu item presents `ImportRecipeView` with the appropriate source pre-selected.

#### Updated Import Sheet

```
┌─────────────────────────────────────┐
│ Cancel    Import Recipe             │
├─────────────────────────────────────┤
│  ┌──────────┐ ┌──────────────────┐  │
│  │ Website  │ │  Photo           │  │  ← Segmented Picker
│  └──────────┘ └──────────────────┘  │
│                                     │
│  ─── When "Website" selected ───    │
│                                     │
│  Paste a recipe URL and Claude will │
│  extract the recipe for you.        │
│                                     │
│ URL                                 │
│ ┌─────────────────────────────────┐ │
│ │ https://example.com/recipe...   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │         Import Recipe           │ │
│ └─────────────────────────────────┘ │
│                                     │
│  ─── When "Photo" selected ──────   │
│                                     │
│  Take photos of a recipe or choose  │
│  from your library. Select multiple │
│  photos for multi-page recipes.     │
│                                     │
│ ┌───────┐ ┌───────┐ ┌───────┐      │
│ │ photo │ │ photo │ │  +    │      │  ← Scrollable thumbnail row
│ │   1   │ │   2   │ │ Add   │      │    with remove (x) buttons
│ │  (x)  │ │  (x)  │ │ More  │      │    and add-more button
│ └───────┘ └───────┘ └───────┘      │
│                                     │
│ ┌───────────┐  ┌────────────────┐  │
│ │  Camera   │  │ Photo Library  │  │  ← iOS only
│ └───────────┘  └────────────────┘  │
│                                     │
│ ┌──────────────────────────────┐   │
│ │        Choose Files          │   │  ← macOS only (Finder picker)
│ └──────────────────────────────┘   │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │         Import Recipe           │ │  ← Disabled until ≥1 photo
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

**States (Photo tab)**:
- **No photos**: Camera and Photo Library buttons shown (iOS); Choose Files button shown (macOS). Import button disabled.
- **Photos selected**: Thumbnail row displayed with remove buttons and "+" to add more (up to 5). Import button enabled.
- **Max photos reached**: "+" add-more button hidden. Camera/Library/Choose Files buttons still visible but disabled.
- **Extracting**: ProgressView + status text. Buttons disabled.
- **Success**: Sheet dismisses, `RecipeFormView` opens in `.add` mode with pre-populated fields.
- **Error**: Alert with error message and "Try Again" / "Cancel" actions.

**No API key state**: Same as website — inline message directing user to Settings.

### Pre-populating RecipeFormView

Identical to the existing website flow — no changes needed:

1. Parse the returned RecipeMD markdown with `RecipeMDParser` to get a `Recipe` object
2. Create a `RecipeFile` wrapper (with a temporary file path)
3. Create a `RecipeFormViewModel(mode: .add)`
4. Call `viewModel.populateFromRecipeFile(recipeFile)`
5. Present `RecipeFormView` with the pre-populated view model

## UI/UX Requirements

### Import Sheet Presentation
- Presented as a `.sheet` from the recipe list
- Dismissible via Cancel button or swipe-down
- If import is in progress, confirm before dismissing
- Source picker (segmented control) at the top switches between Website and Photo
- The sheet opens to the source matching the menu item tapped

### Loading States
- Website: "Extracting recipe with Claude..."
- Photo: "Extracting recipe from photo..."
- `ProgressView` (indeterminate spinner) shown during extraction

### Error Handling
- **Invalid URL**: Inline validation message below text field ("Please enter a valid URL")
- **No photo selected**: Import button is disabled (not an error state)
- **Image too large**: Alert — "The image is too large. Try a smaller photo or lower resolution."
- **Not a recipe (photo)**: Alert — "This photo doesn't appear to contain a recipe. Try a different photo."
- **Not a recipe (website)**: Alert — "This page doesn't appear to contain a recipe. Try a different URL."
- **API key missing**: Inline message with link to Settings (not an alert)
- **API key invalid (401)**: Alert — "Your API key is invalid. Update it in Settings."
- **Rate limited (429)**: Alert — "Rate limited. Please wait a moment and try again."
- **Network error**: Alert — "Network error contacting the Claude API."
- **API error (5xx)**: Alert — "The Claude API is temporarily unavailable. Try again later."
- **Extraction failure (bad markdown)**: Alert — "Could not extract a recipe. Try again with a different source."
- All error alerts include a "Try Again" button that returns to the input

### Camera Permissions
- The app must include `NSCameraUsageDescription` in Info.plist: "OpenCookbook uses the camera to photograph recipes for import."
- If camera permission is denied, hide the Camera button and only show Photo Library
- Photo library access uses `PhotosPicker` which uses the system's limited access picker (no permission prompt needed on iOS 17+)

### macOS File Picker
- On macOS, a "Choose Files" button opens a Finder file picker via SwiftUI's `.fileImporter()` modifier
- Allowed content types: `[.image]` (covers JPEG, PNG, HEIC, TIFF, etc.)
- Multiple selection enabled, respecting the 5-photo maximum
- Security-scoped resource access used to read selected file URLs
- Selected files feed into the same `addImage()` pipeline as PhotosPicker selections

### Settings Section
- No changes needed — the existing "Import Recipe" section already covers provider, model, and API key configuration

## Dependencies
- Existing `RecipeMDParser` — for parsing Claude's response
- Existing `RecipeFormViewModel.populateFromRecipeFile()` — for pre-filling the form
- Existing `RecipeFormView` — user reviews and saves via standard flow
- Existing `KeychainService` — for API key storage
- Existing `AnthropicAPIService` — extended with photo method
- `PhotosUI` framework — for `PhotosPicker`
- `UIKit` — for `UIImagePickerController` (camera)
- Security framework — for Keychain operations
- No new SPM dependencies

## Files Modified
| File | Change |
|------|--------|
| `Core/Services/AnthropicAPIService.swift` | **Modified** — Add `extractRecipeFromImage` method, factor out shared prompt |
| `Features/Import/Views/ImportRecipeView.swift` | **Modified** — Add segmented picker, photo selection UI, photo preview |
| `Features/Import/Views/CameraView.swift` | **New** — `UIViewControllerRepresentable` wrapper for camera |
| `Features/Import/ViewModels/ImportRecipeViewModel.swift` | **Modified** — Add `ImportSource`, photo import pipeline, image resizing |
| `Features/RecipeList/Views/RecipeListView.swift` | **Modified** — `+` menu adds "Import from Photo" |
| `Features/RecipeList/Views/RecipeListSplitView.swift` | **Modified** — `+` menu adds "Import from Photo" |
| `Info.plist` | **Modified** — Add `NSCameraUsageDescription` |

## Test Cases

### Photo Import

#### TC-079: Import recipe from camera photo
1. Configure API key in Settings
2. Tap `+` and select "Import from Photo"
3. Select the "Photo" tab
4. Tap "Camera" and take a photo of a recipe
5. Verify the photo preview appears in the import sheet
6. Tap "Import Recipe"
7. Verify loading state shows "Extracting recipe from photo..."
8. Verify RecipeFormView opens with pre-populated title, ingredients, and instructions
9. Verify all form fields are editable
10. Tap Save and verify recipe is saved successfully

#### TC-080: Import recipe from photo library (single photo)
1. Configure API key
2. Tap `+` and select "Import from Photo"
3. Tap "Photo Library" and select one photo of a recipe
4. Verify the photo thumbnail appears in the thumbnail row
5. Tap "Import Recipe"
6. Verify RecipeFormView opens with extracted recipe data

#### TC-080b: Import recipe from photo library (multiple photos)
1. Configure API key
2. Tap `+` and select "Import from Photo"
3. Tap "Photo Library" and select 2-3 photos of a multi-page recipe
4. Verify all selected photos appear as thumbnails
5. Tap "Import Recipe"
6. Verify loading text says "Extracting recipe from N photos..."
7. Verify RecipeFormView opens with a single combined recipe

#### TC-081: Add and remove photos before importing
1. Select 3 photos in the import sheet
2. Verify all 3 thumbnails are shown
3. Tap the "x" button on the middle thumbnail
4. Verify it is removed and 2 thumbnails remain
5. Tap "+" to add another photo
6. Verify 3 thumbnails are shown again
7. Import and verify the correct photos' recipe is extracted

#### TC-081b: Maximum photo limit
1. Select 5 photos (the maximum)
2. Verify the "+" add-more button is hidden
3. Remove one photo
4. Verify the "+" button reappears
5. Import succeeds with 4 photos

#### TC-082: Import from photo with no recipe content
1. Configure API key
2. Take a photo of something that is not a recipe (e.g., a landscape)
3. Tap "Import Recipe"
4. Verify error alert: "This photo doesn't appear to contain a recipe."
5. Verify "Try Again" returns to photo selection

#### TC-083: Import with oversized images
1. Configure API key
2. Select multiple very large images
3. Verify each image is automatically compressed/resized before sending
4. Verify the import still succeeds

#### TC-084: Import from photo with no API key
1. Ensure no API key is saved
2. Tap `+` and select "Import from Photo"
3. Verify the sheet shows a message directing the user to Settings
4. Verify the Import button is not shown

#### TC-085: Camera permission denied
1. Deny camera permission for the app
2. Tap `+` and select "Import from Photo"
3. Verify the Camera button is not shown
4. Verify Photo Library button still works

#### TC-085b: macOS — Import from files on disk
1. On macOS, configure API key
2. Tap `+` and select "Import from Photo"
3. Verify "Choose Files" button is shown
4. Verify Camera and Photo Library buttons are not shown
5. Click "Choose Files" and select 1-2 image files from Finder
6. Verify selected images appear as thumbnails
7. Tap "Import Recipe" and verify extraction succeeds

#### TC-085c: macOS — Choose Files respects photo limit
1. On macOS, select 4 images via "Choose Files"
2. Click "Choose Files" again and select 3 more images from Finder
3. Verify only 1 additional image is added (reaching the 5-photo max)
4. Verify "Choose Files" button becomes disabled

#### TC-086: Switch between Website and Photo tabs
1. Open import sheet (from either menu item)
2. Switch between Website and Photo tabs
3. Verify the correct input UI is shown for each tab
4. Verify state resets when switching tabs

### Website Import (existing — renumbered for completeness)

#### TC-064: Import recipe from valid URL
1. Configure API key in Settings
2. Tap `+` and select "Import from Website"
3. Paste a valid recipe URL
4. Tap "Import Recipe"
5. Verify loading state shows "Extracting recipe with Claude..."
6. Verify RecipeFormView opens with pre-populated title, ingredients, and instructions
7. Verify all form fields are editable
8. Tap Save and verify recipe is saved successfully

#### TC-065: Import with no API key configured
1. Ensure no API key is saved
2. Tap `+` and select "Import from Website"
3. Verify the sheet shows a message directing the user to Settings
4. Verify the Import button is not shown

#### TC-066: Import with invalid URL
1. Configure API key
2. Tap `+` and select "Import from Website"
3. Enter "not-a-url" in the URL field
4. Tap "Import Recipe"
5. Verify inline validation message: "Please enter a valid URL"

#### TC-067: Import with network error
1. Configure API key
2. Disable network connectivity
3. Tap `+` and select "Import from Website"
4. Enter URL and tap Import
5. Verify error alert about network error contacting Claude API
6. Verify "Try Again" button returns to URL input

#### TC-068: Import with invalid API key
1. Enter an invalid API key in Settings
2. Tap `+` and select "Import from Website"
3. Enter a valid recipe URL and tap Import
4. Verify error alert about invalid API key

#### TC-069: Import from non-recipe page
1. Configure API key
2. Import from a URL that has no recipe content (e.g., a news article)
3. Verify error alert: "This page doesn't appear to contain a recipe."
4. Verify "Try Again" button returns to URL input

#### TC-070: Cancel import in progress
1. Start an import (website or photo)
2. Tap Cancel while loading indicator is shown
3. Verify confirmation dialog appears
4. Confirm cancellation
5. Verify return to recipe list

### Settings (existing)

#### TC-071: Verify API key in Settings
1. Open Settings
2. Enter a valid API key
3. Tap "Verify Key"
4. Verify success indicator (checkmark) appears

#### TC-072: Verify invalid API key in Settings
1. Open Settings
2. Enter an invalid API key
3. Tap "Verify Key"
4. Verify error alert appears

#### TC-073: Model selection persistence
1. Open Settings
2. Change Claude model from Sonnet to Haiku
3. Close and reopen the app
4. Verify Haiku is still selected

### Menu / Navigation

#### TC-074: `+` button shows menu on iPhone
1. On iPhone, tap the `+` button in the recipe list toolbar
2. Verify a menu appears with "New Recipe", "Import from Website", and "Import from Photo"
3. Tap "New Recipe" and verify the recipe form opens (existing behavior)

#### TC-075: `+` button shows menu on iPad
1. On iPad, tap the `+` button in the sidebar toolbar
2. Verify a menu appears with "New Recipe", "Import from Website", and "Import from Photo"
3. Tap "Import from Photo" and verify the import sheet opens to the Photo tab

#### TC-076: Edit imported recipe before saving
1. Import a recipe (from website or photo)
2. In the pre-populated form, change the title and remove an ingredient
3. Tap Save
4. Verify the saved recipe reflects the edits, not the original extraction

#### TC-077: Imported recipe contains no images
1. Configure API key
2. Import from a source that might contain images
3. Verify the pre-populated form fields contain no markdown image syntax (`![...](...)`)
4. Save the recipe and verify the .md file contains no image references

#### TC-078: API key stored securely in Keychain
1. Enter an API key in Settings
2. Verify the key is not stored in UserDefaults (check with debug tools)
3. Verify the key is readable on next app launch

## Implementation Phases

### Phase 1: Multiple Photo Selection from Library (done)
- `PhotosPicker` with `maxSelectionCount: 5` for multi-select from photo library
- Thumbnail row UI with remove buttons and add-more capability
- API call sends all images as separate content blocks in one request
- Prompt adapts preamble based on single vs. multiple photos

### Phase 2: Multiple Camera Captures (done)
- After taking a photo with the camera, a review screen shows the captured photo with "Take Another" and "Done" buttons
- "Take Another" sends the photo to the parent and re-opens the camera picker for the next shot
- "Done" sends the photo and dismisses the camera
- "Take Another" is hidden when the remaining photo limit is reached
- Camera captures accumulate into the same `selectedImages` array as library picks
- User can mix camera captures and library selections
- `CameraView` refactored: `CameraPicker` (UIImagePickerController wrapper) handles capture; `CameraView` manages the review/re-capture loop

## Open Questions
- Should we support importing from the iOS Share Sheet (receiving photos from other apps)?
- Should we offer a crop/rotate UI before sending the photo, or send the full image as-is?

## Future Enhancements
- **Share Sheet Extension**: Accept URLs or photos from the iOS share sheet to trigger import flow
- **Batch import**: Import multiple recipes from a collection/index page
- **Import history**: Show a log of previously imported sources
- **Offline extraction**: Use on-device models for recipe extraction without an API key
- **OCR preprocessing**: Use Vision framework for local text extraction before sending to Claude for structuring
