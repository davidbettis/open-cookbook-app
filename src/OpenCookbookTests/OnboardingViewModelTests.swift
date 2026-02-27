//
//  OnboardingViewModelTests.swift
//  OpenCookbookTests
//
//  Created by Claude Code on 2/26/26.
//

import Testing
import Foundation
@testable import OpenCookbook

struct OnboardingViewModelTests {

    @Test func initialStepIsWelcome() {
        let viewModel = OnboardingViewModel(folderManager: FolderManager())

        #expect(viewModel.currentStep == .welcome)
    }

    @Test func proceedToStorageSelectionTransitionsStep() {
        let viewModel = OnboardingViewModel(folderManager: FolderManager())

        viewModel.proceedToStorageSelection()

        #expect(viewModel.currentStep == .storageSelection)
    }

    @Test func selectDefaultLocalFolderMovesToConfirmation() {
        UserDefaults.standard.removeObject(forKey: "selectedFolderBookmark")
        let folderManager = FolderManager()
        let viewModel = OnboardingViewModel(folderManager: folderManager)

        viewModel.selectDefaultLocalFolder()

        #expect(viewModel.currentStep == .confirmation)
        #expect(viewModel.selectedFolderURL != nil)
        #expect(viewModel.selectedFolderURL?.lastPathComponent == "Recipes")

        // Cleanup
        folderManager.clearSavedFolder()
    }

    @Test func selectCustomFolderShowsPicker() {
        let viewModel = OnboardingViewModel(folderManager: FolderManager())

        viewModel.selectCustomFolder()

        #expect(viewModel.showPicker == true)
    }

    @Test func handleCancelledReturnsToStorageSelection() {
        let viewModel = OnboardingViewModel(folderManager: FolderManager())
        viewModel.currentStep = .storageSelection
        viewModel.selectCustomFolder()

        viewModel.handleCancelled()

        #expect(viewModel.currentStep == .storageSelection)
    }
}
