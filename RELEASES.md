# Release History

1.0.3
- Add curated tag vocabulary with categories (cuisine, meal, method, diet, protein) and AI-biased suggestions based on usage frequency
- Add structured tag picker with category sections, search, usage counts, and custom tag support
- Add bulk tag editing: select multiple recipes and add or remove tags at once
- Add local default folder option during onboarding

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
