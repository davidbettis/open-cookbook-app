# Custom Amount Display Format

**Status:** Draft
**Tracking:** https://github.com/davidbettis/open-cookbook-app/issues/5

## Overview

Add a setting that controls how ingredient amounts are displayed in recipe detail views. Users can choose between three modes:

- **Original** (default) — display amounts exactly as written in the recipe file (`rawText`)
- **Decimal** — display amounts as decimal numbers (e.g., `1.5`, `0.25`)
- **Fraction** — display amounts as Unicode fractions or mixed numbers (e.g., `½`, `2¼`)

This is display-only formatting that does not modify the underlying recipe file.

## User Stories

### US-1: View amounts as fractions
**As a** home cook reading a recipe
**I want** ingredient amounts shown as fractions
**So that** I can easily measure with standard measuring cups and spoons

### US-2: View amounts as decimals
**As a** user who prefers metric-style precision
**I want** ingredient amounts shown as decimal numbers
**So that** I can weigh ingredients on a kitchen scale

### US-3: View amounts as originally written
**As a** user who edits recipe files by hand
**I want** to see amounts exactly as I wrote them
**So that** the display matches my source files

## Acceptance Criteria

- [ ] Settings screen shows an "Amount Format" picker with three options: Original, Decimal, Fraction
- [ ] Setting appears in the existing "Display" section alongside "Auto-number Instructions"
- [ ] Default value is "Original" (preserves current behavior via `rawText`)
- [ ] Selecting "Decimal" displays all amounts as decimal numbers (e.g., `0.5 cups`)
- [ ] Selecting "Fraction" displays amounts as Unicode fractions/mixed numbers (e.g., `½ cup`, `2¼ cups`)
- [ ] Whole numbers display identically in all three modes (e.g., `2 cups`)
- [ ] Setting applies to both ingredient lists and scaled portions
- [ ] Setting persists across app launches
- [ ] Both iPhone and iPad layouts respect the setting

## Technical Design

### Data Model

```swift
enum AmountDisplayFormat: String, CaseIterable {
    case original   // Use Amount.rawText (current behavior)
    case decimal    // Format Amount.amount as decimal string
    case fraction   // Format Amount.amount as fraction/mixed number
}
```

**UserDefaults Key:** `amountDisplayFormat` (default: `"original"`)

### Fraction Formatting Algorithm

Convert a `Double` to the nearest common cooking fraction using Unicode fraction characters:

1. If the value is a whole number, return the integer string (e.g., `2`)
2. Separate into whole part and fractional remainder
3. Match the remainder against common cooking denominators: **2, 3, 4, 8**
   - Tolerance: `0.01` for matching
4. If a match is found, map to the corresponding Unicode character:

| Fraction | Unicode | Character |
|----------|---------|-----------|
| 1/8      | U+215B  | ⅛         |
| 1/4      | U+00BC  | ¼         |
| 1/3      | U+2153  | ⅓         |
| 3/8      | U+215C  | ⅜         |
| 1/2      | U+00BD  | ½         |
| 5/8      | U+215D  | ⅝         |
| 2/3      | U+2154  | ⅔         |
| 3/4      | U+00BE  | ¾         |
| 7/8      | U+215E  | ⅞         |

5. Format the result:
   - No whole part → return Unicode fraction (e.g., `½`)
   - With whole part → return whole number directly joined with fraction (e.g., `2¼`, no space)
6. If no match, fall back to decimal format (e.g., `1.67`)

### Example Conversions

| Double Value | Decimal | Fraction |
|-------------|---------|----------|
| 2.0         | 2       | 2        |
| 0.5         | 0.5     | ½        |
| 1.5         | 1.5     | 1½       |
| 2.25        | 2.25    | 2¼       |
| 0.333...    | 0.33    | ⅓        |
| 0.75        | 0.75    | ¾        |
| 0.125       | 0.13    | ⅛        |
| 1.67        | 1.67    | 1⅔       |
| 3.1415      | 3.14    | 3.14     |

### Files to Modify

| File | Changes |
|------|---------|
| `Core/Extensions/Amount+Scaling.swift` | Add `formattedScaled(by:format:)` method with format parameter |
| `Features/Settings/Views/SettingsView.swift` | Add "Amount Format" picker to Display section |
| `Features/RecipeDetail/Views/IngredientsListView.swift` | Read `@AppStorage`, pass format to amount formatting |
| `Features/RecipeDetail/Views/RecipeHeaderView.swift` | Read `@AppStorage`, pass format to yield formatting |
| `Features/RecipeDetail/Views/RecipeDetailSplitContent.swift` | Pass format through if needed |
| `OpenCookbookTests/PortionScalingTests.swift` | Add tests for decimal and fraction formatting |

### Implementation in Amount+Scaling.swift

