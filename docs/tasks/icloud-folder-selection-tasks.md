# Task Breakdown: Two-Option Storage Selection Onboarding

**Feature Spec**: [docs/specs/icloud-folder-selection.md](../specs/icloud-folder-selection.md)

---

## Task 1: Add folder creation method to FolderManager
**File:** `src/OpenCookbook/Core/Services/FolderManager.swift`
**Status:** Complete

- Added `folderCreationFailed` case to `FolderError` enum
- Added `createDefaultLocalFolder() throws -> URL` — creates `Documents/Recipes`, persists via bookmark

---

## Task 2: Update WelcomeView
**File:** `src/OpenCookbook/Features/Onboarding/Views/WelcomeView.swift`
**Status:** Complete

- Renamed `onSelectFolder` callback to `onContinue`
- Changed button text from "Select Folder" to "Get Started"
- Updated accessibility hint

---

## Task 3: Create StorageSelectionView
**File:** `src/OpenCookbook/Features/Onboarding/Views/StorageSelectionView.swift`
**Status:** Complete

- Two-button vertical layout matching existing onboarding style
- Option 1: `folder` icon — "Use a default folder on your device" / Documents/Recipes
- Option 2: `folder.badge.questionmark` icon — "Pick your own folder" / Choose a local or iCloud Drive folder

---

## Task 4: Update OnboardingView and ViewModel
**File:** `src/OpenCookbook/Features/Onboarding/Views/OnboardingView.swift`
**Status:** Complete

ViewModel changes:
- Added `.storageSelection` case to `OnboardingStep` enum
- Added `proceedToStorageSelection()`, `selectDefaultLocalFolder()`, `selectCustomFolder()` methods
- Updated `handleCancelled()` to return to `.storageSelection`

View changes:
- Added `.storageSelection` case routing to `StorageSelectionView`
- `.welcome` case passes `proceedToStorageSelection` as `onContinue`

---

## Task 5: Enable Files app visibility
**Files:** `src/Info.plist`, `src/OpenCookbook.xcodeproj/project.pbxproj`
**Status:** Complete

- Added `UIFileSharingEnabled` in Info.plist (exposes Documents folder in Files)
- Added `LSSupportsOpeningDocumentsInPlace` in build settings (makes folder browsable in Files)
- App's Documents folder appears under On My iPhone > Open Cookbook in Files

---

## Task 6: Settings folder picker defaults to current folder
**File:** `src/OpenCookbook/Core/Services/DocumentPickerCoordinator.swift`
**Status:** Complete

- Added `initialDirectory` parameter to `FolderPicker`
- Settings passes `folderManager.selectedFolderURL` so picker opens to current folder

---

## Task 7: Add tests
**Files:** `src/OpenCookbookTests/FolderManagerTests.swift`, `src/OpenCookbookTests/OnboardingViewModelTests.swift`
**Status:** Complete

FolderManager tests:
- `createDefaultLocalFolder()` creates directory and returns URL with `lastPathComponent == "Recipes"`
- `createDefaultLocalFolder()` is idempotent
- `createDefaultiCloudFolder()` throws `.iCloudUnavailable` when iCloud is off

OnboardingViewModel tests:
- Initial step is `.welcome`
- `proceedToStorageSelection()` transitions to `.storageSelection`
- `selectDefaultLocalFolder()` moves to `.confirmation` with URL set
- `selectCustomFolder()` sets `showPicker = true`
- `handleCancelled()` returns to `.storageSelection`

---

## Verification Checklist
1. Build succeeds
2. All tests pass
3. Manual: Fresh launch → Welcome → "Get Started" → StorageSelectionView with 2 options
4. Manual: Option 1 creates local folder → confirmation
5. Manual: Option 2 opens picker; cancel returns to selection screen
6. Manual: Option 2 select iCloud Drive folder → confirmation
7. Manual: Local folder visible in Files app under On My iPhone > Open Cookbook
8. Manual: Settings "Change Folder" opens picker at current folder location
