# Feature Spec: Import Recipe from Website

**Priority**: P1
**Feature ID**: F009

## Description
Import recipes from websites by pasting a URL, sending it to the Anthropic Messages API (Claude), and pre-filling the recipe form with the extracted data. Claude fetches and processes the web page content directly — the app only sends the URL, not the HTML. The user reviews and edits the recipe in the existing form before saving. Users provide their own Anthropic API key, stored securely in the iOS Keychain.

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

## Acceptance Criteria

### Settings
- [ ] New "Import Recipe" section in SettingsView between "Display" and "Feedback"
- [ ] Provider picker (default and only option: "Claude (Anthropic)") — designed for future on-device model support
- [ ] Model picker with options dependent on provider; for Claude: Haiku, Sonnet, Opus (default: Sonnet)
- [ ] API key field uses secure text entry (masked input) — only shown for Claude provider
- [ ] API key is stored in the iOS Keychain, not UserDefaults or AppStorage
- [ ] "Verify Key" button sends a lightweight API call and shows success/failure — only shown for Claude provider
- [ ] Provider and model selections persist via AppStorage

### Import Flow
- [ ] Tapping `+` shows a menu with "New Recipe" and "Import from Website" options
- [ ] "Import from Website" presents a sheet with a URL text field and "Import" button
- [ ] URL validation: reject empty or malformed URLs before sending to API
- [ ] Shows loading indicator with status text while calling API
- [ ] On success, opens RecipeFormView in `.add` mode pre-populated with extracted data
- [ ] On error, shows alert with error description and retry option
- [ ] Import is disabled when no API key is configured (shows guidance to visit Settings)

### API Integration
- [ ] URL sent directly to the Anthropic Messages API — Claude fetches the page content
- [ ] API request includes proper headers: `x-api-key`, `anthropic-version`, `content-type`
- [ ] Claude response parsed into recipe fields (title, description, tags, yields, ingredients, instructions)
- [ ] If Claude responds with `NOT_A_RECIPE`, show an error: "This page doesn't appear to contain a recipe."
- [ ] Any markdown image syntax (`![...](...)`) is stripped from the response before parsing
- [ ] No third-party dependencies — uses URLSession and Security framework only

## Technical Design

### Architecture

This feature introduces two new services and modifies the recipe list entry point:

```
Core/Services/
├── KeychainService.swift          (NEW) — Keychain CRUD wrapper
├── AnthropicAPIService.swift      (NEW) — Messages API client

Features/Settings/Views/
├── SettingsView.swift             (MODIFIED) — Add Import Recipe section

Features/RecipeList/Views/
├── RecipeListView.swift           (MODIFIED) — + button shows menu
├── RecipeListSplitView.swift      (MODIFIED) — + button shows menu

Features/Import/Views/
├── ImportRecipeView.swift         (NEW) — URL input sheet

Features/Import/ViewModels/
├── ImportRecipeViewModel.swift    (NEW) — Import orchestration
```

### KeychainService (`Core/Services/KeychainService.swift`)

A thin wrapper around the Security framework for storing the API key.

```swift
struct KeychainService: Sendable {
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status): return "Keychain save failed: \(status)"
            case .readFailed(let status): return "Keychain read failed: \(status)"
            case .deleteFailed(let status): return "Keychain delete failed: \(status)"
            case .unexpectedData: return "Unexpected keychain data format"
            }
        }
    }

    private static let service = "com.opencookbook.api-keys"

    /// Save a string value to the Keychain
    static func save(key: String, value: String) throws(KeychainError) { ... }

    /// Read a string value from the Keychain
    static func read(key: String) throws(KeychainError) -> String? { ... }

    /// Delete a value from the Keychain
    static func delete(key: String) throws(KeychainError) { ... }
}
```

**Implementation notes**:
- Uses `kSecClassGenericPassword` with `kSecAttrService` and `kSecAttrAccount`
- `save` calls `SecItemAdd`; if the item already exists (`errSecDuplicateItem`), calls `SecItemUpdate`
- `read` calls `SecItemCopyMatching` with `kSecReturnData`
- `delete` calls `SecItemDelete`
- All methods use Swift 6 typed throws

### AnthropicAPIService (`Core/Services/AnthropicAPIService.swift`)

Calls the Anthropic Messages API to extract recipe data from a URL. Claude fetches the web page content directly — the app only sends the URL in the prompt.

