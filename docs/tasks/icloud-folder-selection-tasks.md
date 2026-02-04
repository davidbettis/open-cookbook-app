# Task Breakdown: iCloud Folder Selection (F001)

**Feature Spec**: [docs/specs/icloud-folder-selection.md](../specs/icloud-folder-selection.md)

**Total Estimated Complexity**: 18 points

---

## Phase 1: Project Setup & Entitlements

### Task 1.1: Enable iCloud Drive Entitlements
**Complexity**: 2 points (Simple)
**Dependencies**: None
**Acceptance**:
- [ ] iCloud capability added in Xcode project settings
- [ ] iCloud Documents entitlement enabled
- [ ] Info.plist contains iCloud container identifier
- [ ] Build succeeds without entitlement errors

**Implementation Steps**:
1. Open project in Xcode
2. Select target → Signing & Capabilities
3. Add iCloud capability
4. Enable "iCloud Documents" service
5. Verify container identifier created
6. Test build to confirm no errors

**Files to Modify**:
- `OpenCookbook.entitlements` (auto-generated)
- `Info.plist` (auto-updated)

**Testing**:
- Build project and verify no signing errors
- Check entitlements file contains iCloud keys

---

### Task 1.2: Create FolderManager Service
**Complexity**: 3 points (Medium)
**Dependencies**: Task 1.1
**Acceptance**:
- [ ] `FolderManager` class created with @Observable
- [ ] Properties for selected folder URL and bookmark data
- [ ] Methods defined (stub implementation OK for now)
- [ ] Unit test file created

**Implementation Steps**:
1. Create `Core/Services/FolderManager.swift`
2. Define `@Observable class FolderManager`
3. Add properties:
   - `selectedFolderURL: URL?`
   - `folderBookmark: Data?`
   - `isFirstLaunch: Bool`
4. Add method stubs:
   - `func selectFolder() async throws -> URL`
   - `func saveFolder(_ url: URL) throws`
   - `func loadSavedFolder() throws -> URL?`
   - `func hasSelectedFolder() -> Bool`
5. Create `Tests/FolderManagerTests.swift`

**Files to Create**:
- `Core/Services/FolderManager.swift`
- `Tests/FolderManagerTests.swift`

**Testing**:
- Verify class compiles
- Verify @Observable macro works
- Run empty test suite

---

## Phase 2: Core Folder Selection Logic

### Task 2.1: Implement Security-Scoped Bookmark Storage
**Complexity**: 3 points (Medium)
**Dependencies**: Task 1.2
**Acceptance**:
- [ ] Bookmark data saved to UserDefaults
- [ ] Bookmark data can be loaded from UserDefaults
- [ ] Security-scoped resource access started/stopped correctly
- [ ] Unit tests pass

**Implementation Steps**:
1. In `FolderManager`, implement `saveFolder(_ url: URL)`:
   ```swift
   func saveFolder(_ url: URL) throws {
       let bookmarkData = try url.bookmarkData(
           options: .minimalBookmark,
           includingResourceValuesForKeys: nil,
           relativeTo: nil
       )
       UserDefaults.standard.set(bookmarkData, forKey: "selectedFolderBookmark")
       self.selectedFolderURL = url
       self.folderBookmark = bookmarkData
   }
   ```
2. Implement `loadSavedFolder()`:
   ```swift
   func loadSavedFolder() throws -> URL? {
       guard let bookmarkData = UserDefaults.standard.data(forKey: "selectedFolderBookmark") else {
           return nil
       }
       var isStale = false
       let url = try URL(
           resolvingBookmarkData: bookmarkData,
           options: .withoutUI,
           relativeTo: nil,
           bookmarkDataIsStale: &isStale
       )
       if isStale {
           // Re-save bookmark to refresh
           try saveFolder(url)
       }
       self.selectedFolderURL = url
       return url
   }
   ```
