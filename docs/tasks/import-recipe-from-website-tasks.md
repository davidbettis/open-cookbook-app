# Task Breakdown: Import Recipe from Website (F009)

**Spec**: [docs/specs/import-recipe-from-website.md](../specs/import-recipe-from-website.md)
**Priority**: P1

---

## Task 1: Create KeychainService

**Complexity**: Low
**Dependencies**: None

### Description
Create a thin wrapper around the Security framework for storing and retrieving the Anthropic API key in the iOS Keychain.

### Implementation Steps
1. Create `Core/Services/KeychainService.swift`
2. Define `KeychainError` enum with cases: `saveFailed(OSStatus)`, `readFailed(OSStatus)`, `deleteFailed(OSStatus)`, `unexpectedData`
3. Implement `save(key:value:)` — calls `SecItemAdd`; on `errSecDuplicateItem`, falls back to `SecItemUpdate`
4. Implement `read(key:)` — calls `SecItemCopyMatching` with `kSecReturnData`, returns `String?`
5. Implement `delete(key:)` — calls `SecItemDelete`
6. Use `kSecClassGenericPassword` with `kSecAttrService` set to `"com.opencookbook.api-keys"` and `kSecAttrAccount` set to the key parameter

### Code Example
```swift
import Security

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

    static func save(key: String, value: String) throws(KeychainError) {
        guard let data = value.data(using: .utf8) else { throw .unexpectedData }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        // Try update first, fall back to add
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw .saveFailed(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw .saveFailed(updateStatus)
        }
    }

    static func read(key: String) throws(KeychainError) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw .readFailed(status) }
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw .unexpectedData
        }
        return string
    }

    static func delete(key: String) throws(KeychainError) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .deleteFailed(status)
        }
    }
}
```

### Acceptance Criteria
- [ ] `KeychainService` struct is `Sendable` with static methods
- [ ] `save` creates or updates a Keychain item
- [ ] `read` returns the stored string or `nil` if not found
- [ ] `delete` removes the item (no error if not found)
- [ ] All methods use Swift 6 typed throws with `KeychainError`
- [ ] Service identifier is `"com.opencookbook.api-keys"`

---

## Task 2: Create AnthropicAPIService

**Complexity**: Medium
**Dependencies**: Task 1

### Description
Create the API client that sends a URL to the Anthropic Messages API and parses Claude's response into RecipeMD markdown. Claude fetches the web page content directly — the app only sends the URL in the prompt.

### Implementation Steps
1. Create `Core/Services/AnthropicAPIService.swift`
2. Define `ClaudeModel` enum with cases: `haiku`, `sonnet`, `opus` — each with raw model ID string and display name
3. Define `APIError` enum with cases: `noAPIKey`, `invalidResponse(statusCode: Int)`, `decodingError`, `networkError(underlying: Error)`, `rateLimited`, `invalidAPIKey`, `notARecipe`
4. Implement `extractRecipe(from url:, apiKey:, model:)`:
   - Build the prompt by interpolating `{url}` into the hardcoded prompt from the spec
   - POST to `https://api.anthropic.com/v1/messages` with headers: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
   - Request body: `model`, `max_tokens: 4096`, single user message with prompt
   - Parse JSON response, extract `content[0].text`
   - If text is `NOT_A_RECIPE`, throw `notARecipe`
   - Strip any markdown image syntax `![...](...)` from response
   - Return cleaned markdown string
5. Implement `verifyAPIKey(_:)`:
   - Send a minimal request (e.g., short message, `max_tokens: 1`)
   - Return `true` on success, throw appropriate error on failure
6. Map HTTP 401 → `invalidAPIKey`, 429 → `rateLimited`

