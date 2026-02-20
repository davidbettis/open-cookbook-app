//
//  ImportRecipeViewModelTests.swift
//  OpenCookbookTests
//
//  Tests for ImportRecipeViewModel
//

import Foundation
import Testing
@testable import OpenCookbook

@MainActor
@Suite("ImportRecipeViewModel Tests")
struct ImportRecipeViewModelTests {

    @Test("Initial state is idle")
    func initialState() {
        let vm = ImportRecipeViewModel()
        #expect(vm.state == .idle)
        #expect(vm.urlText == "")
        #expect(vm.isImporting == false)
    }

    @Test("statusMessage empty when idle")
    func statusMessageIdle() {
        let vm = ImportRecipeViewModel()
        #expect(vm.statusMessage == "")
    }

    @Test("isImporting true when extracting")
    func isImportingWhenExtracting() {
        let vm = ImportRecipeViewModel()
        vm.state = .extractingRecipe
        #expect(vm.isImporting == true)
        #expect(vm.statusMessage == "Extracting recipe with Claude...")
    }

    @Test("isImporting false for other states")
    func isImportingFalseForOtherStates() {
        let vm = ImportRecipeViewModel()

        vm.state = .idle
        #expect(vm.isImporting == false)

        vm.state = .success("markdown")
        #expect(vm.isImporting == false)

        vm.state = .error("error")
        #expect(vm.isImporting == false)
    }

    @Test("Invalid URL sets error state")
    func invalidURLSetsError() async {
        let vm = ImportRecipeViewModel()
        vm.urlText = "not-a-url"
        await vm.importRecipe()
        if case .error(let message) = vm.state {
            #expect(message == "Please enter a valid URL.")
        } else {
            #expect(Bool(false), "Expected error state")
        }
    }

    @Test("Empty URL sets error state")
    func emptyURLSetsError() async {
        let vm = ImportRecipeViewModel()
        vm.urlText = ""
        await vm.importRecipe()
        if case .error(let message) = vm.state {
            #expect(message == "Please enter a valid URL.")
        } else {
            #expect(Bool(false), "Expected error state")
        }
    }

    @Test("FTP URL sets error state")
    func ftpURLSetsError() async {
        let vm = ImportRecipeViewModel()
        vm.urlText = "ftp://example.com/recipe"
        await vm.importRecipe()
        if case .error(let message) = vm.state {
            #expect(message == "Please enter a valid URL.")
        } else {
            #expect(Bool(false), "Expected error state")
        }
    }

    // MARK: - cleanMarkdown Tests

    @Test("Strips wrapping code fences")
    func stripsCodeFences() {
        let input = "```markdown\n# My Recipe\n\n- *1 cup* flour\n```"
        let cleaned = ImportRecipeViewModel.cleanMarkdown(input)
        #expect(cleaned == "# My Recipe\n\n- *1 cup* flour")
    }

    @Test("Strips plain code fences")
    func stripsPlainCodeFences() {
        let input = "```\n# My Recipe\n\n- *1 cup* flour\n```"
        let cleaned = ImportRecipeViewModel.cleanMarkdown(input)
        #expect(cleaned == "# My Recipe\n\n- *1 cup* flour")
    }

    @Test("No code fences left unchanged")
    func noCodeFencesUnchanged() {
        let input = "# My Recipe\n\n- *1 cup* flour"
        let cleaned = ImportRecipeViewModel.cleanMarkdown(input)
        #expect(cleaned == input)
    }

    @Test("Extracts recipe from embedded code fences with preamble")
    func extractsFromEmbeddedFences() {
        let input = """
        I can't visit URLs, but here is the recipe:

        ```markdown
        # Soy-Glazed Chicken

        *asian, chicken*

        ---

        - *2 lbs* chicken thighs

        ---

        1. Cook the chicken.
        ```

        > Note: This may not be accurate.
        """
        let cleaned = ImportRecipeViewModel.cleanMarkdown(input)
        #expect(cleaned.hasPrefix("# Soy-Glazed Chicken"))
        #expect(!cleaned.contains("```"))
        #expect(!cleaned.contains("I can't visit"))
        #expect(!cleaned.contains("Note: This may not"))
    }

    @Test("Falls back to finding # heading when no code fences")
    func fallsBackToHeading() {
        let input = "Here is the recipe I found:\n\n# Pasta Carbonara\n\n- *4 oz* pasta\n\n---\n\n1. Boil pasta."
        let cleaned = ImportRecipeViewModel.cleanMarkdown(input)
        #expect(cleaned.hasPrefix("# Pasta Carbonara"))
        #expect(!cleaned.contains("Here is the recipe"))
    }

    // MARK: - Photo Import Tests

    @Test("Default source is website")
    func defaultSource() {
        let vm = ImportRecipeViewModel()
        #expect(vm.source == .website)
    }

    @Test("Photo status message when extracting")
    func photoStatusMessage() {
        let vm = ImportRecipeViewModel()
        vm.source = .photo
        vm.state = .extractingRecipe
        #expect(vm.statusMessage == "Extracting recipe from photo...")
    }

    @Test("Website status message when extracting")
    func websiteStatusMessage() {
        let vm = ImportRecipeViewModel()
        vm.source = .website
        vm.state = .extractingRecipe
        #expect(vm.statusMessage == "Extracting recipe with Claude...")
    }

    @Test("Import with no photo selected yields error")
    func importNoPhoto() async {
        let vm = ImportRecipeViewModel()
        vm.source = .photo
        vm.selectedImageData = nil
        await vm.importRecipe()
        if case .error(let message) = vm.state {
            #expect(message == "No photo selected.")
        } else {
            #expect(Bool(false), "Expected error state")
        }
    }

    @Test("ImportSource has website and photo cases")
    func importSourceCases() {
        let cases = ImportRecipeViewModel.ImportSource.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.website))
        #expect(cases.contains(.photo))
    }

    @Test("Selected image data starts nil")
    func selectedImageDataNil() {
        let vm = ImportRecipeViewModel()
        #expect(vm.selectedImageData == nil)
    }
}
