//
//  RecipeAddMenu.swift
//  OpenCookbook
//
//  Shared "Add Recipe" menu used by both RecipeListView and RecipeListSplitView
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Reusable menu for creating or importing recipes
struct RecipeAddMenu: View {

    let onNewRecipe: () -> Void
    let onImportFromWebsite: () -> Void
    let onImportFromPhoto: () -> Void

    @State private var clipboardError: String?
    @State private var showClipboardError = false

    /// Callback when clipboard markdown is ready to import
    var onPasteRecipe: (String) -> Void

    var body: some View {
        Menu {
            Button {
                onNewRecipe()
            } label: {
                Label("New Recipe", systemImage: "square.and.pencil")
            }
            Button {
                importRecipeFromClipboard()
            } label: {
                Label("Paste Recipe", systemImage: "doc.on.clipboard")
            }
            .disabled(!UIPasteboard.general.hasStrings)
            Button {
                onImportFromWebsite()
            } label: {
                Label("Import from Website", systemImage: "globe")
            }
            Button {
                onImportFromPhoto()
            } label: {
                Label("Import from Photo", systemImage: "camera")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add Recipe")
        .alert("Paste Recipe", isPresented: $showClipboardError) {
            Button("OK") {}
        } message: {
            if let error = clipboardError {
                Text(error)
            }
        }
    }

    private func importRecipeFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            clipboardError = "Nothing on the clipboard."
            showClipboardError = true
            return
        }
        do {
            let incoming = try IncomingRecipeHandler.handleIncomingMarkdown(text)
            onPasteRecipe(incoming.markdown)
        } catch {
            clipboardError = "The clipboard doesn't appear to contain a recipe."
            showClipboardError = true
        }
    }
}
