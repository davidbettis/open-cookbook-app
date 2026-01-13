//
//  MarkdownTheme+Recipe.swift
//  RecipeFree
//
//  Custom MarkdownUI theme optimized for RecipeMD display.
//

import MarkdownUI
import SwiftUI

extension Theme {
    /// A custom theme optimized for displaying RecipeMD recipes.
    ///
    /// Typography hierarchy:
    /// - H1: 32pt bold (recipe title)
    /// - H2: 22pt bold (section headers)
    /// - H3: 20pt semibold (ingredient groups)
    /// - Body: 17pt regular
    /// - Emphasis: Monospace font (for ingredient amounts)
    @MainActor
    static var recipe: Theme {
        Theme()
        // MARK: - Headings
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.88)) // ~32pt relative to 17pt base
                }
                .markdownMargin(top: .em(0.5), bottom: .em(0.5))
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.29)) // ~22pt relative to 17pt base
                }
                .markdownMargin(top: .em(1.2), bottom: .em(0.4))
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.18)) // ~20pt relative to 17pt base
                }
                .markdownMargin(top: .em(1.0), bottom: .em(0.3))
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.0))
                }
                .markdownMargin(top: .em(0.8), bottom: .em(0.2))
        }
        // MARK: - Text Styles
        .text {
            FontSize(.em(1.0)) // 17pt base with Dynamic Type
        }
        .emphasis {
            // Monospace for ingredient amounts (italic text in RecipeMD)
            FontFamily(.custom("Menlo"))
            FontSize(.em(0.95))
        }
        .strong {
            FontWeight(.bold)
        }
        // MARK: - Paragraphs
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: .em(0.4), bottom: .em(0.4))
        }
        // MARK: - Lists
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.2))
        }
        .bulletedListMarker { _ in
            Text("•")
                .foregroundStyle(.secondary)
        }
        .numberedListMarker { configuration in
            Text("\(configuration.itemNumber).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        // MARK: - Thematic Break (horizontal rule)
        .thematicBreak {
            Divider()
                .padding(.vertical, 8)
        }
        // MARK: - Links
        .link {
            ForegroundColor(.accentColor)
        }
        // MARK: - Code
        .code {
            FontFamily(.custom("Menlo"))
            FontSize(.em(0.9))
            BackgroundColor(Color(.secondarySystemBackground))
        }
        .codeBlock { configuration in
            configuration.label
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: .em(0.5), bottom: .em(0.5))
        }
    }
}

// MARK: - Preview

#Preview("Recipe Theme") {
    ScrollView {
        Markdown("""
        # Chocolate Chip Cookies

        Classic homemade chocolate chip cookies with a chewy center.

        *dessert, baking, quick*

        **makes 24 cookies**

        ---

        ## Ingredients

        ### For the Dough
        - *2 1/4 cups* all-purpose flour
        - *1 tsp* baking soda
        - *1 cup* butter, softened

        ### For the Mix-ins
        - *2 cups* chocolate chips
        - *1 cup* walnuts, chopped

        ---

        ## Instructions

        1. Preheat oven to 375°F (190°C)
        2. Mix flour and baking soda in a bowl
        3. In a separate bowl, cream together butter and sugars
        4. Beat in eggs and vanilla to butter mixture
        5. Gradually blend in flour mixture
        6. Stir in chocolate chips
        7. Drop rounded tablespoons onto ungreased cookie sheets
        8. Bake for 10-12 minutes until golden brown
        """)
        .markdownTheme(.recipe)
        .padding()
    }
}
