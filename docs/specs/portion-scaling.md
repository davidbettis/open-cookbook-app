# Feature Spec: Portion Scaling

**Priority**: P1 (Should Have)
**Feature ID**: F008

## Description
Allow users to dynamically adjust ingredient quantities and serving yields by selecting a portion multiplier. A dropdown menu provides preset options (Half, Whole, Double) that scale all ingredient amounts and yields accordingly.

## User Stories

### US-020: Scale recipe for fewer servings
**As a** user
**I want** to halve a recipe's quantities
**So that** I can cook for fewer people without doing mental math

### US-021: Scale recipe for more servings
**As a** user
**I want** to double a recipe's quantities
**So that** I can cook for a larger group

### US-022: Reset to original quantities
**As a** user
**I want** to easily return to the original recipe quantities
**So that** I can see what the recipe author intended

## Acceptance Criteria

- [ ] Display portion selector dropdown in recipe detail view
- [ ] Dropdown options: "Half (0.5x)", "Whole (1x)", "Double (2x)"
- [ ] Default selection: "Whole (1x)"
- [ ] Selecting a portion updates all ingredient quantities immediately
- [ ] Selecting a portion updates yield/servings display
- [ ] Scaled quantities display with appropriate precision (no excessive decimals)
- [ ] Ingredients without amounts remain unchanged
- [ ] Portion selection persists while viewing the recipe
- [ ] Portion resets to "Whole" when navigating to a different recipe
- [ ] iPad: Portion selector appears in ingredients panel header
- [ ] iPhone: Portion selector appears above ingredients section

## Technical Requirements

### Portion Multipliers
| Option | Label | Multiplier |
|--------|-------|------------|
| Half | "Half (0.5x)" | 0.5 |
| Whole | "Whole (1x)" | 1.0 |
| Double | "Double (2x)" | 2.0 |

### Scaling Logic
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

### Quantity Scaling
- Multiply `Amount.amount` (the numeric value) by the selected multiplier
- Preserve the unit string unchanged
- Format result to remove unnecessary decimals:
  - Whole numbers: display as integers (e.g., "2" not "2.0")
  - Simple fractions: consider displaying as fractions (e.g., "1/2" for 0.5)
  - Other decimals: round to 2 decimal places maximum

### Yield Scaling
- Parse yield amounts (e.g., "serves 4" → 4)
- Multiply by portion multiplier
- Reconstruct yield string (e.g., "serves 2" for half)
- Handle multiple yields (e.g., "serves 4, makes 12 cookies")

