# Auto-Numbering for Recipe Instructions

**Status:** Implemented

## Overview

Automatically add step numbers to recipe instructions that don't already have numbering. This is display-only formatting that doesn't modify the underlying recipe file.

## Current Implementation

Instructions are:
- Stored as `String?` in `RecipeFile.instructions`
- Rendered using `Markdown(instructions)` from MarkdownUI library
- Displayed in two places:
  - `RecipeDetailContent.swift` (iPhone layout)
  - `RecipeDetailSplitContent.swift` (iPad layout)

## Decisions

### Already Numbered Detection
Detect and skip numbering if the line starts with any of:
- `1.` (markdown ordered list)
- `1)` (parenthetical numbering)
- `Step 1:` or `Step 1 -` (word-based numbering)

### Stop Triggers
Stop auto-numbering when encountering:
- `## Headers` (any level: #, ##, ###, etc.)
- `---` horizontal rules/dividers
- `*Attribution*` lines (italic/emphasis text)

### Number Style
Use standard markdown ordered list style: `1.`, `2.`, `3.`

### Blank Line Handling
Ignore blank lines - number each non-blank content line sequentially.

---

## Implementation Plan

### Approach

Create an `InstructionsFormatter` service that:
1. Parses the instructions string line by line
2. Detects if instructions are already numbered (skip formatting entirely)
3. Adds numbering to unnumbered lines until a stop trigger
4. Passes through remaining content unchanged
5. Returns formatted markdown for display

### Files to Modify

| File | Changes |
|------|---------|
| `Core/Services/InstructionsFormatter.swift` | New - formatting logic |
| `RecipeDetailContent.swift` | Use formatter before passing to Markdown() |
| `RecipeDetailSplitContent.swift` | Use formatter before passing to Markdown() |
| `OpenCookbookTests/InstructionsFormatterTests.swift` | New - unit tests |

### Algorithm

```
1. Check if first non-blank line is already numbered
   - If yes, return original string unchanged
2. Split instructions into lines
3. Initialize stepNumber = 1, stopped = false
4. For each line:
   a. If blank line: append unchanged, continue
   b. If stop trigger (header, HR, italic): set stopped = true
   c. If stopped: append line unchanged
   d. Else: prepend "stepNumber. ", increment stepNumber
5. Join lines and return formatted string
```

### Stop Trigger Detection

```swift
func isStopTrigger(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    // Header (starts with #)
    if trimmed.hasPrefix("#") { return true }

    // Horizontal rule (---, ***, ___)
    if trimmed.matches(/^[-*_]{3,}$/) { return true }

    // Italic/emphasis line (starts and ends with * or _)
    if (trimmed.hasPrefix("*") && trimmed.hasSuffix("*")) ||
       (trimmed.hasPrefix("_") && trimmed.hasSuffix("_")) {
        return true
    }

    return false
}
```

### Already Numbered Detection

```swift
func isAlreadyNumbered(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    // "1." or "1)" style
    if trimmed.matches(/^\d+[.)]/) { return true }

    // "Step 1:" or "Step 1 -" style
    if trimmed.matches(/^[Ss]tep\s+\d+[:\-]/) { return true }

    return false
}
```

### Settings Toggle

Toggle in Settings to enable/disable auto-numbering (enabled by default).

**UserDefaults Key:** `autoNumberInstructions` (default: `true`)

**SettingsView Changes:**
```swift
Section {
    Toggle("Auto-number Instructions", isOn: $autoNumberInstructions)
} header: {
    Text("Display")
} footer: {
    Text("Automatically add step numbers to recipe instructions that don't have numbering.")
}
```

**AppStorage Property:**
```swift
@AppStorage("autoNumberInstructions") private var autoNumberInstructions = true
```

**Detail View Changes:**
```swift
// In RecipeDetailContent.swift and RecipeDetailSplitContent.swift
@AppStorage("autoNumberInstructions") private var autoNumberInstructions = true

// When rendering instructions:
let formattedInstructions = autoNumberInstructions
    ? instructionsFormatter.format(instructions)
    : instructions
Markdown(formattedInstructions)
```

**Files to Modify:**
| File | Changes |
|------|---------|
| `SettingsView.swift` | Add "Display" section with toggle |
| `RecipeDetailContent.swift` | Add @AppStorage, conditionally format |
| `RecipeDetailSplitContent.swift` | Add @AppStorage, conditionally format |

---

### Example Transformations

**Input (unnumbered):**
```
Preheat oven to 375°F

Mix dry ingredients

Cream butter and sugars

Bake for 10-12 minutes

*Adapted from Grandma's cookbook*
```

**Output:**
```
1. Preheat oven to 375°F

2. Mix dry ingredients

3. Cream butter and sugars

4. Bake for 10-12 minutes

*Adapted from Grandma's cookbook*
```

**Input (already numbered):**
```
1. Preheat oven
2. Mix ingredients
3. Bake
```

**Output:** (unchanged)
```
1. Preheat oven
2. Mix ingredients
3. Bake
```

**Input (with header stop):**
```
Preheat oven

Mix ingredients

## Tips

Let dough rest before baking
```

**Output:**
```
1. Preheat oven

2. Mix ingredients

## Tips

Let dough rest before baking
```