```swift
@MainActor
@Observable
class AnthropicAPIService {
    enum APIError: LocalizedError {
        case noAPIKey
        case invalidResponse(statusCode: Int)
        case decodingError
        case networkError(underlying: Error)
        case rateLimited
        case invalidAPIKey

        var errorDescription: String? { ... }
    }

    /// Available Claude models
    enum ClaudeModel: String, CaseIterable, Identifiable {
        case haiku = "claude-haiku-4-5-20251001"
        case sonnet = "claude-sonnet-4-5-20250514"
        case opus = "claude-opus-4-5-20250514"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .haiku: return "Haiku (fastest)"
            case .sonnet: return "Sonnet (balanced)"
            case .opus: return "Opus (most capable)"
            }
        }
    }

    /// Send a URL to Claude and get a recipe markdown string
    func extractRecipe(
        from url: String,
        apiKey: String,
        model: ClaudeModel
    ) async throws(APIError) -> String { ... }

    /// Verify the API key with a minimal request
    func verifyAPIKey(_ apiKey: String) async throws(APIError) -> Bool { ... }
}
```

**API request structure**:
```json
{
  "model": "<selected-model-id>",
  "max_tokens": 4096,
  "messages": [
    {
      "role": "user",
      "content": "<prompt with URL>"
    }
  ]
}
```

**Headers**:
- `x-api-key: <user's API key>`
- `anthropic-version: 2023-06-01`
- `content-type: application/json`

**Claude prompt**:
```
Visit the following URL and extract the recipe into structured markdown format:

{url}

Format the recipe with these exact specifications:
1. Title: Use H1 heading (single #)
2. Tags: On the next line, add italicized tags separated by commas (e.g., asian, slow-cooker)
3. Servings: Bold text showing servings and portion size (e.g., ** 6 Servings, 1.5 cups **)
4. Separator: Add a horizontal rule (---)
5. Ingredients List:
   * Each ingredient on its own line starting with a dash
   * Italicize quantities (e.g., 2½ lb, ½ c, 1 T)
   * Follow quantity with ingredient description
   * Maintain original measurements and abbreviations
   * Do not include a heading that says "Ingredients" for this section.
6. Separator: Add another horizontal rule (---)
7. Instructions:
   * Number each step
   * Use clear, sequential formatting
   * Maintain original wording and details
   * Do not include a heading that says "Instructions" for this section.
8. Attribution: If source information is provided, add it at the end in the format: "*Attribution:* [Author Name], [URL]"
Preserve all recipe details including ingredient amounts, cooking times, temperatures, and special notes. Format any garnishes, serving suggestions, or optional ingredients as separate ingredient lines.

Important rules:
- Do NOT include any images, image links, or markdown image syntax (![...](...)). The output must be plain text and markdown only.
- If the page does not contain a recipe, respond with exactly: NOT_A_RECIPE
- Do not attempt to fabricate a recipe from non-recipe content.

Display in raw markdown format.
```

**Note**: `{url}` is interpolated at runtime. The prompt is hardcoded in the app, not user-editable.

**Response parsing**:
- Extract the `content[0].text` field from the API JSON response
- If the response text is exactly `NOT_A_RECIPE`, treat it as a non-recipe page error
- Strip any markdown image syntax (`![...](...)`) from the response as a safety net, in case the model includes images despite the prompt instruction
- The remaining text is expected to be valid RecipeMD markdown
- Pass the markdown string directly to `RecipeFormViewModel.populateFromRecipeFile()` after parsing with `RecipeMDParser`

### ImportRecipeViewModel (`Features/Import/ViewModels/ImportRecipeViewModel.swift`)

Orchestrates the import flow: validate URL → call Claude API → parse result.

```swift
@MainActor
@Observable
class ImportRecipeViewModel {
    enum ImportState: Equatable {
        case idle
        case extractingRecipe
        case success(String)  // RecipeMD markdown
        case error(String)    // Error message
    }

    var urlText: String = ""
    var state: ImportState = .idle

    var isImporting: Bool { ... }
    var statusMessage: String { ... }

    /// Run the full import pipeline
    func importRecipe() async { ... }
}
```

**Import pipeline**:
1. Validate URL format (guard against empty/malformed input)
2. Read API key from Keychain, read model from AppStorage
3. Set state to `.extractingRecipe`
4. Call `AnthropicAPIService.extractRecipe(from:apiKey:model:)` with the URL string
5. Parse the returned markdown with `RecipeMDParser` to verify it's valid
6. Set state to `.success(markdown)` with the RecipeMD string
7. On any failure, set state to `.error(message)`

### Settings Integration

Add a new "Import Recipe" section to `SettingsView.swift`:

```
┌─────────────────────────────────────┐
│ Import Recipe                       │
│                                     │
│ Provider                            │
│ ┌─────────────────────────────────┐ │
│ │ Claude (Anthropic)          ▾  │ │  ← Picker (future: On-Device)
│ └─────────────────────────────────┘ │
│                                     │
│ Model                               │
│ ┌─────────────────────────────────┐ │
│ │ Sonnet (balanced)           ▾  │ │  ← Picker (options depend on provider)
│ └─────────────────────────────────┘ │
│                                     │
│ API Key                             │
│ ┌─────────────────────────────────┐ │
│ │ ••••••••••••••••••••           │ │  ← SecureField (only for Claude)
│ └─────────────────────────────────┘ │
│                                     │
│ [Verify Key]                        │  ← Button (only for Claude)
│                                     │
│ Used for importing recipes from     │
│ websites. Get a key at              │
│ console.anthropic.com               │
└─────────────────────────────────────┘
```