### State Management
- Store `selectedPortion: PortionOption` as `@State` in the detail view
- Pass multiplier to `IngredientsListView` and `RecipeHeaderView`
- Compute scaled values on-the-fly (don't modify underlying recipe data)

### Implementation Location
- Add `PortionOption` model to `Core/Models/`
- Add `PortionSelectorView` component to `Features/RecipeDetail/Views/`
- Update `IngredientsListView` to accept and apply multiplier
- Update `RecipeHeaderView` to accept and apply multiplier to yields
- Update `RecipeDetailContent` to manage portion state and pass to children

## UI/UX Requirements

### Dropdown Design
```
┌─────────────────────────┐
│ Portions: [Whole (1x) ▼]│
└─────────────────────────┘
        ↓ (on tap)
┌─────────────────────────┐
│ ○ Half (0.5x)           │
│ ● Whole (1x)            │
│ ○ Double (2x)           │
└─────────────────────────┘
```

### iPad Layout (in ingredients panel header)
```
┌────────────────────────────────────────────────────────────────────────┐
│ < Recipe Title                                          Edit  Share  •••│
├────────────────────────────────────────────────────────────────────────┤
│ # Recipe Title                                                         │
│ Description text...                                                    │
│ *tag1, tag2*                                                           │
│ **Serves 4** ← (scaled based on portion)                               │
├──────────────────────┬─────────────────────────────────────────────────┤
│ Ingredients          │              INSTRUCTIONS                       │
│ [Whole (1x) ▼]       │                                                 │
├──────────────────────┼─────────────────────────────────────────────────┤
│ - 2 cups flour       │ 1. Preheat oven...                              │
│   (scaled)           │                                                 │
│ - 1 tsp salt         │ 2. Mix ingredients...                           │
│   (scaled)           │                                                 │
└──────────────────────┴─────────────────────────────────────────────────┘
```

### iPhone Layout (above ingredients)
```
┌─────────────────────────────┐
│ < Recipe Title    Edit Share│
├─────────────────────────────┤
│ # Recipe Title              │
│ Description...              │
│ *tags*                      │
│ **Serves 4** ← (scaled)     │
│                             │
│ ─────────────────────────── │
│                             │
│ Portions: [Whole (1x) ▼]    │
│                             │
│ • 2 cups flour (scaled)     │
│ • 1 tsp salt (scaled)       │
│                             │
│ ─────────────────────────── │
│                             │
│ 1. Instructions...          │
└─────────────────────────────┘
```

### Visual Feedback
- Selected option shows checkmark or filled radio button
- Dropdown uses system Picker with `.menu` style
- Consider subtle animation when quantities update

## Dependencies
- RecipeMD library (for `Amount` type with numeric values)
- Existing `IngredientsListView` component
- Existing `RecipeHeaderView` component
- Existing `RecipeDetailContent` component

## Test Cases

### TC-030: Select half portion
1. Open recipe with ingredients (e.g., "2 cups flour")
2. Tap portion selector
3. Select "Half (0.5x)"
4. Verify ingredients show halved amounts (e.g., "1 cup flour")
5. Verify yields show halved amounts (e.g., "Serves 2" instead of "Serves 4")

### TC-031: Select double portion
1. Open recipe with ingredients
2. Tap portion selector
3. Select "Double (2x)"
4. Verify ingredients show doubled amounts
5. Verify yields show doubled amounts

### TC-032: Reset to whole portion
1. Open recipe and select "Half"
2. Verify quantities are halved
3. Select "Whole (1x)"
4. Verify quantities return to original values

### TC-033: Ingredients without amounts unchanged
1. Open recipe with ingredient "salt to taste" (no amount)
2. Select "Double (2x)"
3. Verify "salt to taste" remains unchanged

### TC-034: Decimal formatting
1. Open recipe with "1 cup butter"
2. Select "Half (0.5x)"
3. Verify displays as "0.5 cup butter" or "1/2 cup butter" (not "0.50000 cup")

### TC-035: Navigate to different recipe resets portion
1. Open Recipe A, select "Double (2x)"
2. Navigate back to recipe list
3. Open Recipe B
4. Verify portion selector shows "Whole (1x)"

### TC-036: Multiple yields scaled
1. Open recipe with yields "serves 4, makes 24 cookies"
2. Select "Half (0.5x)"
3. Verify yields show "serves 2, makes 12 cookies"

### TC-037: iPad portion selector location
1. Open recipe on iPad
2. Verify portion selector appears in ingredients panel header
3. Verify it functions correctly

### TC-038: iPhone portion selector location
1. Open recipe on iPhone
2. Verify portion selector appears above ingredients section
3. Verify it functions correctly

## Accessibility Requirements
- Portion selector fully accessible via VoiceOver
- Announce current selection (e.g., "Portions, Whole, 1x, button, menu")
- Announce when selection changes
- Support keyboard navigation on iPad with external keyboard

## Out of Scope (Future Enhancements)
- Custom multiplier input (e.g., "1.5x" or "serves 6")
- Persisting portion preference across app sessions
- Smart unit conversion (e.g., "24 tsp" → "8 tbsp")
- Fractional display preferences (decimals vs fractions)
- Per-ingredient scaling exceptions

## Open Questions
- Should we display fractions (1/2) or decimals (0.5) for scaled amounts?
  - **Recommendation**: Use decimals for simplicity in v1, consider fractions in future
- Should portion selection persist when returning to the same recipe?
  - **Recommendation**: Reset to "Whole" for simplicity; users expect original recipe
