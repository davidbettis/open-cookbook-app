# Feature Spec: iCloud Drive Folder Selection

**Priority**: P0 (Must Have)
**Feature ID**: F001

## Description
On first launch, users browse and select an iCloud Drive folder to use as their recipe storage location. The app persists this selection and monitors the folder for changes.

## User Stories

### US-001: First-time folder selection
**As a** new user
**I want** to select where my recipes are stored
**So that** I have full control over my data

### US-002: Existing RecipeMD user onboarding
**As an** existing RecipeMD user
**I want** to point the app to my existing recipe folder
**So that** I can immediately access my collection

## Acceptance Criteria

- [ ] App presents folder picker on first launch
- [ ] Selected folder path is persisted in UserDefaults/AppStorage
- [ ] App requests necessary iCloud entitlements and permissions
- [ ] User can change folder location in Settings
- [ ] App handles permission errors gracefully with clear messaging

## Technical Requirements

### Implementation Details
- Use UIDocumentPickerViewController or FileManager for folder selection
- Store bookmark data for security-scoped resource access
- iCloud Drive entitlement enabled in Xcode project
- Monitor folder for file system changes using FileManager or DispatchSource

### Security
- Security-scoped bookmarks must be properly managed
- Request iCloud permissions before accessing
- Handle permission revocation gracefully

### Error Handling
- User cancels folder selection → show message explaining folder is required
- Permission denied → show alert with instructions to grant access in Settings
- Invalid folder selected → show error and re-prompt

## UI/UX Requirements

### First Launch Flow
1. Welcome screen explaining RecipeMD and iCloud folder concept
2. "Select Folder" button launches document picker
3. After selection, show confirmation with folder path
4. Proceed to main app

### Settings Integration
- Settings screen should have "Change Folder Location" option
- Changing folder shows warning about switching collections
- Confirmation dialog before switching

## Dependencies
- iCloud Drive entitlement
- UIDocumentPickerViewController (UIKit bridge)
- FileManager for bookmark storage

## Test Cases

### TC-001: First launch folder selection
1. Launch app for first time
2. Verify folder picker appears
3. Select valid iCloud folder
4. Verify folder path is saved
5. Verify app proceeds to main screen

### TC-002: Change folder in Settings
1. Navigate to Settings
2. Tap "Change Folder Location"
3. Select different folder
4. Verify confirmation dialog appears
5. Confirm change
6. Verify new folder is loaded

### TC-003: Permission denied
1. Revoke iCloud permissions in System Settings
2. Launch app
3. Verify error message appears
4. Verify instructions to grant permission are shown

## Open Questions
- Should app support multiple folder collections?
- What happens if user selects a non-iCloud folder (local)?
