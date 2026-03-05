//
//  UTType+Recipe.swift
//  OpenCookbook
//
//  Custom UTType for .recipemd files
//

import UniformTypeIdentifiers

extension UTType {
    /// Custom type for RecipeMD recipe files (.recipemd)
    /// Conforms to .text (not .plainText) so Gmail accepts it but Quick Look doesn't claim it.
    static let recipeMD = UTType(
        exportedAs: "com.opencookbook.recipemd",
        conformingTo: .text
    )
}
