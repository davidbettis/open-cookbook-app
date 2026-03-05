//
//  ShareableRecipe.swift
//  OpenCookbook
//
//  Transferable wrapper for sharing recipes via ShareLink
//

import CoreTransferable
import UniformTypeIdentifiers

/// A recipe packaged for sharing via the system share sheet.
/// Provides both plain text (for iMessage, email, etc.) and file representation (for AirDrop).
struct ShareableRecipe: Transferable {
    let title: String
    let markdown: String

    static var transferRepresentation: some TransferRepresentation {
        // Share as a .recipe.md file attachment.
        // The ShareLink `message:` parameter provides the human-readable text for messaging apps.
        // "Copy Recipe" in the overflow menu handles clipboard.
        FileRepresentation(exportedContentType: .recipeMD) { recipe in
            let data = Data(recipe.markdown.utf8)
            let filename = "\(recipe.title).recipemd"
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(filename)
            try data.write(to: tmpURL)
            return SentTransferredFile(tmpURL)
        }
    }
}
