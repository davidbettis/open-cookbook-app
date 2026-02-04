# Task Breakdown: Recipe Library View (F002)

**Feature Spec**: [docs/specs/recipe-library-view.md](../specs/recipe-library-view.md)

**Total Estimated Complexity**: 32 points

---

## Phase 1: Data Models & Parser

### Task 1.1: Create Recipe Model
**Complexity**: 2 points (Simple)
**Dependencies**: None
**Acceptance**:
- [ ] `Recipe` model created with all RecipeMD fields
- [ ] Model conforms to Identifiable and Hashable
- [ ] Properties for title, description, tags, yields, ingredients, instructions
- [ ] File path/URL property for tracking source file
- [ ] Model compiles without errors

**Implementation Steps**:
1. Create `Core/Models/Recipe.swift`
2. Define `struct Recipe`:
   ```swift
   struct Recipe: Identifiable, Hashable {
       let id: UUID
       let filePath: URL
       var title: String
       var description: String?
       var tags: [String]
       var yields: [String]
       var ingredients: [Ingredient]
       var ingredientGroups: [IngredientGroup]
       var instructions: String?
       var fileModifiedDate: Date?
   }
   ```
3. Add Ingredient and related models
4. Add computed properties for display (e.g., `primaryTag`)

**Files to Create**:
- `Core/Models/Recipe.swift`
- `Core/Models/Ingredient.swift`

**Testing**:
- Create sample Recipe instances
- Verify Identifiable works (can use in List)
- Verify Hashable works (can use in Set)

---

### Task 1.2: Create Lightweight RecipeMD Metadata Parser
**Complexity**: 4 points (Medium-Hard)
**Dependencies**: Task 1.1
**Acceptance**:
- [ ] Parser extracts title from H1 heading
- [ ] Parser extracts tags from italic paragraphs
- [ ] Parser extracts yields from bold paragraphs
- [ ] Parser extracts first paragraph as description (optional)
- [ ] Parser handles malformed files gracefully
- [ ] Unit tests pass

**Implementation Steps**:
1. Create `Core/Services/RecipeMDParser.swift`
2. Implement lightweight parsing:
   ```swift
   class RecipeMDParser {
       func parseMetadata(from url: URL) throws -> Recipe
       func parseTitle(_ content: String) -> String?
       func parseTags(_ content: String) -> [String]
       func parseYields(_ content: String) -> [String]
       func parseDescription(_ content: String) -> String?
   }
   ```
3. Use regex or string parsing (not full CommonMark parser for list view)
4. Extract only what's needed for list display:
   - Title (first H1: `# Title`)
   - Tags (italic before first HR: `*tag1, tag2*`)
   - Description (first paragraph, optional)
5. Handle errors with custom `RecipeParseError` enum
6. Add unit tests for various RecipeMD formats

**Files to Create**:
- `Core/Services/RecipeMDParser.swift`
- `OpenCookbookTests/RecipeMDParserTests.swift`

**Testing**:
- Test with valid RecipeMD files
- Test with malformed files
- Test with minimal recipes (title only)
- Test with complex recipes
- Verify performance (< 10ms per file)

---

## Phase 2: File System Integration

### Task 2.1: Create RecipeFileMonitor Service
**Complexity**: 4 points (Medium-Hard)
**Dependencies**: Task 1.1
**Acceptance**:
- [ ] Monitor selected folder for .md files
- [ ] Detect file additions, deletions, modifications
- [ ] Debounce file system events (300ms)
- [ ] Notify observers when files change
- [ ] Handle folder access errors gracefully

**Implementation Steps**:
1. Create `Core/Services/RecipeFileMonitor.swift`
2. Implement file monitoring using DispatchSource:
   ```swift
   @Observable
   class RecipeFileMonitor {
       var fileURLs: [URL] = []
       private var monitorSource: DispatchSourceFileSystemObject?

       func startMonitoring(folder: URL)
       func stopMonitoring()
       func scanFolder() -> [URL]
   }
   ```
