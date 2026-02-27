# Feature Spec: Folder Selection

**Priority**: P0 (Must Have)
**Feature ID**: F001

## Description
On first launch, users choose a storage location for their recipes from two options: a default local folder or a custom folder via the native document picker. The custom picker allows selecting local or iCloud Drive folders. The app persists this selection and monitors the chosen folder for changes.

## User Stories

### US-001: Quick default setup
**As a** new user
**I want** a one-tap setup that creates a folder for me
**So that** I can start using the app immediately without navigating a file picker

### US-002: First-time folder selection
**As a** new user
**I want** to select where my recipes are stored
**So that** I have full control over my data

### US-003: Existing RecipeMD user onboarding
**As an** existing RecipeMD user
**I want** to point the app to my existing recipe folder
**So that** I can immediately access my collection

## Acceptance Criteria

- [x] App presents a two-option storage selection screen on first launch
- [x] Option 1 ("Default folder on your device") auto-creates `Documents/Recipes` and selects it
- [x] Option 2 ("Pick your own folder") opens the native document picker
- [x] Document picker allows selecting local or iCloud Drive folders
- [x] Selected folder path is persisted via security-scoped bookmark in UserDefaults
- [x] App's Documents folder is visible in Files app via UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace
- [x] User can change folder location in Settings
- [x] Settings folder picker defaults to the currently selected folder
- [x] App handles permission errors gracefully with clear messaging

## Technical Requirements

### Implementation Details
- Auto-create default local folder with `FileManager.default.createDirectory(at:withIntermediateDirectories:true)`
- Use `UIDocumentPickerViewController` for the "Pick your own folder" option
- Store bookmark data for security-scoped resource access
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` in Info.plist to expose Documents in Files app
- iCloud Drive entitlement enabled in Xcode project for users who choose an iCloud Drive folder via the picker

### Security
- Security-scoped bookmarks must be properly managed
- Handle permission revocation gracefully

### Error Handling
- **Folder creation failure** (local) → show alert: "Could not create folder. Please check available storage and try again."
- **User cancels document picker** → return to storage selection screen
- **Permission denied** → show alert with instructions to grant access in Settings
- **Invalid folder selected** → show error and return to storage selection screen

## UI/UX Requirements

### First Launch Flow
1. Welcome screen explaining OpenCookbook and the RecipeMD format
2. Storage selection screen with two options:
   - **"Use a default folder on your device"** — creates `Documents/Recipes`
   - **"Pick your own folder"** — launches native document picker (supports local and iCloud Drive folders)
3. After selection (or auto-creation), show confirmation with the chosen folder path
4. Proceed to main app

### Settings Integration
- Settings screen has "Change Folder Location" option
- Folder picker defaults to the currently selected folder
- Changing folder shows warning about switching collections
- Confirmation dialog before switching

## Dependencies
- UIDocumentPickerViewController (UIKit bridge) for custom folder selection
- FileManager for folder creation and bookmark storage
- iCloud Drive entitlement (for users who select iCloud Drive folders via picker)

## Test Cases

### TC-001: Select default local folder
1. Launch app for first time
2. Tap "Get Started" on welcome screen
3. Verify storage selection screen appears with two options
4. Tap "Use a default folder on your device"
5. Verify `Documents/Recipes` is created
6. Verify folder path is saved via security-scoped bookmark
7. Verify app proceeds to main screen

### TC-002: Pick custom local folder
1. Launch app for first time
2. Tap "Get Started", then "Pick your own folder"
3. Select a local folder in the document picker
4. Verify folder path is saved
5. Verify app proceeds to main screen

### TC-003: Pick iCloud Drive folder
1. Launch app for first time (iCloud signed in)
2. Tap "Get Started", then "Pick your own folder"
3. Navigate to iCloud Drive and select or create a folder
4. Verify folder path is saved
5. Verify app proceeds to main screen
6. Verify folder is visible in Files app under iCloud Drive

### TC-004: Cancel document picker
1. Launch app for first time
2. Tap "Get Started", then "Pick your own folder"
3. Cancel the document picker
4. Verify user is returned to the storage selection screen

### TC-005: Folder creation failure
1. Simulate a write-protected or full-disk scenario
2. Tap "Use a default folder on your device"
3. Verify appropriate error alert is shown
4. Verify user remains on the storage selection screen

### TC-006: Change folder in Settings
1. Navigate to Settings
2. Tap "Change Folder Location"
3. Verify folder picker opens to the currently selected folder
4. Select different folder
5. Verify confirmation dialog appears
6. Confirm change
7. Verify new folder is loaded

### TC-007: Local folder visible in Files
1. Select "Use a default folder on your device" during onboarding
2. Open Files app on iPhone
3. Navigate to On My iPhone > Open Cookbook
4. Verify the Recipes folder is visible
