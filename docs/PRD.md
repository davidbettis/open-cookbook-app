# Product Requirements Document: OpenCookbook

## Executive Summary
OpenCookbook is an iOS app that provides home chefs with a modern, native interface for managing their recipe collection using the open RecipeMD format. By storing recipes on iCloud Drive in a user-managed folder, OpenCookbook ensures data portability and user ownership while providing a seamless SwiftUI experience for viewing, creating, editing, and searching recipes.

## Problem Statement
Many recipe management apps lock users into proprietary formats and closed ecosystems, making it difficult to export, share, or migrate recipe collections. Home chefs need a solution that:
- Stores recipes in an open, human-readable format (RecipeMD)
- Gives users full control over their data via iCloud Drive
- Provides a native iOS experience for recipe management
- Allows seamless editing of recipe structure and metadata

## Target Users
- **Primary**: Home chefs who value data ownership and want to manage their recipe collection in an open format
- **Secondary**: Users transitioning from other recipe apps who want to preserve their recipes in a future-proof format

## Success Metrics
| Metric | Target | Measurement |
|--------|--------|-------------|
| User Retention | 40% D7 | Analytics |
| App Rating | 4.5+ | App Store |
| Crash-Free Rate | 99.5% | Crashlytics |
| Avg. Recipes per User | 25+ by D30 | Analytics |
| Search Success Rate | 85%+ | Analytics |

## Core Features

Detailed feature specifications with user stories, acceptance criteria, test cases, and UI/UX requirements are available in the `docs/specs/` directory.

### Feature 1: iCloud Drive Folder Selection (P0)
On first launch, users browse and select an iCloud Drive folder to use as their recipe storage location. The app persists this selection and monitors the folder for changes.

📄 **Full Spec**: [docs/specs/icloud-folder-selection.md](specs/icloud-folder-selection.md)

**Key Requirements**:
- Folder picker on first launch
- Persistent folder selection (security-scoped bookmarks)
- Settings to change folder location
- Real-time folder monitoring

### Feature 2: Recipe Library View (P0)
Display all RecipeMD files from the selected iCloud folder in a scrollable list view with recipe names and tags.

📄 **Full Spec**: [docs/specs/recipe-library-view.md](specs/recipe-library-view.md)

**Key Requirements**:
- List all recipes with titles and tags
- Pull-to-refresh support
- Empty state UI
- Graceful error handling for invalid files

### Feature 3: Recipe Search & Filtering (P0)
Search recipes by title, ingredients, tags, or recipe content. Filter by tags defined in RecipeMD format.

📄 **Full Spec**: [docs/specs/recipe-search-filtering.md](specs/recipe-search-filtering.md)

**Key Requirements**:
- Real-time search across all recipe fields
- Tag-based filtering with multi-select
- Case-insensitive matching
- Debounced search input (250ms)

### Feature 4: Recipe Detail View (P0)
Display full recipe content with formatted sections for ingredients, instructions, metadata (yields, tags), organized according to RecipeMD structure.

📄 **Full Spec**: [docs/specs/recipe-detail-view.md](specs/recipe-detail-view.md)

**Key Requirements**:
- Display all RecipeMD sections (title, description, tags, yields, ingredients, instructions)
- Support ingredient groups
- Markdown formatting in instructions
- Dynamic Type support

### Feature 5: Add New Recipe (P0)
Create new recipes using a form-based UI that maps to RecipeMD format structure. Save as .md file in selected iCloud folder.

📄 **Full Spec**: [docs/specs/add-new-recipe.md](specs/add-new-recipe.md)

**Key Requirements**:
- Form with all RecipeMD fields
- Dynamic ingredient list (add/remove)
- Form validation
- Generate valid RecipeMD file with proper formatting

### Feature 6: Edit Existing Recipe (P0)
Edit all aspects of an existing recipe, preserving RecipeMD format. Changes save back to the original .md file in iCloud.