3. Use `FileManager` to list .md files
4. Set up `DispatchSource` to watch folder for changes
5. Debounce events to avoid rapid-fire updates
6. Emit updates via Combine or @Observable changes

**Files to Create**:
- `Core/Services/RecipeFileMonitor.swift`

**Testing**:
- Manual test: Add file to folder, verify detection
- Manual test: Delete file, verify detection
- Manual test: Modify file, verify detection
- Verify debouncing works (rapid changes only trigger once)

---

### Task 2.2: Create RecipeStore Service
**Complexity**: 4 points (Medium-Hard)
**Dependencies**: Tasks 1.2, 2.1
**Acceptance**:
- [ ] RecipeStore loads all recipes from folder
- [ ] Recipes parsed and stored in memory
- [ ] Store updates when files change
- [ ] Background parsing doesn't block UI
- [ ] Invalid files handled with error state
- [ ] Cache mechanism to avoid re-parsing

**Implementation Steps**:
1. Create `Core/Services/RecipeStore.swift`
2. Implement store with @Observable:
   ```swift
   @Observable
   class RecipeStore {
       var recipes: [Recipe] = []
       var parseErrors: [URL: Error] = [:]
       var isLoading = false

       private let parser: RecipeMDParser
       private let fileMonitor: RecipeFileMonitor

       func loadRecipes(from folder: URL) async
       func refreshRecipes() async
       private func parseRecipe(at url: URL) -> Recipe?
   }
   ```
3. Parse files on background thread using async/await
4. Cache parsed recipes with file modification date
5. Only re-parse if file modified date changed
6. Update recipes array on main thread for UI updates

**Files to Create**:
- `Core/Services/RecipeStore.swift`

**Testing**:
- Load folder with multiple recipes
- Verify all valid recipes loaded
- Verify invalid recipes tracked in parseErrors
- Verify background parsing doesn't freeze UI
- Test cache: modify file, verify re-parse; don't modify, verify cache used

---

## Phase 3: UI Components

### Task 3.1: Create RecipeCard View Component
**Complexity**: 3 points (Medium)
**Dependencies**: Task 1.1
**Acceptance**:
- [ ] RecipeCard displays recipe title
- [ ] Shows primary tag as colored chip
- [ ] Shows first line of description (if available)
- [ ] Has subtle shadow/border
- [ ] Supports tap gesture
- [ ] Accessible with VoiceOver

**Implementation Steps**:
1. Create `Features/RecipeList/Views/RecipeCard.swift`
2. Design card layout:
   ```swift
   struct RecipeCard: View {
       let recipe: Recipe

       var body: some View {
           VStack(alignment: .leading, spacing: 8) {
               // Title
               Text(recipe.title)
                   .font(.headline)
                   .lineLimit(2)

               // Primary tag chip
               if let tag = recipe.primaryTag {
                   Text(tag)
                       .font(.caption)
                       .padding(.horizontal, 8)
                       .padding(.vertical, 4)
                       .background(Color.blue.opacity(0.2))
                       .cornerRadius(4)
               }

               // Description preview
               if let desc = recipe.description {
                   Text(desc)
                       .font(.caption)
                       .foregroundStyle(.secondary)
                       .lineLimit(1)
               }
           }
           .padding()
           .frame(maxWidth: .infinity, alignment: .leading)
           .background(Color(.systemBackground))
           .cornerRadius(8)
           .shadow(radius: 2)
       }
   }
   ```
3. Add accessibility labels
4. Create preview with sample data

**Files to Create**:
- `Features/RecipeList/Views/RecipeCard.swift`

**Testing**:
- Preview in Xcode canvas
- Test with different recipe data
- Test VoiceOver navigation
- Test Dynamic Type scaling

---

### Task 3.2: Create Empty State View
**Complexity**: 2 points (Simple)
**Dependencies**: None
**Acceptance**:
- [ ] Shows friendly illustration/icon
- [ ] "No recipes yet" message
- [ ] Subtitle with helpful hint
- [ ] Optional CTA button to add recipe
- [ ] Centered on screen

