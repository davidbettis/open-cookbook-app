//
//  OnboardingView.swift
//  OpenCookbook
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

/// Represents the current step in the onboarding flow
enum OnboardingStep {
    case welcome
    case confirmation
}

/// ViewModel for managing onboarding state and logic
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var selectedFolderURL: URL?
    var showPicker = false
    var errorMessage: String?

    let folderManager: FolderManager

    init(folderManager: FolderManager) {
        self.folderManager = folderManager
    }

    func selectFolder() {
        showPicker = true
    }

    func handleFolderSelected(_ url: URL) {
        do {
            try folderManager.saveFolder(url)
            selectedFolderURL = url
            currentStep = .confirmation
        } catch {
            errorMessage = "Failed to save folder: \(error.localizedDescription)"
        }
    }

    func handleCancelled() {
        errorMessage = "Please select a folder to continue"
    }
}

/// Main onboarding view coordinating the welcome → picker → confirmation flow
struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    init(folderManager: FolderManager, onComplete: @escaping () -> Void) {
        self.viewModel = OnboardingViewModel(folderManager: folderManager)
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(onSelectFolder: viewModel.selectFolder)

            case .confirmation:
                if let url = viewModel.selectedFolderURL {
                    FolderConfirmationView(
                        folderURL: url,
                        onContinue: onComplete
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showPicker) {
            FolderPicker(
                selectedURL: $viewModel.selectedFolderURL,
                onSelect: viewModel.handleFolderSelected,
                onCancel: viewModel.handleCancelled
            )
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

#Preview {
    OnboardingView(
        folderManager: FolderManager(),
        onComplete: {
            print("Onboarding complete")
        }
    )
}
