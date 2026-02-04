# Task Breakdown: Portion Scaling (F008)

**Spec**: [docs/specs/portion-scaling.md](../specs/portion-scaling.md)
**Priority**: P1 (Should Have)

---

## Task 1: Create PortionOption Model

**Complexity**: Low
**Dependencies**: None

### Description
Create the data model representing portion scaling options with their multipliers.

### Implementation Steps
1. Create `Core/Models/PortionOption.swift`
2. Define `PortionOption` struct with:
   - `id: String` - unique identifier
   - `label: String` - display text (e.g., "Half (0.5x)")
   - `multiplier: Double` - scaling factor
3. Add static properties for preset options:
   - `.half` - multiplier 0.5
   - `.whole` - multiplier 1.0
   - `.double` - multiplier 2.0
4. Add `static let allOptions: [PortionOption]` array
5. Conform to `Identifiable`, `Hashable`, `Equatable`

### Code Example
```swift
struct PortionOption: Identifiable, Hashable {
    let id: String
    let label: String
    let multiplier: Double

    static let half = PortionOption(id: "half", label: "Half (0.5x)", multiplier: 0.5)
    static let whole = PortionOption(id: "whole", label: "Whole (1x)", multiplier: 1.0)
    static let double = PortionOption(id: "double", label: "Double (2x)", multiplier: 2.0)

    static let allOptions: [PortionOption] = [.half, .whole, .double]
}
```

### Acceptance Criteria
- [ ] PortionOption model created with all properties
- [ ] Three preset options defined (half, whole, double)
- [ ] Model conforms to required protocols

---

## Task 2: Create PortionSelectorView Component

**Complexity**: Low
**Dependencies**: Task 1

### Description
Create a dropdown picker component for selecting portion size.

### Implementation Steps
1. Create `Features/RecipeDetail/Views/PortionSelectorView.swift`
2. Accept `@Binding var selectedPortion: PortionOption`
3. Use SwiftUI `Picker` with `.menu` style for dropdown behavior
4. Display all options from `PortionOption.allOptions`
5. Add accessibility label "Portion size"
6. Style to match app design

### Code Example
```swift
struct PortionSelectorView: View {
    @Binding var selectedPortion: PortionOption

    var body: some View {
        HStack {
            Text("Portions:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Portion size", selection: $selectedPortion) {
                ForEach(PortionOption.allOptions) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Portion size")
        }
    }
}
```

### Acceptance Criteria
- [ ] Dropdown displays all three portion options
- [ ] Selection updates the binding
- [ ] Accessible via VoiceOver
- [ ] Uses system menu picker style

---

## Task 3: Create Scaling Helper Functions

**Complexity**: Medium
**Dependencies**: Task 1

### Description
Create utility functions to scale ingredient amounts and format results cleanly.

### Implementation Steps
1. Create `Core/Extensions/Amount+Scaling.swift`
2. Add `func scaled(by multiplier: Double) -> Amount` extension on RecipeMD `Amount`
3. Add `var scaledFormatted: String` computed property that formats cleanly:
   - Whole numbers: no decimal (e.g., "2" not "2.0")
   - Clean decimals: max 2 places, trim trailing zeros
4. Create `Core/Extensions/Yield+Scaling.swift`
5. Add `func scaled(by multiplier: Double) -> Yield` extension
6. Handle yield amount scaling and formatting

### Code Example
```swift
extension Amount {
    func scaled(by multiplier: Double) -> Amount {
        let newValue = self.amount * multiplier
        return Amount(amount: newValue, unit: self.unit, rawText: nil)
    }

    func formattedScaled(by multiplier: Double) -> String {
        let scaledValue = self.amount * multiplier
        let formatted: String
        if scaledValue.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = String(format: "%.0f", scaledValue)
        } else {
            formatted = String(format: "%.2g", scaledValue)
        }
        if let unit = self.unit {
            return "\(formatted) \(unit)"
        }
        return formatted
    }
}
```

### Acceptance Criteria
- [ ] Amount scaling produces correct values
- [ ] Formatting removes unnecessary decimals
- [ ] Yield scaling works for single and multiple yields
- [ ] Unit tests pass

---

## Task 4: Update IngredientsListView for Scaling

**Complexity**: Medium
**Dependencies**: Tasks 1, 3

### Description
Update IngredientsListView to accept a portion multiplier and display scaled quantities.

### Implementation Steps
1. Add `portionMultiplier: Double = 1.0` parameter to `IngredientsListView`
2. Pass multiplier down to `IngredientGroupView`
3. Pass multiplier down to `IngredientRowDisplayView`
4. Update `displayText` to use scaled amount formatting
5. Update accessibility label with scaled values
6. Ensure ingredients without amounts remain unchanged

