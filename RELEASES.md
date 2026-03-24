# Release History

1.0.6
- Add "Choose Files" button for importing recipe photos from disk on macOS
- Add help text to Settings display options and import section
- Widen iPad ingredient panel from 25% to 33% in split view
- Sort tag filter chips by recipe count descending

1.0.5
- Support importing recipes from multiple photos (up to 5) for multi-page cookbook spreads, from both photo library and camera
- Camera now offers "Take Another" after each capture to quickly photograph multiple pages
- Move Edit button into the "..." overflow menu in recipe detail view
- Update tag vocabulary: add bread to baking, remove brunch
- Hide custom tag list in recipe form tag picker (custom tag input field remains)

1.0.4
- Update tag vocabulary: add baking category (cake, cookies, pie), add southern/bbq, simplify cuisine to broad flavor profiles
- Add recipe sharing: share recipes via iMessage (as readable text), AirDrop, or email (as .recipemd file attachment)
- Add "Copy Recipe" option in recipe detail overflow menu
- Add "Paste Recipe" option in the + menu to import a recipe from the clipboard
- Register .recipemd file type so "Open in Open Cookbook" appears when receiving recipe files
- Add import preview with edit form when opening shared recipes

1.0.3
- Add curated tag vocabulary with categories (cuisine, meal, method, diet, protein) and AI-biased suggestions based on usage frequency
- Add structured tag picker with category sections, search, usage counts, and custom tag support
- Add bulk tag editing: select multiple recipes and add or remove tags at once
- Add local default folder option during onboarding
- Add warning banner on Instructions tab when ingredient amounts are detected that won't scale with portion adjustments
- Use slash fractions instead of unicode fractions in AI recipe import

1.0.2
- Add the ability to import a recipe from a website
- Add the ability to import a recipe from a photo (camera or photo library)
- Leverages Claude API (API key needed) to do the extraction
- Uses Claude web helper tool to fetch the website
- Uses Claude vision API to extract recipes from photos

1.0.1
- Add ingredient groups (e.g. one group for a sauce, another group for the core of the dish)
- Add instruction groups (parallel to ingredient groups, but for instructions)
- Add support to view/edit raw markdown. Power user feature only. Hidden behind a "..." menu
- Add optional feature to force quantities into fractions or decimals

1.0 - initial release
- Recipe library stored locally on device
- Create/edit/delete recipes
- Add and search by tags
- Add optional feature to number instructions, if not already present
