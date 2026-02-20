# Open Cookbook

A free, open, standards-based recipe manager for iOS and macOS. Your recipes, your files, your data.

## Principles

- **Free** — Open Cookbook is free to use with no ads, subscriptions, or in-app purchases.
- **Open** — The source code is open and the app stores recipes as plain Markdown files you can read, edit, and share with any text editor.
- **Standards-based** — Recipes use the [RecipeMD](https://recipemd.org/) format, an open specification built on CommonMark Markdown. No proprietary formats, no lock-in.
- **Your data** — Recipes live in a folder on iCloud Drive that you choose and control. There are no accounts, no cloud services we operate, and no way for us to access your files.

## Features

- Browse, search, and filter your recipe collection
- Full-text search across titles, ingredients, tags, and instructions
- Create and edit recipes with a form-based editor or raw Markdown
- Import recipes from websites using the Anthropic Claude API (bring your own key)
- Automatic sync across your devices via iCloud Drive
- Native SwiftUI interface with support for Dynamic Type and VoiceOver

## RecipeMD Format

Open Cookbook reads and writes standard [RecipeMD](https://recipemd.org/) files — plain Markdown with a simple structure:

```markdown
# Chocolate Chip Cookies

Classic homemade cookies with a chewy center.

*dessert, baking, quick*

**makes 24 cookies**

---

- *2 1/4 cups* all-purpose flour
- *1 cup* butter, softened
- *2 cups* chocolate chips

---

1. Preheat oven to 375°F
2. Cream butter and sugars, then mix in dry ingredients
3. Stir in chocolate chips and bake for 10-12 minutes
```

Because recipes are plain text files, you can version them with Git, edit them in any text editor, or migrate to another app at any time.

## Requirements

- iOS 17.0+ / macOS 14.0+
- iCloud Drive

## Privacy

Open Cookbook collects no data. All processing happens on your device. See [PRIVACY.md](PRIVACY.md) for the full privacy policy.

## License

Open Cookbook is open source. See [LICENSE](LICENSE) for details.