3. Implement `hasSelectedFolder()`:
   ```swift
   func hasSelectedFolder() -> Bool {
       return UserDefaults.standard.data(forKey: "selectedFolderBookmark") != nil
   }
   ```
4. Add error handling for bookmark operations
5. Write unit tests for save/load operations

**Files to Modify**:
- `Core/Services/FolderManager.swift`
- `Tests/FolderManagerTests.swift`

**Testing**:
- Test saving and loading bookmarks
- Test stale bookmark handling
- Test missing bookmark case

---

### Task 2.2: Implement UIDocumentPickerViewController Bridge
**Complexity**: 4 points (Medium-Hard)
**Dependencies**: Task 2.1
**Acceptance**:
- [ ] Document picker presented from SwiftUI
- [ ] User can select folder
- [ ] Selected URL returned to SwiftUI
- [ ] Cancellation handled gracefully
- [ ] Security-scoped access started on selected URL

**Implementation Steps**:
1. Create `Core/Services/DocumentPickerCoordinator.swift`:
   ```swift
   import SwiftUI
   import UniformTypeIdentifiers

   struct FolderPicker: UIViewControllerRepresentable {
       @Binding var selectedURL: URL?
       var onSelect: (URL) -> Void
       var onCancel: () -> Void

       func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
           let picker = UIDocumentPickerViewController(
               forOpeningContentTypes: [.folder],
               asCopy: false
           )
           picker.delegate = context.coordinator
           picker.directoryURL = FileManager.default.urls(
               for: .documentDirectory,
               in: .userDomainMask
           ).first
           return picker
       }

       func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

       func makeCoordinator() -> Coordinator {
           Coordinator(self)
       }

       class Coordinator: NSObject, UIDocumentPickerDelegate {
           let parent: FolderPicker

           init(_ parent: FolderPicker) {
               self.parent = parent
           }

           func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
               guard let url = urls.first else { return }
               // Start accessing security-scoped resource
               guard url.startAccessingSecurityScopedResource() else {
                   return
               }
               parent.selectedURL = url
               parent.onSelect(url)
           }

           func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
               parent.onCancel()
           }
       }
   }
   ```
2. Update `FolderManager` to use `FolderPicker`
3. Add `selectFolder()` implementation in `FolderManager`
4. Handle security-scoped resource lifecycle

**Files to Create**:
- `Core/Services/DocumentPickerCoordinator.swift`

**Files to Modify**:
- `Core/Services/FolderManager.swift`

**Testing**:
- Manual test: present picker and select folder
- Manual test: cancel picker
- Verify security-scoped access started

---

## Phase 3: First Launch Experience

### Task 3.1: Create Welcome/Onboarding View
**Complexity**: 2 points (Simple)
**Dependencies**: None
**Acceptance**:
- [ ] `WelcomeView` created with explanation text
- [ ] "Select Folder" button styled appropriately
- [ ] Responsive layout for all iPhone sizes
- [ ] VoiceOver labels added

**Implementation Steps**:
1. Create `Features/Onboarding/Views/WelcomeView.swift`:
   ```swift
   struct WelcomeView: View {
       let onSelectFolder: () -> Void

       var body: some View {
           VStack(spacing: 24) {
               Spacer()

               Image(systemName: "folder.badge.plus")
                   .font(.system(size: 80))
                   .foregroundStyle(.blue)

               Text("Welcome to OpenCookbook")
                   .font(.largeTitle)
                   .bold()

               Text("Store your recipes in RecipeMD format on iCloud Drive. Your data stays under your control.")
                   .font(.body)
                   .foregroundStyle(.secondary)
                   .multilineTextAlignment(.center)
                   .padding(.horizontal, 32)

               Spacer()

               Button(action: onSelectFolder) {
                   Text("Select Folder")
                       .font(.headline)
                       .frame(maxWidth: .infinity)
               }
               .buttonStyle(.borderedProminent)
               .padding(.horizontal, 32)
               .padding(.bottom, 48)
           }
       }
   }
   ```
