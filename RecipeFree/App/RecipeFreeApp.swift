//
//  RecipeFreeApp.swift
//  RecipeFree
//
//  Created by David Bettis on 1/6/26.
//

import SwiftUI

@main
struct RecipeFreeApp: App {
    @State private var folderManager = FolderManager()
    @State private var showError: FolderError?

    var body: some Scene {
        WindowGroup {
            Group {
                if folderManager.selectedFolderURL != nil {
                    // Main app with tabs
                    MainTabView()
                        .environment(folderManager)
                } else {
                    OnboardingView(folderManager: folderManager) { }
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