**Behavior**:
- Provider picker with `@AppStorage("importProvider")` — currently only "Claude (Anthropic)", designed so on-device models can be added later
- Model picker options change based on selected provider
- API key fields only shown when provider requires an API key (i.e., Claude)
- On appear, load API key from Keychain into a `@State` variable
- On text field commit / focus loss, save to Keychain
- Model selection stored via `@AppStorage("claudeModel")`
- "Verify Key" button calls `AnthropicAPIService.verifyAPIKey()`; shows checkmark on success, alert on failure
- Footer text includes a note about where to obtain an API key

### Import Flow UI

#### Entry Point: `+` Button Menu

Replace the current `+` button action in `RecipeListView` and `RecipeListSplitView` with a `Menu`:

```swift
Menu {
    Button {
        showAddRecipe = true
    } label: {
        Label("New Recipe", systemImage: "square.and.pencil")
    }
    Button {
        showImportRecipe = true
    } label: {
        Label("Import from Website", systemImage: "globe")
    }
} label: {
    Image(systemName: "plus")
}
```

#### Import Sheet: `ImportRecipeView`

```
┌─────────────────────────────────────┐
│ Cancel    Import Recipe             │
├─────────────────────────────────────┤
│                                     │
│  Paste a recipe URL and Claude will │
│  extract the recipe for you.        │
│                                     │
│ URL                                 │
│ ┌─────────────────────────────────┐ │
│ │ https://example.com/recipe...   │ │  ← TextField, .url keyboard
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │         Import Recipe           │ │  ← Button (disabled until valid URL)
│ └─────────────────────────────────┘ │
│                                     │
│       Extracting recipe...           │  ← Status text (during import)
│       ◌                             │  ← ProgressView (during import)
│                                     │
└─────────────────────────────────────┘
```

**States**:
- **Idle**: URL text field and Import button shown. Button disabled if URL is empty.
- **Extracting recipe**: ProgressView + "Extracting recipe with Claude..." text. Button disabled.
- **Success**: Sheet dismisses, `RecipeFormView` opens in `.add` mode with pre-populated fields.
- **Error**: Alert with error message and "Try Again" / "Cancel" actions.

**No API key state**: If no API key is stored, show an inline message: "Set up your API key in Settings to import recipes." with a button/link to Settings. The Import button is hidden.

### Pre-populating RecipeFormView

On successful import:

1. Parse the returned RecipeMD markdown with `RecipeMDParser` to get a `Recipe` object
2. Create a `RecipeFile` wrapper (with a temporary file path)
3. Create a `RecipeFormViewModel(mode: .add)`
4. Call `viewModel.populateFromRecipeFile(recipeFile)` — this method already exists and handles populating all form fields
5. Present `RecipeFormView` with the pre-populated view model

The user can then review, edit, and save the recipe using the existing form flow. No changes to `RecipeFormView` or the save flow are needed.

## UI/UX Requirements

### Import Sheet Presentation
- Presented as a `.sheet` from the recipe list
- Dismissible via Cancel button or swipe-down
- If import is in progress, confirm before dismissing

### Loading States
- Single-phase loading indicator: "Extracting recipe with Claude..." while waiting for API response
- `ProgressView` (indeterminate spinner) shown during extraction

### Error Handling
- **Invalid URL**: Inline validation message below text field ("Please enter a valid URL")
- **API key missing**: Inline message with link to Settings (not an alert)
- **API key invalid (401)**: Alert — "Your API key is invalid. Update it in Settings."
- **Rate limited (429)**: Alert — "Rate limited. Please wait a moment and try again."
- **Network error**: Alert — "Network error contacting the Claude API."
- **API error (5xx)**: Alert — "The Claude API is temporarily unavailable. Try again later."
- **Not a recipe page**: Alert — "This page doesn't appear to contain a recipe. Try a different URL."
- **Extraction failure (bad markdown)**: Alert — "Could not extract a recipe from this page. Try a different URL."
- All error alerts include a "Try Again" button that returns to the URL input

### Settings Section Placement
- The "Import Recipe" section appears between "Display" and "Feedback" sections in SettingsView

## Dependencies
- Existing `RecipeMDParser` — for parsing Claude's response
- Existing `RecipeFormViewModel.populateFromRecipeFile()` — for pre-filling the form
- Existing `RecipeFormView` — user reviews and saves via standard flow
- Security framework — for Keychain operations
- No new SPM dependencies