📄 **Full Spec**: [docs/specs/edit-recipe.md](specs/edit-recipe.md)

**Key Requirements**:
- Reuse add recipe form with pre-populated data
- Atomic file write operation
- Unsaved changes warning
- Handle external file modifications

### Feature 7: Delete Recipe (P1)
Allow users to delete recipes from their collection, removing the file from iCloud Drive.

📄 **Full Spec**: [docs/specs/delete-recipe.md](specs/delete-recipe.md)

**Key Requirements**:
- Delete from detail view or list swipe action
- Confirmation dialog
- Permanent deletion from iCloud Drive
- Error handling for locked/missing files

## Non-Functional Requirements
- **Performance**:
  - App launch < 2s
  - Recipe list scrolling at 60fps (120fps on ProMotion devices)
  - Search results displayed < 300ms for collections under 500 recipes
  - File parsing < 100ms per recipe

- **Accessibility**:
  - VoiceOver support for all interactive elements
  - Dynamic Type support (text scales appropriately)
  - Minimum contrast ratios (WCAG 2.1 AA)
  - VoiceControl compatible navigation

- **Localization**:
  - English (primary)
  - UI strings externalized for future localization

- **Security**:
  - Security-scoped bookmarks for iCloud folder access
  - No collection of user data or analytics without consent
  - Files only accessible within user's iCloud sandbox

- **Data Integrity**:
  - Atomic file writes to prevent corruption
  - Backup/preservation of original file on edit failures
  - Validation of RecipeMD format before save

## RecipeMD Format Specification
OpenCookbook adheres to the **RecipeMD v2.4.0 specification**, a Markdown-based format following CommonMark standards.

### Structure Overview
A RecipeMD document has this sequential structure:

1. **Title** (required): First-level heading `# Recipe Name`
2. **Description** (optional): Zero or more paragraphs
3. **Tags** (optional): Italicized paragraph with comma-separated values: `*tag1, tag2, tag3*`
4. **Yields** (optional): Bold paragraph with comma-separated amounts: `**serves 4, makes 12 cookies**`
5. **Horizontal divider** (required): `---`
6. **Ingredients** (required): Markdown lists with optional amounts in italics
7. **Horizontal divider** (optional): `---`
8. **Instructions** (optional): Remaining document content in markdown

### Example RecipeMD File
```markdown
# Chocolate Chip Cookies

Classic homemade chocolate chip cookies with a chewy center and crispy edges.

*dessert, baking, quick*

**makes 24 cookies**

---

- *2 1/4 cups* all-purpose flour
- *1 tsp* baking soda
- *1 cup* butter, softened
- *3/4 cup* granulated sugar
- *3/4 cup* packed brown sugar
- *2 large* eggs
- *2 tsp* vanilla extract
- *2 cups* chocolate chips

---

1. Preheat oven to 375°F (190°C)
2. Mix flour and baking soda in a bowl
3. In a separate bowl, cream together butter and sugars
4. Beat in eggs and vanilla to butter mixture
5. Gradually blend in flour mixture
6. Stir in chocolate chips
7. Drop rounded tablespoons onto ungreased cookie sheets
8. Bake for 10-12 minutes until golden brown
9. Cool on baking sheet for 2 minutes before transferring to wire rack
```

### Key Format Details

**Amounts**: Support fractions (1/2, ½), decimals (1.5), and integers (2)

**Ingredient Groups**: Use headings to create groups:
```markdown
## For the Dough
- *2 cups* flour
- *1 tsp* salt

## For the Filling
- *1 cup* cream cheese
```

**Recipe Links**: Ingredients can reference other recipes using inline links:
```markdown
- *2 cups* [marinara sauce](marinara.md)
```

**No YAML**: Unlike some recipe formats, RecipeMD uses pure Markdown syntax—no frontmatter.