### Code Example
```swift
import Foundation

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
        case notARecipe

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No API key configured. Add your key in Settings."
            case .invalidResponse(let code): return "API returned an error (HTTP \(code))."
            case .decodingError: return "Could not parse the API response."
            case .networkError: return "Network error contacting the Claude API."
            case .rateLimited: return "Rate limited. Please wait a moment and try again."
            case .invalidAPIKey: return "Your API key is invalid. Update it in Settings."
            case .notARecipe: return "This page doesn't appear to contain a recipe."
            }
        }
    }

    enum ClaudeModel: String, CaseIterable, Identifiable, Sendable {
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

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    /// Send a URL to Claude and get a recipe markdown string.
    func extractRecipe(
        from url: String,
        apiKey: String,
        model: ClaudeModel
    ) async throws(APIError) -> String {
        let prompt = Self.buildPrompt(url: url)
        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .networkError(underlying: error)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299: break
            case 401: throw .invalidAPIKey
            case 429: throw .rateLimited
            default: throw .invalidResponse(statusCode: http.statusCode)
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw .decodingError
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines) == "NOT_A_RECIPE" {
            throw .notARecipe
        }

        return Self.stripImageSyntax(text)
    }

    func verifyAPIKey(_ apiKey: String) async throws(APIError) -> Bool {
        // Send minimal request (max_tokens: 1) to validate the key
        // ...
        return true
    }

    /// Strip markdown image syntax `![...](...)` from text.
    static func stripImageSyntax(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"!\[.*?\]\(.*?\)"#,
            with: "",
            options: .regularExpression
        )
    }

    /// Build the extraction prompt with URL interpolated.
    static func buildPrompt(url: String) -> String {
        // Full prompt from spec with {url} interpolated
        """
        Visit the following URL and extract the recipe into structured markdown format:

        \(url)

        Format the recipe with these exact specifications:
        ...
        """
    }
}
```

### Acceptance Criteria
- [ ] `ClaudeModel` enum has haiku/sonnet/opus with correct model IDs and display names
- [ ] `extractRecipe` accepts only a URL string (no page content), builds prompt, POSTs to Messages API, parses response
- [ ] `NOT_A_RECIPE` sentinel detected and throws `notARecipe`
- [ ] Markdown image syntax `![...](...)` stripped from response
- [ ] HTTP 401 mapped to `invalidAPIKey`, 429 to `rateLimited`
- [ ] `verifyAPIKey` sends minimal request and validates key
- [ ] All methods use typed throws with `APIError`
- [ ] Hardcoded prompt matches spec exactly (interpolating `{url}`)

---

## Task 3: Add Import Recipe Section to Settings UI

**Complexity**: Medium
**Dependencies**: Tasks 1, 2

### Description
Add an "Import Recipe" section to SettingsView between the "Display" and "Feedback" sections. Include a Provider picker (future-proofed for on-device models), a model picker, API key field, and verify button.

### Implementation Steps
1. Modify `Features/Settings/Views/SettingsView.swift`
2. Add state properties:
   - `@AppStorage("importProvider") private var importProvider: String` — currently only "claude"
   - `@AppStorage("claudeModel") private var claudeModelRawValue: String`
   - `@State private var apiKey: String = ""`
   - `@State private var isVerifyingKey = false`, `keyVerified = false`
3. Add new `Section("Import Recipe")` between the "Display" section and `#if DEBUG` / "Feedback" section
4. In the section:
   - `Picker("Provider")` — currently one option "Claude (Anthropic)", designed so on-device models can be added later
   - `Picker("Model", selection: ...)` — options depend on selected provider; for Claude: Haiku, Sonnet, Opus
   - `SecureField("API Key", text: $apiKey)` — only shown when provider requires API key (Claude)
   - "Verify Key" `Button` — only shown for Claude provider
   - Footer: "Used for importing recipes from websites. Get a key at console.anthropic.com"
5. On `.onAppear`, load API key from `KeychainService.read(key: "anthropic-api-key")`
6. On `SecureField` submit, save to `KeychainService.save(key:value:)`

### Code Example
```swift
Section("Import Recipe") {
    Picker("Provider", selection: $importProvider) {
        Text("Claude (Anthropic)").tag("claude")
        // Future: Text("On-Device").tag("ondevice")
    }

    Picker("Model", selection: selectedModelBinding) {
        ForEach(AnthropicAPIService.ClaudeModel.allCases) { model in
            Text(model.displayName).tag(model)
        }
    }

    SecureField("API Key", text: $apiKey)
        .textContentType(.password)
        .onSubmit { saveAPIKey() }
        .onChange(of: apiKey) { _, _ in keyVerified = false }

    Button {
        Task { await verifyKey() }
    } label: {
        HStack {
            Text("Verify Key")
            Spacer()
            if isVerifyingKey {
                ProgressView().scaleEffect(0.8)
            } else if keyVerified {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
    .disabled(apiKey.isEmpty || isVerifyingKey)
} footer: {
    Text("Used for importing recipes from websites. Get a key at console.anthropic.com")
}
```