Add a new method alongside the existing `formattedScaled(by:)`:

```swift
func formattedScaled(by multiplier: Double, format: AmountDisplayFormat) -> String {
    let scaledValue = self.amount * multiplier

    let formattedNumber: String
    switch format {
    case .original:
        // For 1x multiplier, use rawText; otherwise use existing decimal logic
        if multiplier == 1.0 {
            formattedNumber = self.rawText
        } else {
            formattedNumber = Self.formatNumber(scaledValue)
        }
    case .decimal:
        formattedNumber = Self.formatDecimal(scaledValue)
    case .fraction:
        formattedNumber = Self.formatFractionUnicode(scaledValue)
    }

    if let unit = self.unit, !unit.isEmpty {
        return "\(formattedNumber) \(unit)"
    }
    return formattedNumber
}
```

### Unicode Fraction Lookup

```swift
private static let unicodeFractions: [(Double, Character)] = [
    (1.0/8.0, "⅛"),
    (1.0/4.0, "¼"),
    (1.0/3.0, "⅓"),
    (3.0/8.0, "⅜"),
    (1.0/2.0, "½"),
    (5.0/8.0, "⅝"),
    (2.0/3.0, "⅔"),
    (3.0/4.0, "¾"),
    (7.0/8.0, "⅞"),
]

private static func formatFractionUnicode(_ value: Double) -> String {
    guard !value.isZero else { return "0" }

    let whole = Int(value)
    let remainder = value - Double(whole)

    // Whole number — no fraction needed
    if abs(remainder) < 0.01 {
        return "\(whole)"
    }

    // Match remainder to a Unicode fraction
    for (fractionValue, character) in unicodeFractions {
        if abs(remainder - fractionValue) < 0.01 {
            if whole > 0 {
                return "\(whole)\(character)"
            }
            return String(character)
        }
    }

    // No match — fall back to decimal
    return formatDecimal(value)
}
```

### SettingsView Changes

```swift
// Add alongside existing @AppStorage properties
@AppStorage("amountDisplayFormat") private var amountDisplayFormat: String = AmountDisplayFormat.original.rawValue

// Add to Display section
Picker("Amount Format", selection: $amountDisplayFormat) {
    Text("Original").tag(AmountDisplayFormat.original.rawValue)
    Text("Decimal").tag(AmountDisplayFormat.decimal.rawValue)
    Text("Fraction").tag(AmountDisplayFormat.fraction.rawValue)
}

// Section footer
Text("Choose how ingredient amounts are displayed. Original shows amounts as written in the recipe file.")
```

### IngredientsListView Changes

```swift
@AppStorage("amountDisplayFormat") private var amountDisplayFormatRaw: String = AmountDisplayFormat.original.rawValue

private var amountFormat: AmountDisplayFormat {
    AmountDisplayFormat(rawValue: amountDisplayFormatRaw) ?? .original
}

// In displayText computed property:
private var displayText: String {
    if let amount = ingredient.amount {
        let scaledAmount = amount.formattedScaled(by: portionMultiplier, format: amountFormat)
        return "\(scaledAmount) \(ingredient.name)"
    }
    return ingredient.name
}
```

## Test Cases

### TC-1: Decimal formatting
1. Set amount format to Decimal in settings
2. Open a recipe with fractional amounts (e.g., `1/2 cup`)
3. Verify amounts display as decimals (e.g., `0.5 cup`)

### TC-2: Fraction formatting with Unicode
1. Set amount format to Fraction in settings
2. Open a recipe with decimal amounts (e.g., `2.25 cups`)
3. Verify amounts display as Unicode fractions (e.g., `2¼ cups`)

### TC-3: Original formatting preserves rawText
1. Set amount format to Original (default)
2. Open a recipe where amounts were written as `1/2`
3. Verify `1/2` is displayed, not `0.5`

### TC-4: Fraction fallback for non-standard values
1. Set amount format to Fraction
2. Open a recipe with an amount like `3.1415`
3. Verify it falls back to decimal display (e.g., `3.14`)

### TC-5: Whole numbers are consistent
1. Open a recipe with whole number amounts (e.g., `2 cups`)
2. Switch between all three format modes
3. Verify `2 cups` displays identically in all modes

### TC-6: Scaling interacts correctly with format
1. Set amount format to Fraction
2. Open a recipe with `1 cup` of an ingredient
3. Scale to 1.5x portions
4. Verify amount displays as `1½ cups`

### TC-7: Setting persists
1. Set amount format to Fraction
2. Force-quit and relaunch the app
3. Verify setting is still Fraction

### TC-8: Both layouts respect setting
1. Set amount format to Fraction
2. Open recipe detail on iPhone — verify fractions shown
3. Open recipe detail on iPad — verify fractions shown in ingredients panel
