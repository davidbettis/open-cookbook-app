//
//  InstructionsFormatterTests.swift
//  RecipeFreeTests
//
//  Tests for InstructionsFormatter auto-numbering
//

import Testing
@testable import RecipeFree

struct InstructionsFormatterTests {

    let formatter = InstructionsFormatter()

    // MARK: - Basic Numbering

    @Test func numbersUnnumberedInstructions() {
        let input = """
        Preheat oven to 375°F
        Mix dry ingredients
        Cream butter and sugars
        Bake for 10-12 minutes
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven to 375°F"))
        #expect(result.contains("2. Mix dry ingredients"))
        #expect(result.contains("3. Cream butter and sugars"))
        #expect(result.contains("4. Bake for 10-12 minutes"))
    }

    @Test func preservesBlankLines() {
        let input = """
        Preheat oven

        Mix ingredients

        Bake
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven"))
        #expect(result.contains("2. Mix ingredients"))
        #expect(result.contains("3. Bake"))
        // Blank lines should be preserved
        #expect(result.contains("\n\n"))
    }

    // MARK: - Already Numbered Detection

    @Test func skipsAlreadyNumberedWithDot() {
        let input = """
        1. Preheat oven
        2. Mix ingredients
        3. Bake
        """

        let result = formatter.format(input)

        #expect(result == input)
    }

    @Test func skipsAlreadyNumberedWithParenthesis() {
        let input = """
        1) Preheat oven
        2) Mix ingredients
        3) Bake
        """

        let result = formatter.format(input)

        #expect(result == input)
    }

    @Test func skipsAlreadyNumberedWithStepWord() {
        let input = """
        Step 1: Preheat oven
        Step 2: Mix ingredients
        Step 3: Bake
        """

        let result = formatter.format(input)

        #expect(result == input)
    }

    @Test func skipsStepWithDash() {
        let input = """
        Step 1 - Preheat oven
        Step 2 - Mix ingredients
        """

        let result = formatter.format(input)

        #expect(result == input)
    }

    // MARK: - Stop Triggers

    @Test func stopsAtHeader() {
        let input = """
        Preheat oven
        Mix ingredients
        ## Tips
        Let dough rest before baking
        Use room temperature butter
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven"))
        #expect(result.contains("2. Mix ingredients"))
        #expect(result.contains("## Tips"))
        #expect(result.contains("Let dough rest before baking"))
        #expect(!result.contains("3. ## Tips"))
        #expect(!result.contains("3. Let dough"))
    }

    @Test func stopsAtHorizontalRule() {
        let input = """
        Preheat oven
        Mix ingredients
        ---
        Notes about the recipe
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven"))
        #expect(result.contains("2. Mix ingredients"))
        #expect(result.contains("---"))
        #expect(!result.contains("3. ---"))
        #expect(!result.contains("3. Notes"))
    }

    @Test func stopsAtItalicAttribution() {
        let input = """
        Preheat oven
        Mix ingredients
        Bake for 30 minutes
        *Adapted from Grandma's cookbook*
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven"))
        #expect(result.contains("2. Mix ingredients"))
        #expect(result.contains("3. Bake for 30 minutes"))
        #expect(result.contains("*Adapted from Grandma's cookbook*"))
        #expect(!result.contains("4. *Adapted"))
    }

    @Test func stopsAtUnderscoreItalic() {
        let input = """
        Preheat oven
        _Recipe by Chef John_
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven"))
        #expect(result.contains("_Recipe by Chef John_"))
        #expect(!result.contains("2. _Recipe"))
    }

    @Test func doesNotStopAtBoldText() {
        // Bold (**text**) should NOT stop numbering - only italic (*text*)
        let input = """
        Preheat oven
        **Important:** Mix well
        Bake
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven"))
        #expect(result.contains("2. **Important:** Mix well"))
        #expect(result.contains("3. Bake"))
    }

    // MARK: - Edge Cases

    @Test func handlesEmptyString() {
        let result = formatter.format("")
        #expect(result == "")
    }

    @Test func handlesSingleLine() {
        let input = "Bake at 350°F"
        let result = formatter.format(input)
        #expect(result == "1. Bake at 350°F")
    }

    @Test func handlesOnlyBlankLines() {
        let input = "\n\n\n"
        let result = formatter.format(input)
        #expect(result == input)
    }

    @Test func handlesLeadingBlankLines() {
        let input = """

        Preheat oven
        Mix ingredients
        """

        let result = formatter.format(input)

        #expect(result.contains("1. Preheat oven"))
        #expect(result.contains("2. Mix ingredients"))
    }

    @Test func trimsWhitespaceFromLines() {
        let input = "   Preheat oven   "
        let result = formatter.format(input)
        #expect(result == "1. Preheat oven")
    }

    @Test func handlesVariousHorizontalRules() {
        // Test different HR styles
        let inputs = ["---", "***", "___", "----", "******"]

        for hr in inputs {
            let input = "Step one\n\(hr)\nNotes"
            let result = formatter.format(input)
            #expect(result.contains("1. Step one"), "Failed for HR: \(hr)")
            #expect(!result.contains("2. \(hr)"), "Failed for HR: \(hr)")
        }
    }
}
