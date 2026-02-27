//
//  InstructionAmountDetector.swift
//  OpenCookbook
//
//  Detects ingredient amounts in instruction text that won't scale with portions
//

import Foundation

enum InstructionAmountDetector {

    // Matches numeric quantities (including fractions and unicode fractions)
    // followed by common cooking measurement units.
    // Deliberately excludes temperatures (°F/°C), times (minutes/hours), and step numbers.
    private static let pattern =
        #"(?i)(?:^|\b|(?<=\s))(\d[\d./]*|[½¼¾⅓⅔⅛⅜⅝⅞])\s*(cups?|tablespoons?|tbsp|teaspoons?|tsp|ounces?|oz|pounds?|lbs?|grams?|g|kilograms?|kg|milliliters?|ml|liters?|l|quarts?|qt|pints?|pt|gallons?|gal|sticks?|cloves?|slices?|pieces?|t|c)\b"#

    private static let regex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: pattern)
    }()

    /// Returns `true` when the text contains numeric quantities followed by cooking units.
    static func containsAmounts(_ text: String) -> Bool {
        guard !text.isEmpty, let regex else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
