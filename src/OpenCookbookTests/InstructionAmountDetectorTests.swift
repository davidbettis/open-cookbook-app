//
//  InstructionAmountDetectorTests.swift
//  OpenCookbookTests
//
//  Tests for detecting ingredient amounts in instruction text
//

import Testing
@testable import OpenCookbook

struct InstructionAmountDetectorTests {

    // MARK: - Positive Cases (should detect amounts)

    @Test func detectsCupsAmount() {
        #expect(InstructionAmountDetector.containsAmounts("add 2 cups broth"))
    }

    @Test func detectsFractionWithSlash() {
        #expect(InstructionAmountDetector.containsAmounts("add 1/2 tsp salt"))
    }

    @Test func detectsUnicodeFraction() {
        #expect(InstructionAmountDetector.containsAmounts("add ½ cup water"))
    }

    @Test func detectsTablespoons() {
        #expect(InstructionAmountDetector.containsAmounts("stir in 3 tablespoons oil"))
    }

    @Test func detectsOunces() {
        #expect(InstructionAmountDetector.containsAmounts("pour 8 oz cream"))
    }

    @Test func detectsPounds() {
        #expect(InstructionAmountDetector.containsAmounts("use 2 lbs ground beef"))
    }

    @Test func detectsGrams() {
        #expect(InstructionAmountDetector.containsAmounts("weigh out 200 grams flour"))
    }

    @Test func detectsMilliliters() {
        #expect(InstructionAmountDetector.containsAmounts("add 100 ml milk"))
    }

    @Test func detectsUppercaseT() {
        #expect(InstructionAmountDetector.containsAmounts("add 2 T butter"))
    }

    @Test func detectsLowercaseT() {
        #expect(InstructionAmountDetector.containsAmounts("add 1 t vanilla"))
    }

    @Test func detectsLowercaseC() {
        #expect(InstructionAmountDetector.containsAmounts("add 1 c flour"))
    }

    @Test func detectsSlices() {
        #expect(InstructionAmountDetector.containsAmounts("top with 3 slices cheese"))
    }

    @Test func detectsCloves() {
        #expect(InstructionAmountDetector.containsAmounts("mince 4 cloves garlic"))
    }

    @Test func detectsCaseInsensitive() {
        #expect(InstructionAmountDetector.containsAmounts("Add 2 CUPS broth"))
    }

    @Test func detectsTbspAbbreviation() {
        #expect(InstructionAmountDetector.containsAmounts("mix 1 tbsp vanilla"))
    }

    // MARK: - Negative Cases (should not detect amounts)

    @Test func ignoresTemperatureFahrenheit() {
        #expect(!InstructionAmountDetector.containsAmounts("bake at 375°F"))
    }

    @Test func ignoresTemperatureCelsius() {
        #expect(!InstructionAmountDetector.containsAmounts("preheat to 190°C"))
    }

    @Test func ignoresTimeMinutes() {
        #expect(!InstructionAmountDetector.containsAmounts("cook for 25 minutes"))
    }

    @Test func ignoresTimeHours() {
        #expect(!InstructionAmountDetector.containsAmounts("simmer for 2 hours"))
    }

    @Test func ignoresPlainText() {
        #expect(!InstructionAmountDetector.containsAmounts("stir until smooth"))
    }

    @Test func ignoresServings() {
        #expect(!InstructionAmountDetector.containsAmounts("serves 4"))
    }

    @Test func ignoresStepNumbers() {
        #expect(!InstructionAmountDetector.containsAmounts("step 3"))
    }

    @Test func ignoresEmptyString() {
        #expect(!InstructionAmountDetector.containsAmounts(""))
    }

    @Test func ignoresTemperatureWithoutDegreeSymbol() {
        #expect(!InstructionAmountDetector.containsAmounts("set oven to 350 degrees"))
    }

    @Test func ignoresBareNumbers() {
        #expect(!InstructionAmountDetector.containsAmounts("repeat 3 times"))
    }
}