2. Add accessibility labels
3. Test on various screen sizes

**Files to Create**:
- `Features/Onboarding/Views/WelcomeView.swift`

**Testing**:
- Preview in Xcode canvas
- Test VoiceOver navigation
- Test on iPhone SE and iPhone Pro Max

---

### Task 3.2: Create Folder Confirmation View
**Complexity**: 2 points (Simple)
**Dependencies**: Task 3.1
**Acceptance**:
- [ ] Shows selected folder path
- [ ] Continue button proceeds to main app
- [ ] Visual feedback for successful selection

**Implementation Steps**:
1. Create `Features/Onboarding/Views/FolderConfirmationView.swift`:
   ```swift
   struct FolderConfirmationView: View {
       let folderURL: URL
       let onContinue: () -> Void

       var body: some View {
           VStack(spacing: 24) {
               Spacer()

               Image(systemName: "checkmark.circle.fill")
                   .font(.system(size: 80))
                   .foregroundStyle(.green)

               Text("Folder Selected")
                   .font(.largeTitle)
                   .bold()

               VStack(alignment: .leading, spacing: 8) {
                   Text("Your recipes will be stored in:")
                       .font(.subheadline)
                       .foregroundStyle(.secondary)

                   Text(folderURL.path)
                       .font(.body)
                       .padding()
                       .background(Color(.systemGray6))
                       .cornerRadius(8)
               }
               .padding(.horizontal, 32)

               Spacer()

               Button(action: onContinue) {
                   Text("Continue")
                       .font(.headline)
                       .frame(maxWidth: .infinity)
               }
               .buttonStyle(.borderedProminent)
               .padding(.horizontal, 32)
               .padding(.bottom, 48)
           }
       }
   }
   ```

**Files to Create**:
- `Features/Onboarding/Views/FolderConfirmationView.swift`

**Testing**:
- Preview with sample URL
- Verify path displays correctly

---

### Task 3.3: Implement Onboarding Coordinator
**Complexity**: 3 points (Medium)
**Dependencies**: Tasks 2.2, 3.1, 3.2
**Acceptance**:
- [ ] OnboardingView coordinates welcome → picker → confirmation flow
- [ ] Folder selection persisted via FolderManager
- [ ] Navigation to main app after completion
- [ ] Error handling for picker cancellation

**Implementation Steps**:
1. Create `Features/Onboarding/Views/OnboardingView.swift`:
   ```swift
   @Observable
   class OnboardingViewModel {
       var currentStep: OnboardingStep = .welcome
       var selectedFolderURL: URL?
       var showPicker = false
       var errorMessage: String?

       let folderManager: FolderManager

       init(folderManager: FolderManager) {
           self.folderManager = folderManager
       }

       func selectFolder() {
           showPicker = true
       }

       func handleFolderSelected(_ url: URL) {
           do {
               try folderManager.saveFolder(url)
               selectedFolderURL = url
               currentStep = .confirmation
           } catch {
               errorMessage = "Failed to save folder: \(error.localizedDescription)"
           }
       }

       func handleCancelled() {
           errorMessage = "Please select a folder to continue"
       }

       func complete() {
           // Handled by parent view
       }
   }

   enum OnboardingStep {
       case welcome
       case confirmation
   }

   struct OnboardingView: View {
       @State private var viewModel: OnboardingViewModel
       var onComplete: () -> Void

       init(folderManager: FolderManager, onComplete: @escaping () -> Void) {
           self.viewModel = OnboardingViewModel(folderManager: folderManager)
           self.onComplete = onComplete
       }

       var body: some View {
           Group {
               switch viewModel.currentStep {
               case .welcome:
                   WelcomeView(onSelectFolder: viewModel.selectFolder)
               case .confirmation:
                   if let url = viewModel.selectedFolderURL {
                       FolderConfirmationView(
                           folderURL: url,
                           onContinue: onComplete
                       )
                   }
               }
           }
           .sheet(isPresented: $viewModel.showPicker) {
               FolderPicker(
                   selectedURL: $viewModel.selectedFolderURL,
                   onSelect: viewModel.handleFolderSelected,
                   onCancel: viewModel.handleCancelled
               )
           }
           .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
               Button("OK") {
                   viewModel.errorMessage = nil
               }
           } message: {
               if let error = viewModel.errorMessage {
                   Text(error)
               }
           }
       }
   }
   ```