### Acceptance Criteria
- [ ] "Import Recipe" section appears between "Display" and "Feedback" sections
- [ ] Provider picker present with "Claude (Anthropic)" as default (designed for future on-device model support)
- [ ] Model picker options depend on selected provider; for Claude: Haiku, Sonnet, Opus
- [ ] `SecureField` loads API key from Keychain on appear; only shown for Claude provider
- [ ] API key saved to Keychain on submit
- [ ] Default model is Sonnet
- [ ] "Verify Key" button calls `verifyAPIKey()` and shows success/failure; only shown for Claude
- [ ] "Verify Key" disabled when API key is empty
- [ ] Provider and model selections persist via `@AppStorage`
- [ ] Footer text includes guidance about obtaining a key

---

## Task 4: Create ImportRecipeViewModel

**Complexity**: Medium
**Dependencies**: Tasks 1, 2

### Description
Create the view model that orchestrates the import pipeline: validate URL → call Claude API → parse the result. The app sends only the URL to Claude — no HTML fetching on the device.

### Implementation Steps
1. Create `Features/Import/ViewModels/ImportRecipeViewModel.swift`
2. Define `ImportState` enum: `idle`, `extractingRecipe`, `success(String)`, `error(String)`
3. Add published properties: `urlText: String`, `state: ImportState`
4. Add computed properties: `isImporting: Bool`, `statusMessage: String`, `hasAPIKey: Bool`
5. Implement `importRecipe() async`:
   - Validate URL format (guard against empty/malformed input, require http/https scheme)
   - Read API key from `KeychainService.read(key: "anthropic-api-key")`
   - Read model from `@AppStorage("claudeModel")` raw value
   - Set state to `.extractingRecipe`
   - Call `AnthropicAPIService().extractRecipe(from: urlText, apiKey:, model:)`
   - Validate result parses with `RecipeMDParser` (via `import RecipeMD`)
   - Set state to `.success(markdown)`
   - On any failure, set state to `.error(message)`

### Code Example
```swift
import RecipeMD
import SwiftUI

@MainActor
@Observable
class ImportRecipeViewModel {
    enum ImportState: Equatable {
        case idle
        case extractingRecipe
        case success(String)
        case error(String)
    }

    var urlText: String = ""
    var state: ImportState = .idle

    @ObservationIgnored
    @AppStorage("claudeModel") private var claudeModelRawValue: String = AnthropicAPIService.ClaudeModel.sonnet.rawValue

    var isImporting: Bool {
        if case .extractingRecipe = state { return true }
        return false
    }

    var statusMessage: String {
        switch state {
        case .extractingRecipe: return "Extracting recipe with Claude..."
        default: return ""
        }
    }

    var hasAPIKey: Bool {
        guard let key = try? KeychainService.read(key: "anthropic-api-key") else { return false }
        return key != nil && !key!.isEmpty
    }

    func importRecipe() async {
        guard let url = URL(string: urlText),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else {
            state = .error("Please enter a valid URL.")
            return
        }

        do {
            guard let apiKey = try KeychainService.read(key: "anthropic-api-key"), !apiKey.isEmpty else {
                state = .error("No API key configured. Add your key in Settings.")
                return
            }
            let model = AnthropicAPIService.ClaudeModel(rawValue: claudeModelRawValue) ?? .sonnet

            state = .extractingRecipe
            let service = AnthropicAPIService()
            let markdown = try await service.extractRecipe(
                from: urlText,
                apiKey: apiKey,
                model: model
            )

            // Validate it parses as RecipeMD
            let parser = RecipeMDParser()
            _ = try parser.parse(markdown)

            state = .success(markdown)
        } catch let error as AnthropicAPIService.APIError {
            state = .error(error.errorDescription ?? "An unknown error occurred.")
        } catch {
            state = .error("Could not extract a recipe from this page. Try a different URL.")
        }
    }
}
```

