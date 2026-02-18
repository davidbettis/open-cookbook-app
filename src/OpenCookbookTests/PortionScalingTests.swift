//
//  PortionScalingTests.swift
//  OpenCookbookTests
//
//  Unit tests for portion scaling functionality
//

import Testing
import Foundation
import RecipeMD
@testable import OpenCookbook

@Suite("Portion Scaling Tests")
struct PortionScalingTests {

    // MARK: - PortionOption Tests

    @Test("PortionOption has correct multipliers")
    func portionOptionMultipliers() {
        #expect(PortionOption.half.multiplier == 0.5)
        #expect(PortionOption.whole.multiplier == 1.0)
        #expect(PortionOption.double.multiplier == 2.0)
    }

    @Test("PortionOption has correct labels")
    func portionOptionLabels() {
        #expect(PortionOption.half.label == "0.5x")
        #expect(PortionOption.whole.label == "1x")
        #expect(PortionOption.double.label == "2x")
    }

    @Test("PortionOption allOptions contains all three options")
    func portionOptionAllOptions() {
        #expect(PortionOption.allOptions.count == 3)
        #expect(PortionOption.allOptions.contains(.half))
        #expect(PortionOption.allOptions.contains(.whole))
        #expect(PortionOption.allOptions.contains(.double))
    }

    @Test("PortionOption is equatable")
    func portionOptionEquatable() {
        #expect(PortionOption.half == PortionOption.half)
        #expect(PortionOption.half != PortionOption.whole)
        #expect(PortionOption.whole != PortionOption.double)
    }

    // MARK: - Amount Scaling Tests

    @Test("Amount scales correctly for half")
    func amountScalesHalf() {
        let amount = Amount(2, unit: "cups")
        let scaled = amount.formattedScaled(by: 0.5)
        #expect(scaled == "1 cups")
    }

    @Test("Amount scales correctly for double")
    func amountScalesDouble() {
        let amount = Amount(1, unit: "cup")
        let scaled = amount.formattedScaled(by: 2.0)
        #expect(scaled == "2 cup")
    }

    @Test("Amount scales correctly for whole (no change)")
    func amountScalesWhole() {
        let amount = Amount(2, unit: "cups")
        let scaled = amount.formattedScaled(by: 1.0)
        #expect(scaled == "2 cups")
    }

    @Test("Amount with decimal scales correctly")
    func amountWithDecimalScales() {
        let amount = Amount(2.5, unit: "cups")
        let scaled = amount.formattedScaled(by: 2.0)
        #expect(scaled == "5 cups")
    }

    @Test("Amount without unit scales correctly")
    func amountWithoutUnitScales() {
        let amount = Amount(4, unit: nil)
        let scaled = amount.formattedScaled(by: 0.5)
        #expect(scaled == "2")
    }

    // MARK: - Decimal Formatting Tests

    @Test("Whole numbers display without decimal")
    func wholeNumberFormatting() {
        let amount = Amount(2, unit: "cups")
        let scaled = amount.formattedScaled(by: 1.0)
        #expect(!scaled.contains("."))
    }

    @Test("Half values display with one decimal")
    func halfValueFormatting() {
        let amount = Amount(1, unit: "cup")
        let scaled = amount.formattedScaled(by: 0.5)
        #expect(scaled == "0.5 cup")
    }

    @Test("Quarter values display appropriately")
    func quarterValueFormatting() {
        let amount = Amount(1, unit: "cup")
        let scaled = amount.formattedScaled(by: 0.25)
        #expect(scaled == "0.25 cup")
    }

    @Test("Scaling produces clean results for common fractions")
    func cleanFractionScaling() {
        // 2 cups halved = 1 cup
        let amount1 = Amount(2, unit: "cups")
        #expect(amount1.formattedScaled(by: 0.5) == "1 cups")

        // 1 cup doubled = 2 cups
        let amount2 = Amount(1, unit: "cup")
        #expect(amount2.formattedScaled(by: 2.0) == "2 cup")

        // 3 tbsp halved = 1.5 tbsp
        let amount3 = Amount(3, unit: "tbsp")
        #expect(amount3.formattedScaled(by: 0.5) == "1.5 tbsp")
    }

    // MARK: - Yield Scaling Tests

    @Test("Yield scales correctly for half")
    func yieldScalesHalf() {
        let yield = Yield(amount: [Amount(4, unit: "servings")])
        let scaled = yield.formattedScaled(by: 0.5)
        #expect(scaled == "2 servings")
    }

    @Test("Yield scales correctly for double")
    func yieldScalesDouble() {
        let yield = Yield(amount: [Amount(4, unit: "servings")])
        let scaled = yield.formattedScaled(by: 2.0)
        #expect(scaled == "8 servings")
    }

    @Test("Yield unchanged for whole multiplier")
    func yieldUnchangedForWhole() {
        let yield = Yield(amount: [Amount(4, unit: "servings")])
        let original = yield.formatted
        let scaled = yield.formattedScaled(by: 1.0)
        #expect(scaled == original)
    }