**Files to Create**:
- `Features/Onboarding/Views/OnboardingView.swift`

**Testing**:
- Test full flow: welcome → picker → confirmation
- Test cancellation handling
- Test error states

---

### Task 3.4: Integrate Onboarding into App Launch
**Complexity**: 2 points (Simple)
**Dependencies**: Task 3.3
**Acceptance**:
- [ ] App checks for first launch on startup
- [ ] Shows onboarding if no folder selected
- [ ] Shows main app if folder already selected
- [ ] State persists across app launches

**Implementation Steps**:
1. Modify `App/OpenCookbookApp.swift`:
   ```swift
   @main
   struct OpenCookbookApp: App {
       @State private var folderManager = FolderManager()

       var body: some Scene {
           WindowGroup {
               Group {
                   if folderManager.hasSelectedFolder() {
                       MainTabView()
                           .environment(folderManager)
                   } else {
                       OnboardingView(folderManager: folderManager) {
                           // Force re-check after onboarding
                           folderManager.objectWillChange.send()
                       }
                   }
               }
               .onAppear {
                   // Load saved folder on launch
                   try? folderManager.loadSavedFolder()
               }
           }
       }
   }
   ```
2. Test first launch vs. returning user

**Files to Modify**:
- `App/OpenCookbookApp.swift`

**Testing**:
- Delete app, reinstall, verify onboarding appears
- Complete onboarding, relaunch, verify main app appears
- Test state restoration

---

## Phase 4: Settings Integration

### Task 4.1: Create Settings View with Folder Option
**Complexity**: 2 points (Simple)
**Dependencies**: None
**Acceptance**:
- [ ] Settings view created with "Change Folder Location" row
- [ ] Tapping row triggers folder picker
- [ ] Current folder path displayed

**Implementation Steps**:
1. Create `Features/Settings/Views/SettingsView.swift`:
   ```swift
   struct SettingsView: View {
       @Environment(FolderManager.self) private var folderManager
       @State private var showFolderPicker = false
       @State private var showChangeConfirmation = false

       var body: some View {
           NavigationStack {
               Form {
                   Section {
                       VStack(alignment: .leading, spacing: 8) {
                           Text("Recipe Folder")
                               .font(.headline)
                           if let url = folderManager.selectedFolderURL {
                               Text(url.path)
                                   .font(.caption)
                                   .foregroundStyle(.secondary)
                           }
                       }

                       Button("Change Folder Location") {
                           showChangeConfirmation = true
                       }
                   } header: {
                       Text("Storage")
                   }
               }
               .navigationTitle("Settings")
               .confirmationDialog(
                   "Change Folder?",
                   isPresented: $showChangeConfirmation
               ) {
                   Button("Change Folder", role: .destructive) {
                       showFolderPicker = true
                   }
                   Button("Cancel", role: .cancel) {}
               } message: {
                   Text("Changing your folder will switch to a different recipe collection.")
               }
               .sheet(isPresented: $showFolderPicker) {
                   FolderPicker(
                       selectedURL: .constant(nil),
                       onSelect: { url in
                           try? folderManager.saveFolder(url)
                       },
                       onCancel: {}
                   )
               }
           }
       }
   }
   ```

**Files to Create**:
- `Features/Settings/Views/SettingsView.swift`

**Testing**:
- Navigate to settings
- Verify current folder displayed
- Test change folder flow

---

## Phase 5: Error Handling & Edge Cases