### Acceptance Criteria
- [ ] `@MainActor @Observable` class
- [ ] `ImportState` enum with four cases: `idle`, `extractingRecipe`, `success`, `error`
- [ ] URL validation rejects empty/malformed input and non-http(s) schemes
- [ ] Pipeline: validate URL → read API key → extract recipe via Claude → parse with RecipeMDParser
- [ ] Reads API key from Keychain, model from AppStorage
- [ ] Single loading state: `.extractingRecipe`
- [ ] All errors caught and converted to user-facing `.error(message)` state
- [ ] `hasAPIKey` computed property for checking key availability

---

## Task 5: Create ImportRecipeView

**Complexity**: Medium
**Dependencies**: Task 4

### Description
Create the import sheet UI with URL text field, loading state, error handling, and no-API-key guidance.

### Implementation Steps
1. Create `Features/Import/Views/ImportRecipeView.swift`
2. Accept `onImport: (String) -> Void` completion closure and `@Environment(\.dismiss)` for cancellation
3. Create `@State private var viewModel = ImportRecipeViewModel()`
4. Build sheet with `NavigationStack`:
   - Title: "Import Recipe"
   - Cancel button in toolbar (`.cancellationAction`)
5. Implement states:
   - **No API key**: Show message "Set up your API key in Settings to import recipes." Hide Import button.
   - **Idle**: URL `TextField` (`.url` keyboard type, `.autocapitalization(.none)`) and "Import Recipe" `Button` (disabled when URL is empty)
   - **Extracting**: `ProgressView` + "Extracting recipe with Claude..." text, Import button disabled
   - **Error**: `.alert` with error message, "Try Again" resets to idle, "Cancel" dismisses
   - **Success**: Call `onImport(markdown)` and dismiss

### Code Example
```swift
import SwiftUI

struct ImportRecipeView: View {
    let onImport: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ImportRecipeViewModel()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.hasAPIKey {
                    noAPIKeySection
                } else {
                    urlInputSection
                    if viewModel.isImporting {
                        loadingSection
                    }
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("Try Again") { viewModel.state = .idle }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: viewModel.state) { _, newState in
                switch newState {
                case .success(let markdown):
                    onImport(markdown)
                    dismiss()
                case .error(let message):
                    errorMessage = message
                    showError = true
                default:
                    break
                }
            }
        }
    }

    private var noAPIKeySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "key")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Set up your API key in Settings to import recipes.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private var urlInputSection: some View {
        Section {
            TextField("https://example.com/recipe", text: $viewModel.urlText)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                Task { await viewModel.importRecipe() }
            } label: {
                Text("Import Recipe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.urlText.isEmpty || viewModel.isImporting)
        } header: {
            Text("Paste a recipe URL and Claude will extract the recipe for you.")
        }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        }
    }
}
```

### Acceptance Criteria
- [ ] Sheet with NavigationStack and Cancel toolbar button
- [ ] URL text field with `.url` keyboard type
- [ ] Import button disabled when URL is empty or import in progress
- [ ] Single loading state shows ProgressView + "Extracting recipe with Claude..."
- [ ] No-API-key state shows guidance message, hides Import button
- [ ] Error alerts with "Try Again" (resets to idle) and "Cancel" (dismisses)
- [ ] On success: calls `onImport` completion with markdown string and dismisses

---

## Task 6: Update + Button Entry Points

**Complexity**: Low
**Dependencies**: Task 5

### Description
Replace the `+` button in `RecipeListView` and `RecipeListSplitView` with a `Menu` offering "New Recipe" and "Import from Website" options.

### Implementation Steps
1. Modify `Features/RecipeList/Views/RecipeListView.swift`:
   - Add `@State private var showImportRecipe = false`
   - Replace the `Button` in `ToolbarItem(placement: .primaryAction)` with a `Menu`
   - Menu contains "New Recipe" (existing `showAddRecipe = true`) and "Import from Website" (`showImportRecipe = true`)
   - Add `.sheet(isPresented: $showImportRecipe)` presenting `ImportRecipeView`
2. Repeat the same changes in `Features/RecipeList/Views/RecipeListSplitView.swift`

### Code Example
```swift
// Replace existing toolbar button (in both views):
ToolbarItem(placement: .primaryAction) {
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
    .accessibilityLabel("Add Recipe")
}

// Add sheet modifier:
.sheet(isPresented: $showImportRecipe) {
    ImportRecipeView { markdown in
        handleImportedRecipe(markdown)
    }
}
```