### Code Changes
```swift
struct IngredientsListView: View {
    let ingredientGroups: [IngredientGroup]
    var portionMultiplier: Double = 1.0  // NEW

    // Pass multiplier to child views
}

struct IngredientRowDisplayView: View {
    let ingredient: Ingredient
    var portionMultiplier: Double = 1.0  // NEW

    private var displayText: String {
        if let amount = ingredient.amount {
            let scaled = amount.formattedScaled(by: portionMultiplier)
            return "\(scaled) \(ingredient.name)"
        }
        return ingredient.name
    }
}
```

### Acceptance Criteria
- [ ] Ingredient amounts scale correctly with multiplier
- [ ] Ingredients without amounts unchanged
- [ ] Accessibility labels reflect scaled values
- [ ] Default multiplier of 1.0 preserves existing behavior

---

## Task 5: Update RecipeHeaderView for Yield Scaling

**Complexity**: Medium
**Dependencies**: Tasks 1, 3

### Description
Update RecipeHeaderView to accept a portion multiplier and display scaled yields.

### Implementation Steps
1. Add `portionMultiplier: Double = 1.0` parameter to `RecipeHeaderView`
2. Create helper to scale yield amounts
3. Update `YieldView` to display scaled yields
4. Handle multiple yields (e.g., "serves 4, makes 24 cookies")
5. Update accessibility labels

### Code Changes
```swift
struct RecipeHeaderView: View {
    let title: String
    let description: String?
    let tags: [String]
    let yield: Yield
    var portionMultiplier: Double = 1.0  // NEW

    private var scaledYieldText: String {
        // Scale yield amounts by multiplier
    }
}
```

### Acceptance Criteria
- [ ] Yield amounts scale correctly
- [ ] Multiple yields all scale properly
- [ ] Formatting is clean (no excess decimals)
- [ ] Default multiplier preserves existing behavior

---

## Task 6: Update RecipeDetailSplitContent with Portion Selector

**Complexity**: Medium
**Dependencies**: Tasks 2, 4, 5

### Description
Add portion selector to the ingredients panel header on iPad and pass multiplier to child views.

### Implementation Steps
1. Add `@Binding var selectedPortion: PortionOption` parameter
2. Add `PortionSelectorView` below "Ingredients" header in left panel
3. Pass `selectedPortion.multiplier` to `IngredientsListView`
4. Keep instructions panel unchanged (no scaling needed)

### Code Changes
```swift
struct RecipeDetailSplitContent: View {
    let ingredientGroups: [IngredientGroup]
    let instructions: String?
    @Binding var selectedPortion: PortionOption  // NEW

    private var ingredientsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Ingredients")
                // ...

            // Portion selector - NEW
            PortionSelectorView(selectedPortion: $selectedPortion)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Scrollable ingredients list with multiplier
            ScrollView {
                IngredientsListView(
                    ingredientGroups: ingredientGroups,
                    portionMultiplier: selectedPortion.multiplier
                )
            }
        }
    }
}
```

### Acceptance Criteria
- [ ] Portion selector visible in ingredients panel header
- [ ] Selecting portion updates ingredient displays
- [ ] Layout remains clean and usable

---

## Task 7: Update RecipeDetailContent to Manage Portion State

**Complexity**: Medium
**Dependencies**: Tasks 4, 5, 6

### Description
Add portion state management to the platform-adaptive container and ensure it resets when recipe changes.

### Implementation Steps
1. Add `@State private var selectedPortion: PortionOption = .whole`
2. Pass binding to `RecipeDetailSplitContent` (iPad)
3. For iPhone layout, add portion selector above ingredients
4. Pass multiplier to `RecipeHeaderView` for yield scaling
5. Reset portion to `.whole` when `recipeFile` changes (use `.onChange`)

### Code Changes
```swift
struct RecipeDetailContent: View {
    let recipeFile: RecipeFile
    let markdownContent: String

    @State private var selectedPortion: PortionOption = .whole  // NEW

    var body: some View {
        // ...
    }
    .onChange(of: recipeFile.id) { _, _ in
        selectedPortion = .whole  // Reset on recipe change
    }
}
```

### iPhone Layout Update
For iPhone, since we render full markdown, we need a different approach:
- Add portion selector UI above the markdown content
- For ingredient scaling on iPhone, consider:
  - Option A: Parse and rebuild markdown with scaled values (complex)
  - Option B: Show portion selector but note scaling only works on iPad (simpler)
  - Option C: Switch iPhone to use structured rendering like iPad (recommended)

**Recommendation**: For consistency, update iPhone to use the same structured rendering as iPad (just in vertical layout instead of split).

### Acceptance Criteria
- [ ] Portion state managed in RecipeDetailContent
- [ ] Portion resets to "Whole" when navigating to different recipe
- [ ] iPad layout fully functional with scaling
- [ ] iPhone layout includes portion selector

---

## Task 8: Update iPhone Layout for Structured Rendering