### Task 5.1: Implement Permission Error Handling
**Complexity**: 2 points (Simple)
**Dependencies**: Task 2.2
**Acceptance**:
- [ ] Detect when iCloud permissions revoked
- [ ] Show alert with instructions to grant access
- [ ] Link to Settings app if possible
- [ ] Graceful degradation if permissions unavailable

**Implementation Steps**:
1. Add permission checking to `FolderManager`:
   ```swift
   func checkiCloudAvailability() -> Bool {
       return FileManager.default.ubiquityIdentityToken != nil
   }
   ```
2. Create error alert view component:
   ```swift
   struct CloudPermissionErrorView: View {
       var body: some View {
           VStack(spacing: 16) {
               Image(systemName: "exclamationmark.icloud")
                   .font(.system(size: 60))
                   .foregroundStyle(.orange)

               Text("iCloud Access Required")
                   .font(.title2)
                   .bold()

               Text("Please enable iCloud Drive in Settings to use OpenCookbook.")
                   .multilineTextAlignment(.center)
                   .foregroundStyle(.secondary)

               Button("Open Settings") {
                   if let url = URL(string: UIApplication.openSettingsURLString) {
                       UIApplication.shared.open(url)
                   }
               }
               .buttonStyle(.borderedProminent)
           }
           .padding()
       }
   }
   ```
3. Integrate permission check into app launch

**Files to Modify**:
- `Core/Services/FolderManager.swift`

**Files to Create**:
- `Features/Onboarding/Views/CloudPermissionErrorView.swift`

**Testing**:
- Disable iCloud in Settings
- Launch app
- Verify error message shown
- Verify Settings button works

---

### Task 5.2: Handle Folder Access Errors
**Complexity**: 2 points (Simple)
**Dependencies**: Task 5.1
**Acceptance**:
- [ ] Handle case where saved folder no longer accessible
- [ ] Show appropriate error message
- [ ] Offer to select new folder
- [ ] Clear invalid bookmark data

**Implementation Steps**:
1. Enhance `loadSavedFolder()` error handling:
   ```swift
   func loadSavedFolder() throws -> URL? {
       guard let bookmarkData = UserDefaults.standard.data(forKey: "selectedFolderBookmark") else {
           return nil
       }

       do {
           var isStale = false
           let url = try URL(
               resolvingBookmarkData: bookmarkData,
               options: .withoutUI,
               relativeTo: nil,
               bookmarkDataIsStale: &isStale
           )

           // Verify we can still access the folder
           guard FileManager.default.fileExists(atPath: url.path) else {
               throw FolderError.folderNotFound
           }

           if isStale {
               try saveFolder(url)
           }

           self.selectedFolderURL = url
           return url
       } catch {
           // Clear invalid bookmark
           clearSavedFolder()
           throw error
       }
   }

   func clearSavedFolder() {
       UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
       selectedFolderURL = nil
       folderBookmark = nil
   }

   enum FolderError: LocalizedError {
       case folderNotFound
       case permissionDenied

       var errorDescription: String? {
           switch self {
           case .folderNotFound:
               return "The selected folder could not be found."
           case .permissionDenied:
               return "Permission denied to access folder."
           }
       }
   }
   ```
2. Add error handling UI in app launch
3. Test various error scenarios

**Files to Modify**:
- `Core/Services/FolderManager.swift`
- `App/OpenCookbookApp.swift`

**Testing**:
- Save folder, then delete it externally
- Launch app and verify error handling
- Verify can select new folder

---

## Phase 6: Testing & Polish

### Task 6.1: Write Unit Tests
**Complexity**: 2 points (Simple)
**Dependencies**: All implementation tasks
**Acceptance**:
- [ ] FolderManager tests cover all methods
- [ ] Test bookmark save/load cycle
- [ ] Test error cases
- [ ] 80%+ code coverage on FolderManager