### Acceptance Criteria
- [ ] `+` button in `RecipeListView` shows menu with two options
- [ ] `+` button in `RecipeListSplitView` shows menu with two options
- [ ] "New Recipe" preserves existing behavior (opens RecipeFormView)
- [ ] "Import from Website" presents ImportRecipeView sheet
- [ ] Menu uses correct SF Symbols: `square.and.pencil` and `globe`

---

## Task 7: Wire Import Success to Pre-populated Recipe Form

**Complexity**: Medium
**Dependencies**: Task 6

### Description
Wire the import completion path in both list views to parse the returned markdown, create a pre-populated `RecipeFormViewModel`, and present the recipe form.

### Implementation Steps
1. In both `RecipeListView` and `RecipeListSplitView`, implement `handleImportedRecipe(_ markdown: String)`:
   - Parse markdown with `RecipeMDParser().parse(markdown)` to get a `Recipe` object
   - Create a temporary `RecipeFile` from the parsed recipe
   - Create `RecipeFormViewModel(mode: .add)` (uses existing `.add` mode)
   - Call `viewModel.populateFromRecipeFile(tempFile)` (existing method at `RecipeFormViewModel.swift:591`)
   - Set the populated view model and trigger `showAddRecipe = true` to present `RecipeFormView` via the existing `fullScreenCover`
2. Handle parse failures gracefully (show an alert if markdown is invalid)

### Code Example
```swift
private func handleImportedRecipe(_ markdown: String) {
    let parser = RecipeMDParser()
    do {
        let recipe = try parser.parse(markdown)
        let tempFile = RecipeFile(
            filePath: URL(filePath: "/tmp/imported-recipe.md"),
            recipe: recipe
        )
        let formVM = RecipeFormViewModel(mode: .add)
        formVM.populateFromRecipeFile(tempFile)
        importedFormViewModel = formVM
        showAddRecipe = true
    } catch {
        // Open blank form as fallback
        showAddRecipe = true
    }
}
```

### Notes
- The `fullScreenCover` uses `importedFormViewModel ?? RecipeFormViewModel(mode: .add)` so it works for both new and imported recipes.
- `importedFormViewModel` is cleared via `.onDisappear` on the fullScreenCover.
- `populateFromRecipeFile()` handles all fields: title, description, tags, yields, ingredients, and instructions.

### Acceptance Criteria
- [ ] Successful import parses markdown via `RecipeMDParser`
- [ ] Creates `RecipeFormViewModel(mode: .add)` and calls `populateFromRecipeFile`
- [ ] Pre-populated `RecipeFormView` opens in `.add` mode
- [ ] All form fields editable — user can review and save via existing flow
- [ ] Parse failures fall back gracefully
- [ ] Works in both `RecipeListView` (iPhone) and `RecipeListSplitView` (iPad)

---

## Task 8: Unit Tests

**Complexity**: Medium
**Dependencies**: Tasks 1–7

### Description
Write unit tests for the new services and view model using Swift Testing framework.

### Implementation Steps
1. Create `OpenCookbookTests/KeychainServiceTests.swift`:
   - Test save/read/delete round-trip
   - Test read returns `nil` for missing key
   - Test delete succeeds for non-existent key
   - Test overwrite (save same key twice)
2. Create `OpenCookbookTests/AnthropicAPIServiceTests.swift`:
   - Test `NOT_A_RECIPE` sentinel detection
   - Test markdown image syntax stripping via `stripImageSyntax()`
   - Test `ClaudeModel` raw values and display names
   - Test prompt construction (interpolation of URL)
3. Create `OpenCookbookTests/ImportRecipeViewModelTests.swift`:
   - Test URL validation (empty, malformed, valid http/https)
   - Test initial state is idle
   - Test `hasAPIKey` computed property
   - Test `isImporting` and `statusMessage` for each state