**Complexity**: Medium
**Dependencies**: Task 7

### Description
Update iPhone layout to use structured rendering (like iPad) instead of raw markdown, enabling portion scaling on both platforms.

### Implementation Steps
1. Update `iPhoneLayout` in `RecipeDetailContent` to use:
   - `RecipeHeaderView` with portion multiplier
   - `PortionSelectorView`
   - `IngredientsListView` with portion multiplier
   - `Markdown(instructions)` for instructions only
2. Arrange vertically in a ScrollView
3. Add visual separator between sections

### Code Example
```swift
private var iPhoneLayout: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            RecipeHeaderView(
                title: recipeFile.title,
                description: recipeFile.description,
                tags: recipeFile.tags,
                yield: recipeFile.yield,
                portionMultiplier: selectedPortion.multiplier
            )
            .padding(.horizontal)

            Divider()

            // Portion selector
            PortionSelectorView(selectedPortion: $selectedPortion)
                .padding(.horizontal)

            // Ingredients
            IngredientsListView(
                ingredientGroups: recipeFile.ingredientGroups,
                portionMultiplier: selectedPortion.multiplier
            )
            .padding(.horizontal)

            Divider()

            // Instructions (still markdown)
            if let instructions = recipeFile.instructions {
                Markdown(instructions)
                    .markdownTheme(.recipe)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}
```

### Acceptance Criteria
- [ ] iPhone uses structured rendering
- [ ] Portion selector visible on iPhone
- [ ] Ingredient scaling works on iPhone
- [ ] Yield scaling works on iPhone
- [ ] Instructions still render as markdown

---

## Task 9: Write Unit Tests for Portion Scaling

**Complexity**: Medium
**Dependencies**: Tasks 1-8

### Description
Create comprehensive unit tests for portion scaling functionality.

### Implementation Steps
1. Create `OpenCookbookTests/PortionScalingTests.swift`
2. Test `PortionOption` model
3. Test `Amount` scaling extension
4. Test `Yield` scaling extension
5. Test formatting (decimal cleanup)
6. Test edge cases (no amount, zero values)

### Test Cases
```swift
@Suite("Portion Scaling Tests")
struct PortionScalingTests {

    @Test("PortionOption has correct multipliers")
    func portionOptionMultipliers() {
        #expect(PortionOption.half.multiplier == 0.5)
        #expect(PortionOption.whole.multiplier == 1.0)
        #expect(PortionOption.double.multiplier == 2.0)
    }

    @Test("Amount scales correctly for half")
    func amountScalesHalf() {
        let amount = Amount(2, unit: "cups")
        let scaled = amount.formattedScaled(by: 0.5)
        #expect(scaled == "1 cups")
    }

    @Test("Amount scales correctly for double")
    func amountScalesDouble() {
        let amount = Amount(1, unit: "cup")
        let scaled = amount.formattedScaled(by: 2.0)
        #expect(scaled == "2 cup")
    }

    @Test("Decimal formatting removes trailing zeros")
    func decimalFormatting() {
        let amount = Amount(1, unit: "cup")
        let scaled = amount.formattedScaled(by: 0.5)
        #expect(scaled == "0.5 cup")  // Not "0.50"
    }

    @Test("Whole numbers display without decimal")
    func wholeNumberFormatting() {
        let amount = Amount(2, unit: "cups")
        let scaled = amount.formattedScaled(by: 1.0)
        #expect(scaled == "2 cups")  // Not "2.0 cups"
    }
}
```

### Acceptance Criteria
- [ ] PortionOption tests pass
- [ ] Amount scaling tests pass
- [ ] Yield scaling tests pass
- [ ] Formatting tests pass
- [ ] Edge case tests pass

---

## Summary

| Task | Complexity | Dependencies | Status |
|------|------------|--------------|--------|
| 1. PortionOption Model | Low | None | Pending |
| 2. PortionSelectorView | Low | Task 1 | Pending |
| 3. Scaling Helper Functions | Medium | Task 1 | Pending |
| 4. Update IngredientsListView | Medium | Tasks 1, 3 | Pending |
| 5. Update RecipeHeaderView | Medium | Tasks 1, 3 | Pending |
| 6. Update RecipeDetailSplitContent | Medium | Tasks 2, 4, 5 | Pending |
| 7. Update RecipeDetailContent | Medium | Tasks 4, 5, 6 | Pending |
| 8. Update iPhone Layout | Medium | Task 7 | Pending |
| 9. Write Unit Tests | Medium | Tasks 1-8 | Pending |

**Implementation Order**: 1 → 2 → 3 → 4 + 5 (parallel) → 6 → 7 → 8 → 9

**Critical Path**: Tasks 1, 3, 4, 6, 7 are required for iPad functionality.

**Note**: Task 8 (iPhone structured rendering) is recommended for feature parity but could be deferred if needed.
