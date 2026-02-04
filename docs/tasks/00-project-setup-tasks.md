# Task Breakdown: Project Setup & Scaffolding

**Goal**: Create a working iOS project with basic UI displaying "Hello, world"

**Total Estimated Complexity**: 8 points

---

## Phase 0: Initial Project Creation

### Task 0.1: Create Xcode Project
**Complexity**: 2 points (Simple)
**Dependencies**: None
**Acceptance**:
- [ ] Xcode project created with correct bundle identifier
- [ ] iOS deployment target set to iOS 17.0
- [ ] Swift 6.0 language mode enabled
- [ ] Project builds successfully
- [ ] Basic "Hello, world" UI visible when app launches

**Implementation Steps**:
1. Open Xcode
2. Create new project: File → New → Project
3. Select iOS → App template
4. Configure project:
   - Product Name: `OpenCookbook`
   - Team: Select your development team
   - Organization Identifier: `com.yourname` (or your preference)
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None (we'll add manually)
   - Include Tests: Yes
5. Choose location: `/Users/davidbettis/Development/OpenCookbook`
6. In project settings:
   - Set iOS Deployment Target to 17.0
   - Enable Swift 6 language mode (Build Settings → Swift Language Version → 6)
7. Build and run to verify "Hello, world" appears

**Initial ContentView.swift**:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

**Files Created by Xcode**:
- `OpenCookbook.xcodeproj`
- `OpenCookbook/OpenCookbookApp.swift`
- `OpenCookbook/ContentView.swift`
- `OpenCookbook/Assets.xcassets`
- `OpenCookbook/Preview Content/`
- `OpenCookbookTests/`
- `OpenCookbookUITests/`

**Testing**:
- Cmd+R to build and run
- Verify app launches on simulator
- Verify "Hello, world!" text displays

---

### Task 0.2: Set Up Project Structure
**Complexity**: 2 points (Simple)
**Dependencies**: Task 0.1
**Acceptance**:
- [ ] Folder structure created following CLAUDE.md guidelines
- [ ] Empty placeholder files added for organization
- [ ] Project navigator organized logically
- [ ] Project still builds successfully

**Implementation Steps**:
1. In Xcode, create folder groups (right-click → New Group):
   ```
   OpenCookbook/
   ├── App/
   │   └── OpenCookbookApp.swift (move existing)
   ├── Features/
   │   ├── Onboarding/
   │   │   └── Views/
   │   ├── RecipeList/
   │   │   └── Views/
   │   ├── RecipeDetail/
   │   │   └── Views/
   │   └── Settings/
   │       └── Views/
   ├── Core/
   │   ├── Extensions/
   │   ├── Services/
   │   └── Models/
   ├── Resources/
   │   └── Assets.xcassets (move existing)
   └── ContentView.swift (temporary, will remove later)
   ```

2. Move files to appropriate groups:
   - Move `OpenCookbookApp.swift` to `App/` group
   - Move `Assets.xcassets` to `Resources/` group
   - Keep `ContentView.swift` at root for now (temporary hello world)

3. Create `.gitignore` in project root:
   ```
   # Xcode
   build/
   *.pbxuser
   !default.pbxuser
   *.mode1v3
   !default.mode1v3
   *.mode2v3
   !default.mode2v3
   *.perspectivev3
   !default.perspectivev3
   xcuserdata/
   *.xccheckout
   *.moved-aside
   DerivedData/
   *.xcuserstate
   *.xcscmblueprint

   # Swift Package Manager
   .build/
   .swiftpm/

   # macOS
   .DS_Store
   ```

4. Build project to verify structure works

**Files to Create**:
- `.gitignore`
- Folder groups in Xcode (no physical files yet)

**Testing**:
- Build and run
- Verify app still shows "Hello, world!"
- Verify folder structure visible in Xcode navigator

---

### Task 0.3: Configure Build Settings
**Complexity**: 2 points (Simple)
**Dependencies**: Task 0.2
**Acceptance**:
- [ ] Swift 6 strict concurrency enabled
- [ ] Warnings configured appropriately
- [ ] Debug/Release configurations set up
- [ ] Project builds with no warnings

**Implementation Steps**:
1. Select project in navigator → Build Settings
2. Configure Swift settings:
   - Swift Language Version: 6
   - Swift Strict Concurrency: Complete (Build Settings → search "strict concurrency")
   - Enable Upcoming Features: All (Optional, for Swift 6 features)

3. Configure warnings:
   - Treat Warnings as Errors: Yes (for Release only)
   - Enable Additional Warnings: Yes

4. Configure optimization:
   - Debug: Optimize for Speed [-O]
   - Release: Optimize for Speed [-O]

5. Build project and fix any warnings that appear

**Build Settings to Modify**:
- `SWIFT_VERSION = 6.0`
- `SWIFT_STRICT_CONCURRENCY = complete`
- `SWIFT_TREAT_WARNINGS_AS_ERRORS[config=Release] = YES`

**Testing**:
- Build for Debug configuration → should succeed
- Build for Release configuration → should succeed with no warnings
- Run on simulator → verify still works

---

### Task 0.4: Add Testing Infrastructure
**Complexity**: 1 point (Simple)
**Dependencies**: Task 0.3
**Acceptance**:
- [ ] Test target configured properly
- [ ] Sample unit test runs successfully
- [ ] Sample UI test runs successfully
- [ ] Test coverage enabled

**Implementation Steps**:
1. Verify test targets exist:
   - `OpenCookbookTests` (unit tests)
   - `OpenCookbookUITests` (UI tests)

2. Update `OpenCookbookTests/OpenCookbookTests.swift`:
   ```swift
   import Testing
   @testable import OpenCookbook

   struct OpenCookbookTests {
       @Test func exampleTest() async throws {
           // This is a placeholder test
           #expect(1 + 1 == 2)
       }
   }
   ```

3. Update `OpenCookbookUITests/OpenCookbookUITests.swift`:
   ```swift
   import XCTest

   final class OpenCookbookUITests: XCTestCase {
       func testAppLaunches() throws {
           let app = XCUIApplication()
           app.launch()

           // Verify "Hello, world!" appears
           XCTAssertTrue(app.staticTexts["Hello, world!"].exists)
       }
   }
   ```

4. Enable code coverage:
   - Product → Scheme → Edit Scheme
   - Test → Options
   - Check "Code Coverage" for OpenCookbook target

5. Run tests (Cmd+U) and verify they pass

**Files to Modify**:
- `OpenCookbookTests/OpenCookbookTests.swift`
- `OpenCookbookUITests/OpenCookbookUITests.swift`

**Testing**:
- Cmd+U to run all tests
- Verify unit test passes
- Verify UI test passes
- Check code coverage report

---

### Task 0.5: Initialize Git Repository
**Complexity**: 1 point (Simple)
**Dependencies**: Task 0.2
**Acceptance**:
- [ ] Git repository initialized
- [ ] Initial commit created
- [ ] .gitignore working correctly
- [ ] Project files tracked appropriately

**Implementation Steps**:
1. Open Terminal in project directory:
   ```bash
   cd /Users/davidbettis/Development/OpenCookbook
   ```

2. Initialize git repository:
   ```bash
   git init
   ```

3. Add all files:
   ```bash
   git add .
   ```

4. Create initial commit:
   ```bash
   git commit -m "Initial project setup with Hello World

   - Created Xcode project with iOS 17 target
   - Set up folder structure following CLAUDE.md
   - Configured Swift 6 strict concurrency
   - Added test infrastructure
   - Basic ContentView displays Hello, world!
   "
   ```

5. Verify files tracked:
   ```bash
   git status
   ```

6. Verify ignored files not tracked:
   ```bash
   # Should not show xcuserdata, build/, etc.
   git ls-files | grep xcuserdata
   # (should return nothing)
   ```

**Commands to Run**:
```bash
git init
git add .
git commit -m "Initial project setup with Hello World"
git status
```

**Testing**:
- Run `git log` to see commit
- Run `git status` to verify clean working tree
- Verify `.DS_Store`, `xcuserdata/` not tracked

---

## Summary

**Total Tasks**: 5
**Total Complexity**: 8 points

**Phases**:
- Phase 0: Initial Project Creation: 8 points (5 tasks)

**Critical Path**:
Task 0.1 → 0.2 → 0.3 → 0.4 (0.5 can be done anytime after 0.2)

**Final State After Completion**:
- ✅ Working iOS 17 app with Swift 6
- ✅ "Hello, world!" UI visible
- ✅ Project structure follows CLAUDE.md
- ✅ Tests passing
- ✅ Git repository initialized
- ✅ Ready for feature development

**Next Steps**:
After completing these tasks, proceed to:
- [icloud-folder-selection-tasks.md](icloud-folder-selection-tasks.md) - Feature F001