### Test Examples
```swift
import Testing
@testable import OpenCookbook

@Suite("KeychainService Tests")
struct KeychainServiceTests {
    @Test("Save and read round-trip")
    func saveAndRead() throws {
        try KeychainService.save(key: "test-key", value: "test-value")
        let result = try KeychainService.read(key: "test-key")
        #expect(result == "test-value")
        try KeychainService.delete(key: "test-key")
    }

    @Test("Read returns nil for missing key")
    func readMissing() throws {
        let result = try KeychainService.read(key: "nonexistent-key")
        #expect(result == nil)
    }

    @Test("Delete succeeds for non-existent key")
    func deleteNonExistent() throws {
        try KeychainService.delete(key: "nonexistent-key")
    }
}

@Suite("AnthropicAPIService Tests")
struct AnthropicAPIServiceTests {
    @Test("ClaudeModel has correct display names")
    func modelDisplayNames() {
        #expect(AnthropicAPIService.ClaudeModel.haiku.displayName == "Haiku (fastest)")
        #expect(AnthropicAPIService.ClaudeModel.sonnet.displayName == "Sonnet (balanced)")
        #expect(AnthropicAPIService.ClaudeModel.opus.displayName == "Opus (most capable)")
    }

    @Test("ClaudeModel has correct raw model IDs")
    func modelRawValues() {
        #expect(AnthropicAPIService.ClaudeModel.haiku.rawValue == "claude-haiku-4-5-20251001")
        #expect(AnthropicAPIService.ClaudeModel.sonnet.rawValue == "claude-sonnet-4-5-20250514")
        #expect(AnthropicAPIService.ClaudeModel.opus.rawValue == "claude-opus-4-5-20250514")
    }

    @Test("Image syntax stripped from response")
    func stripImageSyntax() {
        let input = "# Recipe\n![photo](https://example.com/img.jpg)\n- *1 cup* flour"
        let cleaned = AnthropicAPIService.stripImageSyntax(input)
        #expect(!cleaned.contains("!["))
        #expect(cleaned.contains("- *1 cup* flour"))
    }

    @Test("Prompt includes URL")
    func promptContainsURL() {
        let prompt = AnthropicAPIService.buildPrompt(url: "https://example.com/recipe")
        #expect(prompt.contains("https://example.com/recipe"))
        #expect(prompt.contains("NOT_A_RECIPE"))
    }
}

@Suite("ImportRecipeViewModel Tests")
struct ImportRecipeViewModelTests {
    @Test("Initial state is idle")
    func initialState() {
        let vm = ImportRecipeViewModel()
        #expect(vm.state == .idle)
        #expect(vm.urlText == "")
        #expect(vm.isImporting == false)
    }

    @Test("statusMessage empty when idle")
    func statusMessageIdle() {
        let vm = ImportRecipeViewModel()
        #expect(vm.statusMessage == "")
    }
}
```

### Acceptance Criteria
- [ ] KeychainService save/read/delete tests pass
- [ ] `NOT_A_RECIPE` detection test passes
- [ ] Image syntax stripping test passes
- [ ] `ClaudeModel` enum tests pass (display names and raw values)
- [ ] Prompt construction test passes (URL interpolated, sentinel instruction present)
- [ ] URL validation tests pass
- [ ] ImportRecipeViewModel state tests pass
- [ ] All tests use Swift Testing framework (`@Test`, `#expect`, `@Suite`)

---

## Summary

| Task | Complexity | Dependencies | Status |
|------|------------|--------------|--------|
| 1. KeychainService | Low | None | Pending |
| 2. AnthropicAPIService | Medium | Task 1 | Pending |
| 3. Settings UI — Import Recipe Section | Medium | Tasks 1, 2 | Pending |
| 4. ImportRecipeViewModel | Medium | Tasks 1, 2 | Pending |
| 5. ImportRecipeView | Medium | Task 4 | Pending |
| 6. Update + Button Entry Points | Low | Task 5 | Pending |
| 7. Integration & Pre-population Wiring | Medium | Task 6 | Pending |
| 8. Unit Tests | Medium | Tasks 1–7 | Pending |

**Implementation Order**: 1 → 2 → 3 + 4 (parallel) → 5 → 6 → 7 → 8

**Critical Path**: Tasks 1, 2, 4, 5, 6, 7 are required for end-to-end import functionality.

**Key changes from previous version**:
- Removed WebPageFetcher — Claude fetches the page content directly from the URL
- Simplified `ImportState` to 4 cases (removed `fetchingPage`)
- Single loading state: "Extracting recipe with Claude..."
- `extractRecipe` now takes only a URL string, not page content
- Settings section renamed to "Import Recipe" with Provider picker for future on-device model support

**Verification**:
- Build with XcodeBuildMCP after each task
- Run tests with XcodeBuildMCP after Task 8
- Manual test: paste a real recipe URL, verify extraction and form pre-population