**Implementation Steps**:
1. Create `Features/RecipeList/Views/RecipeListEmptyState.swift`
2. Design empty state:
   ```swift
   struct RecipeListEmptyState: View {
       var body: some View {
           VStack(spacing: 24) {
               Image(systemName: "book.closed")
                   .font(.system(size: 80))
                   .foregroundStyle(.secondary)

               Text("No Recipes Yet")
                   .font(.title2)
                   .bold()

               Text("Tap the + button to add your first recipe")
                   .font(.body)
                   .foregroundStyle(.secondary)
                   .multilineTextAlignment(.center)
           }
           .padding()
       }
   }
   ```
3. Add accessibility
4. Create preview

**Files to Create**:
- `Features/RecipeList/Views/RecipeListEmptyState.swift`

**Testing**:
- Preview in Xcode
- Test with VoiceOver

---

### Task 3.3: Create RecipeListView (iPhone)
**Complexity**: 4 points (Medium-Hard)
**Dependencies**: Tasks 2.2, 3.1, 3.2
**Acceptance**:
- [ ] Displays list of recipes using RecipeCard
- [ ] Shows empty state when no recipes
- [ ] Pull-to-refresh functionality
- [ ] Loading indicator while parsing
- [ ] Smooth scrolling performance
- [ ] Navigation bar with title and + button
- [ ] Uses NavigationStack for iPhone navigation pattern

**Implementation Steps**:
1. Create `Features/RecipeList/Views/RecipeListView.swift`
2. Create ViewModel:
   ```swift
   @Observable
   class RecipeListViewModel {
       var recipeStore: RecipeStore
       var isRefreshing = false

       init(recipeStore: RecipeStore) {
           self.recipeStore = recipeStore
       }

       func loadRecipes(folder: URL) async {
           await recipeStore.loadRecipes(from: folder)
       }

       func refresh() async {
           isRefreshing = true
           await recipeStore.refreshRecipes()
           isRefreshing = false
       }
   }
   ```
3. Create view:
   ```swift
   struct RecipeListView: View {
       @Environment(FolderManager.self) private var folderManager
       @State private var viewModel: RecipeListViewModel

       var body: some View {
           NavigationStack {
               Group {
                   if viewModel.recipeStore.recipes.isEmpty {
                       RecipeListEmptyState()
                   } else {
                       List(viewModel.recipeStore.recipes) { recipe in
                           RecipeCard(recipe: recipe)
                               .listRowSeparator(.hidden)
                       }
                       .listStyle(.plain)
                       .refreshable {
                           await viewModel.refresh()
                       }
                   }
               }
               .navigationTitle("Recipes")
               .toolbar {
                   ToolbarItem(placement: .primaryAction) {
                       Button {
                           // Add recipe action
                       } label: {
                           Image(systemName: "plus")
                       }
                   }
               }
               .task {
                   if let folder = folderManager.selectedFolderURL {
                       await viewModel.loadRecipes(folder: folder)
                   }
               }
           }
       }
   }
   ```
4. Add loading overlay for initial load

**Files to Create**:
- `Features/RecipeList/Views/RecipeListView.swift`

**Testing**:
- Test with empty folder on iPhone
- Test with populated folder on iPhone
- Test pull-to-refresh
- Test adding file externally and refreshing
- Test scroll performance with many recipes
- Verify navigation stack behavior

---

### Task 3.4: Create RecipeListSplitView (iPad)
**Complexity**: 5 points (Hard)
**Dependencies**: Tasks 2.2, 3.1, 3.2
**Acceptance**:
- [ ] Uses NavigationSplitView for iPad layout
- [ ] Recipe list displayed in left sidebar (30-40% width)
- [ ] Recipe detail view (or placeholder) in right pane
- [ ] Selected recipe highlighted in list
- [ ] Detail pane updates when selecting different recipes
- [ ] Split view persists in landscape and portrait
- [ ] Pull-to-refresh in sidebar
- [ ] Shows empty state when no recipes
- [ ] Smooth scrolling and selection

