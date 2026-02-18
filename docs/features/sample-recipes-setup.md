# Sample Recipes Setup

## Overview
Sample RecipeMD recipes have been added to the app bundle for testing in the simulator.

## What Was Added

### Sample Recipe Files (6 recipes)
Located in `src/OpenCookbook/Resources/SampleRecipes/`:

1. **Guacamole.md** - Classic Mexican dip (appetizer, vegan, mexican)
2. **Chocolate Chip Cookies.md** - Baking recipe (dessert, baking)
3. **Spaghetti Carbonara.md** - Italian pasta dish (pasta, italian, dinner)
4. **Green Smoothie.md** - Healthy breakfast smoothie (breakfast, vegan, healthy)
5. **Margherita Pizza.md** - Pizza with ingredient groups (dinner, italian, vegetarian)
6. **Cinnamon Rolls.md** - Rolls with 3 ingredient groups: dough, filling, frosting (breakfast, baking, dessert)

All recipes follow the RecipeMD v2.4.0 specification from https://recipemd.org/specification.html

### New Infrastructure

1. **SampleRecipeLoader.swift** - Helper class that:
   - Copies bundled sample recipes to a temporary directory
   - Can be used to quickly load test recipes
   - Handles errors gracefully

2. **Updated SettingsView.swift** - Added "Testing" section with:
   - "Load Sample Recipes" button
   - Progress indicator during loading
   - Error alerts if loading fails

## How to Use

### In the Simulator

1. Build and run the app in the iOS simulator
2. Navigate to the **Settings** tab
3. Tap **"Load Sample Recipes"** in the Testing section
4. The app will:
   - Copy the bundled recipes to a temporary directory
   - Switch to that directory automatically
   - Load all 5 sample recipes
5. Navigate to the **Recipes** tab to see the loaded recipes

### Xcode Integration

The sample recipes are automatically bundled with the app thanks to Xcode 16's new file system synchronization feature (PBXFileSystemSynchronizedRootGroup). No manual project file editing was required!

## Build Verification

Build output confirms all files are bundled:
```
CpResource .../OpenCookbook.app/Chocolate Chip Cookies.md
CpResource .../OpenCookbook.app/Green Smoothie.md
CpResource .../OpenCookbook.app/Guacamole.md
CpResource .../OpenCookbook.app/Margherita Pizza.md
CpResource .../OpenCookbook.app/Spaghetti Carbonara.md
```

## Testing Coverage

The sample recipes test various RecipeMD features:
- Basic recipes with simple ingredients (Guacamole, Green Smoothie)
- Longer recipes with more ingredients (Chocolate Chip Cookies, Spaghetti Carbonara)
- Recipes with 2 ingredient groups (Margherita Pizza - "For the dough", "For the topping")
- Recipes with 3 ingredient groups (Cinnamon Rolls - "For the Dough", "For the Filling", "For the Frosting")
- Different tags and categories
- Various yields formats

Perfect for testing the Recipe Library View implementation!