## Out of Scope (v1.0)
- Meal planning calendar
- Shopping list generation
- Recipe scaling/conversion
- Social features (sharing recipes online, comments)
- Recipe import from websites
- Multi-device sync beyond iCloud Drive
- Recipe ratings or favorites (can be added via tags in RecipeMD)
- Voice-guided cooking mode
- Nutritional information calculation
- Recipe printing or PDF export
- Unit conversion tools
- Ingredient group management (will display but simple add/edit in v1.0)
- Recipe linking (will parse but not navigate between linked recipes)

## Technical Constraints
- Swift 6.0+ with strict concurrency
- SwiftUI-only (no UIKit unless necessary for file picker)
- CommonMark-compliant parser for RecipeMD (consider swift-markdown or custom)
- Minimum iOS 17.0
- iCloud Drive entitlement required
- FileProvider framework for folder monitoring
- Local file caching with iCloud Drive as source of truth

## Open Questions & Risks
- **Risk**: RecipeMD format variations in the wild may cause parsing issues
  - Mitigation: Implement lenient parser with fallbacks; log parse errors; adhere strictly to v2.4.0 spec

- **Risk**: iCloud sync delays may cause confusion if files don't appear immediately
  - Mitigation: Show sync status indicator; provide manual refresh

- **Question**: Should app support sub-folders within selected recipe folder?
  - Decision needed: Scan recursively or only top-level files?

- **Question**: How to handle ingredient groups in add/edit UI?
  - v1.0 decision: Simple flat list; groups displayed in detail view but simplified in editor

- **Question**: How to render recipe links between ingredients?
  - v1.0 decision: Display as text; make tappable links in v2.0

## Future Enhancements (Post v1.0)
- Recipe import from URL (web scraping)
- Export/share individual recipes
- Duplicate recipe feature
- Recipe templates for common formats
- Dark mode optimization
- iPad-optimized layout (split view)
- macOS companion app
- Recipe history/versioning (git integration)
- Collaborative editing (shared iCloud folders)
- Full ingredient group editing support
- Recipe linking navigation (tap linked ingredients to open that recipe)
- Ingredient autocomplete based on existing recipes
- Bulk tag editing
- Recipe scaling with automatic unit conversion

## Technical Architecture Notes

### RecipeMD Parser Requirements
Based on specification v2.4.0, the parser must:
1. Parse CommonMark into AST (use swift-markdown)
2. Extract H1 heading as title
3. Extract paragraphs before first HR as description
4. Parse italic paragraphs as comma-separated tags
5. Parse bold paragraphs as comma-separated yields
6. Parse lists after first HR as ingredients with optional italic amounts
7. Handle ingredient groups via heading hierarchy (H2, H3, etc.)
8. Parse remaining content after ingredients as instructions

### File Monitoring Strategy
- Use `FileManager` with `DispatchSource.makeFileSystemObjectSource` for folder monitoring
- Debounce file system events to avoid excessive reloads
- Re-parse only changed files (track modification dates)
- Handle iCloud download on-demand (placeholder files)

### Data Model
```swift
@Observable
class Recipe {
    var title: String
    var description: String?
    var tags: [String]
    var yields: [String]
    var ingredients: [Ingredient]
    var ingredientGroups: [IngredientGroup]
    var instructions: String?
    var filePath: URL
}

struct Ingredient {
    var amount: Amount?
    var name: String
    var linkedRecipe: String? // For recipe links
}

struct Amount {
    var value: Double
    var unit: String?
}

struct IngredientGroup {
    var title: String
    var ingredients: [Ingredient]
    var subgroups: [IngredientGroup]
}
```

## Timeline
| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Architecture & Setup | 1 week | Project structure, RecipeMD parser, iCloud setup |
| Core Features (List, Detail, Search) | 3 weeks | Browse and search recipes |
| CRUD Operations (Add, Edit, Delete) | 2 weeks | Full recipe management |
| Polish & Testing | 2 weeks | Bug fixes, accessibility, performance |
| App Store Prep | 1 week | Screenshots, metadata, submission |

**Total: 9 weeks to v1.0**
