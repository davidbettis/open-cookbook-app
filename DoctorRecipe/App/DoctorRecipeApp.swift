//
//  DoctorRecipeApp.swift
//  DoctorRecipe
//
//  Created by David Bettis on 1/6/26.
//

import SwiftUI

@main
struct DoctorRecipeApp: App {
    @State private var folderManager = FolderManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if folderManager.hasSelectedFolder() {
                    // Main app - placeholder for now
                    ContentView()
                        .environment(folderManager)
                } else {
                    // Show onboarding if no folder selected
                    OnboardingView(folderManager: folderManager) {
                        // Force UI refresh after onboarding completes
                        // The folderManager state change will trigger a re-render
                    }
                }
            }
            .onAppear {
                // Load saved folder on launch
                try? folderManager.loadSavedFolder()
            }
        }
    }
}