**Implementation Steps**:
1. Create `Features/RecipeList/Views/RecipeListSplitView.swift`
2. Extend ViewModel to track selection:
   ```swift
   @Observable
   class RecipeListViewModel {
       var recipeStore: RecipeStore
       var isRefreshing = false
       var selectedRecipe: Recipe? = nil // For iPad split view

       func selectRecipe(_ recipe: Recipe) {
           selectedRecipe = recipe
       }
   }
   ```
3. Create split view:
   ```swift
   struct RecipeListSplitView: View {
       @Environment(FolderManager.self) private var folderManager
       @State private var viewModel: RecipeListViewModel

       var body: some View {
           NavigationSplitView {
               // Sidebar - Recipe List
               Group {
                   if viewModel.recipeStore.recipes.isEmpty {
                       RecipeListEmptyState()
                   } else {
                       List(viewModel.recipeStore.recipes, selection: $viewModel.selectedRecipe) { recipe in
                           RecipeCard(recipe: recipe)
                               .listRowSeparator(.hidden)
                               .onTapGesture {
                                   viewModel.selectRecipe(recipe)
                               }
                       }
                       .listStyle(.plain)
                       .refreshable {
                           await viewModel.refresh()
                       }
                   }
               }
               .navigationTitle("Recipes")
               .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 500)
               .toolbar {
                   ToolbarItem(placement: .primaryAction) {
                       Button {
                           // Add recipe action
                       } label: {
                           Image(systemName: "plus")
                       }
                   }
               }
           } detail: {
               // Detail pane
               if let recipe = viewModel.selectedRecipe {
                   // Placeholder for recipe detail view
                   RecipeDetailPlaceholder(recipe: recipe)
               } else {
                   Text("Select a recipe")
                       .foregroundStyle(.secondary)
               }
           }
           .task {
               if let folder = folderManager.selectedFolderURL {
                   await viewModel.loadRecipes(folder: folder)
               }
           }
       }
   }

   // Temporary placeholder until F004 implements full detail view
   struct RecipeDetailPlaceholder: View {
       let recipe: Recipe

       var body: some View {
           VStack {
               Text(recipe.title)
                   .font(.title)
               Text("Detail view coming in F004")
                   .foregroundStyle(.secondary)
           }
       }
   }
   ```
4. Add loading overlay for initial load
5. Test on iPad simulator in both orientations

**Files to Create**:
- `Features/RecipeList/Views/RecipeListSplitView.swift`

**Testing**:
- Test on iPad simulator (all sizes)
- Test with empty folder
- Test with populated folder
- Test selection highlighting
- Test detail pane updates
- Test pull-to-refresh
- Rotate to portrait and landscape
- Verify split view persists
- Test scroll performance

---

### Task 3.5: Create Platform-Adaptive Container View
**Complexity**: 2 points (Simple)
**Dependencies**: Tasks 3.3, 3.4
**Acceptance**:
- [ ] Detects device idiom (iPhone vs iPad)
- [ ] Shows RecipeListSplitView on iPad
- [ ] Shows RecipeListView on iPhone
- [ ] Shares same RecipeListViewModel instance
- [ ] No code duplication
- [ ] Adapts correctly when running on different devices

**Implementation Steps**:
1. Create `Features/RecipeList/Views/RecipeLibraryContainerView.swift`
2. Implement adaptive container:
   ```swift
   struct RecipeLibraryContainerView: View {
       @Environment(FolderManager.self) private var folderManager
       @State private var recipeStore = RecipeStore()

       var body: some View {
           if UIDevice.current.userInterfaceIdiom == .pad {
               RecipeListSplitView(
                   viewModel: RecipeListViewModel(recipeStore: recipeStore)
               )
               .environment(recipeStore)
           } else {
               RecipeListView(
                   viewModel: RecipeListViewModel(recipeStore: recipeStore)
               )
               .environment(recipeStore)
           }
       }
   }
   ```
