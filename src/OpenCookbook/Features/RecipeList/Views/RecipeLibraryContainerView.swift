//
//  RecipeLibraryContainerView.swift
//  OpenCookbook
//
//  Platform-adaptive container for recipe library
//

import SwiftUI

extension Notification.Name {
    /// Posted when recipes are added/changed outside the RecipeStore (e.g. file import)
    static let recipesDidChange = Notification.Name("recipesDidChange")
}

/// Platform-adaptive container that shows appropriate view based on device
struct RecipeLibraryContainerView: View {

    // MARK: - Properties

    @Environment(FolderManager.self) private var folderManager
    @State private var recipeStore = RecipeStore()

    // MARK: - Body

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Use split view
                RecipeListSplitView(
                    viewModel: RecipeListViewModel(recipeStore: recipeStore)
                )
            } else {
                // iPhone: Use navigation stack
                RecipeListView(
                    viewModel: RecipeListViewModel(recipeStore: recipeStore)
                )
            }
        }
        .environment(recipeStore)
        .onAppear {
            if let folderURL = folderManager.selectedFolderURL {
                recipeStore.loadRecipes(from: folderURL)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .recipesDidChange)) { _ in
            recipeStore.refreshRecipes()
        }
    }
}

// MARK: - Previews

#Preview("iPhone") {
    RecipeLibraryContainerView()
        .environment(FolderManager())
        .previewDevice("iPhone 15 Pro")
}

#Preview("iPad") {
    RecipeLibraryContainerView()
        .environment(FolderManager())
        .previewDevice("iPad Pro (12.9-inch)")
}
