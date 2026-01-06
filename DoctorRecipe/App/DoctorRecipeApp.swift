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
    @State private var showError: FolderError?

    var body: some Scene {
        WindowGroup {
            Group {
                // Check if iCloud is available
                if !folderManager.checkiCloudAvailability() {
                    CloudPermissionErrorView()
                } else if folderManager.hasSelectedFolder() {
                    // Main app with tabs
                    MainTabView()
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
                do {
                    try folderManager.loadSavedFolder()
                } catch let error as FolderError {
                    showError = error
                } catch {
                    // Ignore other errors on launch
                }
            }
            .alert(
                "Folder Error",
                isPresented: .constant(showError != nil),
                presenting: showError
            ) { error in
                Button("OK") {
                    showError = nil
                }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred")
            }
        }
    }
}