3. Optionally use `@Environment(\.horizontalSizeClass)` for more granular adaptation
4. Create preview for both iPhone and iPad

**Files to Create**:
- `Features/RecipeList/Views/RecipeLibraryContainerView.swift`

**Testing**:
- Run on iPhone simulator (verify RecipeListView)
- Run on iPad simulator (verify RecipeListSplitView)
- Test with different iPad sizes
- Test with iPhone in landscape (should still use RecipeListView)
- Preview both variants in Xcode

---

## Phase 4: Integration & Polish

### Task 4.1: Integrate RecipeLibraryContainerView into MainTabView
**Complexity**: 1 point (Simple)
**Dependencies**: Task 3.5
**Acceptance**:
- [ ] RecipeLibraryContainerView replaces ContentView in Recipes tab
- [ ] Shows correct view on iPhone vs iPad
- [ ] Navigation works correctly on both platforms
- [ ] App builds and runs on both iPhone and iPad

**Implementation Steps**:
1. Update `App/MainTabView.swift`:
   ```swift
   struct MainTabView: View {
       @Environment(FolderManager.self) private var folderManager

       var body: some View {
           TabView {
               RecipeLibraryContainerView()
                   .tabItem {
                       Label("Recipes", systemImage: "book")
                   }

               SettingsView()
                   .tabItem {
                       Label("Settings", systemImage: "gear")
                   }
           }
       }
   }
   ```
2. Remove ContentView placeholder if present
3. Build and test on both iPhone and iPad simulators

**Files to Modify**:
- `App/MainTabView.swift`

**Testing**:
- Build app on iPhone simulator
- Navigate to Recipes tab, verify RecipeListView (NavigationStack)
- Build app on iPad simulator
- Navigate to Recipes tab, verify RecipeListSplitView
- Verify tab switching works on both
- Test rotation on iPad (verify split view persists)

---

### Task 4.2: Add Loading State UI
**Complexity**: 2 points (Simple)
**Dependencies**: Task 3.3
**Acceptance**:
- [ ] Show skeleton cards while loading
- [ ] Or show progress indicator for large collections
- [ ] Smooth transition from loading to loaded state
- [ ] Loading doesn't block UI interaction

**Implementation Steps**:
1. Create `Features/RecipeList/Views/RecipeCardSkeleton.swift`:
   ```swift
   struct RecipeCardSkeleton: View {
       var body: some View {
           VStack(alignment: .leading, spacing: 8) {
               // Skeleton title
               RoundedRectangle(cornerRadius: 4)
                   .fill(Color.gray.opacity(0.3))
                   .frame(height: 20)
                   .frame(maxWidth: 200)

               // Skeleton tag
               RoundedRectangle(cornerRadius: 4)
                   .fill(Color.gray.opacity(0.3))
                   .frame(width: 60, height: 16)

               // Skeleton description
               RoundedRectangle(cornerRadius: 4)
                   .fill(Color.gray.opacity(0.3))
                   .frame(height: 14)
           }
           .padding()
           .background(Color(.systemBackground))
           .cornerRadius(8)
           .shadow(radius: 2)
           .redacted(reason: .placeholder)
       }
   }
   ```
2. Update RecipeListView to show skeletons when loading:
   ```swift
   if viewModel.recipeStore.isLoading {
       List(0..<5, id: \.self) { _ in
           RecipeCardSkeleton()
               .listRowSeparator(.hidden)
       }
       .listStyle(.plain)
   } else if viewModel.recipeStore.recipes.isEmpty {
       // Empty state
   } else {
       // Recipe list
   }
   ```

**Files to Create**:
- `Features/RecipeList/Views/RecipeCardSkeleton.swift`

**Files to Modify**:
- `Features/RecipeList/Views/RecipeListView.swift`

**Testing**:
- Simulate slow loading (add delay)
- Verify skeleton appears
- Verify smooth transition