## Files Modified
| File | Change |
|------|--------|
| `Core/Services/KeychainService.swift` | **New** — Keychain CRUD wrapper |
| `Core/Services/AnthropicAPIService.swift` | **New** — Anthropic Messages API client |
| `Features/Import/Views/ImportRecipeView.swift` | **New** — URL input sheet |
| `Features/Import/ViewModels/ImportRecipeViewModel.swift` | **New** — Import orchestration |
| `Features/Settings/Views/SettingsView.swift` | **Modified** — Add Import Recipe section |
| `Features/RecipeList/Views/RecipeListView.swift` | **Modified** — `+` button becomes Menu |
| `Features/RecipeList/Views/RecipeListSplitView.swift` | **Modified** — `+` button becomes Menu |

## Test Cases

### TC-064: Import recipe from valid URL
1. Configure API key in Settings
2. Tap `+` and select "Import from Website"
3. Paste a valid recipe URL
4. Tap "Import Recipe"
5. Verify loading state shows "Extracting recipe with Claude..."
6. Verify RecipeFormView opens with pre-populated title, ingredients, and instructions
7. Verify all form fields are editable
8. Tap Save and verify recipe is saved successfully

### TC-065: Import with no API key configured
1. Ensure no API key is saved
2. Tap `+` and select "Import from Website"
3. Verify the sheet shows a message directing the user to Settings
4. Verify the Import button is not shown

### TC-066: Import with invalid URL
1. Configure API key
2. Tap `+` and select "Import from Website"
3. Enter "not-a-url" in the URL field
4. Tap "Import Recipe"
5. Verify inline validation message: "Please enter a valid URL"

### TC-067: Import with network error
1. Configure API key
2. Disable network connectivity
3. Tap `+` and select "Import from Website"
4. Enter URL and tap Import
5. Verify error alert about network error contacting Claude API
6. Verify "Try Again" button returns to URL input

### TC-068: Import with invalid API key
1. Enter an invalid API key in Settings
2. Tap `+` and select "Import from Website"
3. Enter a valid recipe URL and tap Import
4. Verify error alert about invalid API key

### TC-069: Import from non-recipe page
1. Configure API key
2. Import from a URL that has no recipe content (e.g., a news article)
3. Verify error alert: "This page doesn't appear to contain a recipe."
4. Verify "Try Again" button returns to URL input

### TC-070: Cancel import in progress
1. Start an import
2. Tap Cancel while loading indicator is shown
3. Verify confirmation dialog appears
4. Confirm cancellation
5. Verify return to recipe list

### TC-071: Verify API key in Settings
1. Open Settings
2. Enter a valid API key
3. Tap "Verify Key"
4. Verify success indicator (checkmark) appears

### TC-072: Verify invalid API key in Settings
1. Open Settings
2. Enter an invalid API key
3. Tap "Verify Key"
4. Verify error alert appears

### TC-073: Model selection persistence
1. Open Settings
2. Change Claude model from Sonnet to Haiku
3. Close and reopen the app
4. Verify Haiku is still selected

### TC-074: `+` button shows menu on iPhone
1. On iPhone, tap the `+` button in the recipe list toolbar
2. Verify a menu appears with "New Recipe" and "Import from Website"
3. Tap "New Recipe" and verify the recipe form opens (existing behavior)

### TC-075: `+` button shows menu on iPad
1. On iPad, tap the `+` button in the sidebar toolbar
2. Verify a menu appears with "New Recipe" and "Import from Website"
3. Tap "Import from Website" and verify the import sheet opens

### TC-076: Edit imported recipe before saving
1. Import a recipe from a website
2. In the pre-populated form, change the title and remove an ingredient
3. Tap Save
4. Verify the saved recipe reflects the edits, not the original extraction

### TC-077: Imported recipe contains no images
1. Configure API key
2. Import from a recipe URL whose web page contains images
3. Verify the pre-populated form fields contain no markdown image syntax (`![...](...)`)
4. Save the recipe and verify the .md file contains no image references

### TC-078: API key stored securely in Keychain
1. Enter an API key in Settings
2. Verify the key is not stored in UserDefaults (check with debug tools)
3. Verify the key is readable on next app launch

## Open Questions
- Should we support pasting content directly (clipboard text) in addition to URLs?
- Should the Claude prompt be user-editable in Settings for advanced users?
- Rate limiting: should we add client-side throttling to avoid hitting API limits?

## Future Enhancements
- **Share Sheet Extension**: Accept URLs from Safari share sheet to trigger import flow (separate spec)
- **Batch import**: Import multiple recipes from a collection/index page
- **Import history**: Show a log of previously imported URLs
- **Offline extraction**: Use on-device models for recipe extraction without an API key