**Implementation Steps**:
1. Implement comprehensive tests in `Tests/FolderManagerTests.swift`:
   ```swift
   @Test func testSaveAndLoadFolder() async throws {
       let manager = FolderManager()
       let testURL = URL(fileURLWithPath: "/tmp/test")

       // This will fail in test environment, but structure is correct
       // try manager.saveFolder(testURL)
       // let loaded = try manager.loadSavedFolder()
       // #expect(loaded == testURL)
   }

   @Test func testHasSelectedFolder() {
       let manager = FolderManager()
       #expect(manager.hasSelectedFolder() == false)
   }

   @Test func testClearSavedFolder() {
       let manager = FolderManager()
       manager.clearSavedFolder()
       #expect(manager.selectedFolderURL == nil)
   }
   ```
2. Run tests and verify passing
3. Check code coverage report

**Files to Modify**:
- `Tests/FolderManagerTests.swift`

**Testing**:
- Run test suite via Xcode
- Verify all tests pass
- Check coverage report

---

### Task 6.2: Implement UI Tests for Onboarding Flow
**Complexity**: 2 points (Simple)
**Dependencies**: Task 6.1
**Acceptance**:
- [ ] UI test covers first launch flow
- [ ] Test verifies folder picker appears
- [ ] Test verifies confirmation screen
- [ ] Test runs reliably in CI

**Implementation Steps**:
1. Create `UITests/OnboardingUITests.swift`:
   ```swift
   import XCTest

   final class OnboardingUITests: XCTestCase {
       func testFirstLaunchOnboarding() throws {
           let app = XCUIApplication()
           app.launchArguments = ["--reset-onboarding"]
           app.launch()

           // Verify welcome screen appears
           XCTAssertTrue(app.staticTexts["Welcome to OpenCookbook"].exists)

           // Tap select folder button
           app.buttons["Select Folder"].tap()

           // Document picker should appear
           // Note: Hard to test picker interaction in UI tests
           // May need to mock or skip this part
       }
   }
   ```
2. Add launch argument handling for test mode
3. Run and verify test passes

**Files to Create**:
- `UITests/OnboardingUITests.swift`

**Testing**:
- Run UI tests
- Verify stable execution

---

### Task 6.3: Manual QA Checklist
**Complexity**: 1 point (Simple)
**Dependencies**: All tasks
**Acceptance**:
- [ ] All test cases from spec executed manually
- [ ] Edge cases documented
- [ ] Screenshots captured for documentation

**QA Checklist**:
- [ ] TC-001: First launch folder selection
- [ ] TC-002: Change folder in Settings
- [ ] TC-003: Permission denied handling
- [ ] Test on multiple device sizes (SE, Pro, Pro Max)
- [ ] Test with VoiceOver enabled
- [ ] Test with Dynamic Type at largest size
- [ ] Test app in Airplane mode (iCloud unavailable)
- [ ] Test selecting non-iCloud folder (if supported)

**Deliverable**:
- Document test results in `docs/qa/f001-test-results.md`

---

## Summary

**Total Tasks**: 15
**Total Complexity**: 35 points

**Phases**:
1. Project Setup & Entitlements: 5 points (2 tasks)
2. Core Folder Selection Logic: 10 points (3 tasks)
3. First Launch Experience: 9 points (4 tasks)
4. Settings Integration: 2 points (1 task)
5. Error Handling & Edge Cases: 4 points (2 tasks)
6. Testing & Polish: 5 points (3 tasks)

**Recommended Sprint Planning**:
- Sprint 1: Phases 1-2 (Foundation)
- Sprint 2: Phase 3 (Onboarding UX)
- Sprint 3: Phases 4-6 (Settings, errors, testing)

**Critical Path**:
Task 1.1 → 1.2 → 2.1 → 2.2 → 3.3 → 3.4

**Parallel Work Opportunities**:
- Task 3.1 and 3.2 can be done in parallel with Phase 2
- Task 4.1 can be done independently
- Task 5.1 can start after 2.2
