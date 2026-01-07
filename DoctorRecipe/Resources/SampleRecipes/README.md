# Sample Recipes

This folder contains sample RecipeMD recipes bundled with the app for testing purposes.

## Adding to Xcode Project

To bundle these recipes with the app:

1. Open DoctorRecipe.xcodeproj in Xcode
2. Right-click on the "Resources" folder in the Project Navigator
3. Select "Add Files to DoctorRecipe..."
4. Navigate to and select the entire "SampleRecipes" folder
5. Make sure the following options are selected:
   - ✓ Copy items if needed
   - ✓ Create folder references (not Create groups)
   - ✓ Add to targets: DoctorRecipe
6. Click "Add"

## Using Sample Recipes

Once bundled, users can load these sample recipes by:

1. Opening the Settings tab
2. Tapping "Load Sample Recipes" in the Testing section
3. The app will copy these recipes to a temporary directory and switch to that folder

## Recipe Files

- Guacamole.md - Classic Mexican dip
- Chocolate Chip Cookies.md - Baking recipe with multiple ingredients
- Spaghetti Carbonara.md - Italian pasta dish
- Green Smoothie.md - Healthy breakfast smoothie
- Margherita Pizza.md - Recipe with ingredient groups