---

### Task 4.3: Add Error Handling UI
**Complexity**: 2 points (Simple)
**Dependencies**: Task 3.3
**Acceptance**:
- [ ] Invalid RecipeMD files shown with warning icon
- [ ] Tap warning to see error details
- [ ] Alert with parsing error message
- [ ] Option to dismiss

**Implementation Steps**:
1. Update RecipeCard to show error state:
   ```swift
   struct RecipeCard: View {
       let recipe: Recipe?
       let error: Error?

       var body: some View {
           if let recipe = recipe {
               // Normal card
           } else if let error = error {
               HStack {
                   Image(systemName: "exclamationmark.triangle")
                       .foregroundStyle(.orange)
                   Text("Parse Error")
                       .foregroundStyle(.secondary)
                   Spacer()
               }
               .padding()
           }
       }
   }
   ```
2. Update RecipeListView to show parse errors:
   ```swift
   List {
       ForEach(viewModel.recipeStore.recipes) { recipe in
           RecipeCard(recipe: recipe, error: nil)
       }

       ForEach(Array(viewModel.recipeStore.parseErrors.keys), id: \.self) { url in
           RecipeCard(recipe: nil, error: viewModel.recipeStore.parseErrors[url])
               .onTapGesture {
                   // Show error details
               }
       }
   }
   ```
3. Add alert for error details

**Files to Modify**:
- `Features/RecipeList/Views/RecipeCard.swift`
- `Features/RecipeList/Views/RecipeListView.swift`

**Testing**:
- Add invalid .md file to folder
- Verify error card appears
- Tap card, verify alert with error details

---

## Phase 5: Performance & Testing

### Task 5.1: Implement Caching Strategy
**Complexity**: 3 points (Medium)
**Dependencies**: Task 2.2
**Acceptance**:
- [ ] Parsed recipes cached with modification date
- [ ] Only re-parse if file changed
- [ ] Cache persists across app launches (optional)
- [ ] Memory-efficient for large collections

**Implementation Steps**:
1. Add caching to RecipeStore:
   ```swift
   private var recipeCache: [URL: (recipe: Recipe, modDate: Date)] = [:]

   private func parseRecipe(at url: URL) async -> Recipe? {
       let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
       let modDate = attributes?[.modificationDate] as? Date

       // Check cache
       if let cached = recipeCache[url],
          cached.modDate == modDate {
           return cached.recipe
       }

       // Parse and cache
       if let recipe = try? parser.parseMetadata(from: url) {
           recipeCache[url] = (recipe, modDate ?? Date())
           return recipe
       }
       return nil
   }
   ```
2. Clear cache when folder changes
3. Optionally persist cache to UserDefaults or file

**Files to Modify**:
- `Core/Services/RecipeStore.swift`

**Testing**:
- Load 100 recipes, time it
- Reload without file changes, verify much faster
- Modify one file, verify only that file re-parsed

---

### Task 5.2: Write Unit Tests
**Complexity**: 3 points (Medium)
**Dependencies**: All implementation tasks
**Acceptance**:
- [ ] RecipeMDParser tests cover all parsing scenarios
- [ ] RecipeStore tests cover loading and caching
- [ ] RecipeFileMonitor tests (if testable)
- [ ] 80%+ code coverage on core services

**Implementation Steps**:
1. Expand `RecipeMDParserTests.swift`:
   - Test valid RecipeMD files
   - Test malformed files
   - Test edge cases (no title, no tags, etc.)
2. Create `RecipeStoreTests.swift`:
   - Test loading recipes
   - Test caching behavior
   - Test error handling
3. Create sample RecipeMD files for testing
4. Run tests and verify passing

**Files to Create**:
- `OpenCookbookTests/RecipeStoreTests.swift`
- `OpenCookbookTests/TestRecipes/` (sample .md files)

**Testing**:
- Run all tests (Cmd+U)
- Check coverage report
- Fix any failing tests

---

