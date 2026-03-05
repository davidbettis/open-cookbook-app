//
//  OpenCookbookApp.swift
//  OpenCookbook
//
//  Created by David Bettis on 1/6/26.
//

import SwiftUI

@main
struct OpenCookbookApp: App {
    @State private var folderManager = FolderManager()
    @State private var showError: FolderError?
    @State private var importError: Error?
    @State private var showImportError = false

    /// Key for queuing recipe markdown in AppStorage when app isn't onboarded yet
    private static let pendingRecipeKey = "pendingImportRecipeMarkdown"

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

                // Check for queued recipe from before onboarding
                loadQueuedRecipe()
            }
            .onOpenURL { url in
                handleIncomingURL(url)
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
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK") {}
            } message: {
                if let error = importError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Incoming File Handling

    private func handleIncomingURL(_ url: URL) {
        do {
            let incoming = try IncomingRecipeHandler.handleIncomingFile(at: url)

            if folderManager.selectedFolderURL != nil {
                // Store on FolderManager so the recipe list picks it up
                folderManager.pendingImportMarkdown = incoming.markdown
            } else {
                // Not onboarded yet — queue the markdown for later
                UserDefaults.standard.set(incoming.markdown, forKey: Self.pendingRecipeKey)
            }
        } catch {
            importError = error
            showImportError = true
        }
    }

    /// Check for a queued recipe that arrived before the user finished onboarding.
    private func loadQueuedRecipe() {
        guard folderManager.selectedFolderURL != nil,
              let markdown = UserDefaults.standard.string(forKey: Self.pendingRecipeKey) else {
            return
        }

        // Clear the queue regardless of parse outcome
        UserDefaults.standard.removeObject(forKey: Self.pendingRecipeKey)

        do {
            let _ = try IncomingRecipeHandler.handleIncomingMarkdown(markdown)
            folderManager.pendingImportMarkdown = markdown
        } catch {
            importError = error
            showImportError = true
        }
    }
}