    @Test("Multiple yields all scale correctly")
    func multipleYieldsScale() {
        let yield = Yield(amount: [
            Amount(4, unit: "servings"),
            Amount(24, unit: "cookies")
        ])
        let scaled = yield.formattedScaled(by: 0.5)
        #expect(scaled.contains("2 servings"))
        #expect(scaled.contains("12 cookies"))
    }

    // MARK: - Edge Cases

    @Test("Empty yield returns empty string")
    func emptyYieldReturnsEmpty() {
        let yield = Yield(amount: [])
        let scaled = yield.formattedScaled(by: 2.0)
        #expect(scaled.isEmpty)
    }

    @Test("Zero amount scales to zero")
    func zeroAmountScales() {
        let amount = Amount(0, unit: "cups")
        let scaled = amount.formattedScaled(by: 2.0)
        #expect(scaled == "0 cups")
    }

    @Test("Very small multiplier produces correct result")
    func verySmallMultiplier() {
        let amount = Amount(100, unit: "g")
        let scaled = amount.formattedScaled(by: 0.5)
        #expect(scaled == "50 g")
    }

    // MARK: - Unicode Fraction Formatting Tests

    @Test("formatFractionUnicode converts all 9 standard fractions")
    func fractionUnicodeStandardFractions() {
        #expect(Amount.formatFractionUnicode(0.125) == "⅛")
        #expect(Amount.formatFractionUnicode(0.25) == "¼")
        #expect(Amount.formatFractionUnicode(1.0/3.0) == "⅓")
        #expect(Amount.formatFractionUnicode(0.375) == "⅜")
        #expect(Amount.formatFractionUnicode(0.5) == "½")
        #expect(Amount.formatFractionUnicode(0.625) == "⅝")
        #expect(Amount.formatFractionUnicode(2.0/3.0) == "⅔")
        #expect(Amount.formatFractionUnicode(0.75) == "¾")
        #expect(Amount.formatFractionUnicode(0.875) == "⅞")
    }

    @Test("formatFractionUnicode handles mixed numbers")
    func fractionUnicodeMixedNumbers() {
        #expect(Amount.formatFractionUnicode(1.5) == "1½")
        #expect(Amount.formatFractionUnicode(2.25) == "2¼")
        #expect(Amount.formatFractionUnicode(3.75) == "3¾")
        #expect(Amount.formatFractionUnicode(1.0 + 2.0/3.0) == "1⅔")
    }

    @Test("formatFractionUnicode handles whole numbers")
    func fractionUnicodeWholeNumbers() {
        #expect(Amount.formatFractionUnicode(1.0) == "1")
        #expect(Amount.formatFractionUnicode(5.0) == "5")
        #expect(Amount.formatFractionUnicode(0.0) == "0")
    }

    @Test("formatFractionUnicode falls back to decimal for unrecognized fractions")
    func fractionUnicodeFallback() {
        // pi has no standard fraction representation
        let result = Amount.formatFractionUnicode(3.1415)
        #expect(result == "3.14")
    }

    // MARK: - Format-Aware Scaling Tests

    @Test("formattedScaled with decimal format")
    func formattedScaledDecimalFormat() {
        let amount = Amount(0.5, unit: "cup")
        let result = amount.formattedScaled(by: 1.0, format: .decimal)
        #expect(result == "0.5 cup")
    }

    @Test("formattedScaled with fraction format")
    func formattedScaledFractionFormat() {
        let amount = Amount(0.5, unit: "cup")
        let result = amount.formattedScaled(by: 1.0, format: .fraction)
        #expect(result == "½ cup")
    }

    @Test("formattedScaled with fraction format and scaling")
    func formattedScaledFractionFormatScaled() {
        let amount = Amount(1, unit: "cup")
        let result = amount.formattedScaled(by: 1.5, format: .fraction)
        #expect(result == "1½ cup")
    }

    @Test("formattedScaled with original format at 1x returns rawText")
    func formattedScaledOriginalAt1x() {
        let amount = Amount(amount: 0.5, unit: "cup", rawText: "1/2")
        let result = amount.formattedScaled(by: 1.0, format: .original)
        #expect(result == "1/2 cup")
    }

    @Test("formattedScaled with original format at non-1x falls back to fraction")
    func formattedScaledOriginalScaled() {
        let amount = Amount(amount: 0.5, unit: "cup", rawText: "1/2")
        let result = amount.formattedScaled(by: 2.0, format: .original)
        #expect(result == "1 cup")
    }

    @Test("Whole numbers display identically in decimal and fraction formats")
    func wholeNumberConsistentAcrossFormats() {
        let amount = Amount(2, unit: "cups")
        let decimal = amount.formattedScaled(by: 1.0, format: .decimal)
        let fraction = amount.formattedScaled(by: 1.0, format: .fraction)
        #expect(decimal == "2 cups")
        #expect(decimal == fraction)
    }
}