### Task 5.3: Performance Testing & Optimization
**Complexity**: 2 points (Simple)
**Dependencies**: Task 5.1
**Acceptance**:
- [ ] Test with 500+ recipe files
- [ ] Load time < 3s
- [ ] Scrolling at 60fps minimum
- [ ] Memory usage reasonable
- [ ] No UI freezing

**Implementation Steps**:
1. Generate 500 test RecipeMD files using script
2. Load in app and measure:
   - Time to first display
   - Scroll performance (use Instruments)
   - Memory usage
3. Optimize if needed:
   - Ensure background parsing
   - Use lazy loading
   - Limit cache size if memory issue
4. Document performance benchmarks

**Testing**:
- Create 500 recipe files
- Launch app and time load
- Scroll rapidly through list
- Monitor with Instruments

---

### Task 5.4: Manual QA Testing
**Complexity**: 1 point (Simple)
**Dependencies**: All tasks
**Acceptance**:
- [ ] All test cases from spec executed
- [ ] Edge cases documented
- [ ] Bug fixes applied

**QA Checklist**:
- [ ] TC-004: Display recipe list (5 recipes)
- [ ] TC-005: Empty state with empty folder
- [ ] TC-006: Pull-to-refresh after adding file externally
- [ ] TC-007: Invalid file with warning icon
- [ ] TC-008: Performance with 500 recipes
- [ ] TC-009: iPad split view layout
  - [ ] Recipe list on left
  - [ ] Detail on right
  - [ ] Selection highlighting works
  - [ ] Detail updates on selection
  - [ ] Persists in portrait and landscape
- [ ] TC-010: iPhone navigation layout
  - [ ] Full-width list
  - [ ] Navigation to detail
  - [ ] Back button works
  - [ ] No split view
- [ ] Test recipe card tap (navigation placeholder on iPhone, selection on iPad)
- [ ] Test + button (add recipe placeholder)
- [ ] Test with various screen sizes (iPhone SE, Pro Max, iPad mini, iPad Pro)
- [ ] Test with VoiceOver on both iPhone and iPad
- [ ] Test with Dynamic Type

**Deliverable**:
- Document results in `docs/qa/f002-test-results.md`

---

## Summary

**Total Tasks**: 17
**Total Complexity**: 39 points

**Phases**:
1. Data Models & Parser: 6 points (2 tasks)
2. File System Integration: 12 points (3 tasks)
3. UI Components: 16 points (5 tasks)
4. Integration & Polish: 5 points (3 tasks)
5. Performance & Testing: 9 points (4 tasks)

**Recommended Sprint Planning**:
- Sprint 1: Phases 1-2 (Foundation - parser, file monitoring, store)
- Sprint 2: Phase 3 (UI Components - both iPhone and iPad views)
- Sprint 3: Phases 4-5 (Integration, performance, testing on both platforms)

**Critical Path**:
Task 1.1 → 1.2 → 2.2 → 3.3/3.4 → 3.5 → 4.1

**Parallel Work Opportunities**:
- Task 2.1 (FileMonitor) can be done alongside 1.2 (Parser)
- Task 3.1, 3.2 (UI components) can be done before 2.2 is complete
- Task 3.3 and 3.4 (iPhone and iPad views) can be developed in parallel by different developers
- Task 5.1 (Caching) can be done anytime after 2.2

**Key Dependencies**:
- swift-markdown library (if using) - Add via SPM
- RecipeMD test files for testing
- FolderManager integration from F001
- UIDevice.current.userInterfaceIdiom for platform detection

**Notes**:
- This implements platform-adaptive list view (iPhone + iPad)
- iPhone uses NavigationStack with standard navigation pattern
- iPad uses NavigationSplitView with persistent sidebar and detail pane
- Grid view is out of scope (v2.0)
- Recipe detail view is placeholder (F004 implements full detail view)
- Add recipe button is placeholder (F005 implements add/edit)
- No sorting/filtering in v1.0 (basic alphabetical order)
- Testing must cover both iPhone and iPad platforms
