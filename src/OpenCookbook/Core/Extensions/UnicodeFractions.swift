//
//  UnicodeFractions.swift
//  OpenCookbook
//
//  Shared unicode fraction lookup table for parsing and formatting
//

import Foundation

enum UnicodeFractions {
    /// All supported unicode fractions, sorted by value ascending
    static let all: [(character: Character, value: Double)] = [
        ("⅛", 1.0 / 8.0),
        ("⅙", 1.0 / 6.0),
        ("⅕", 1.0 / 5.0),
        ("¼", 1.0 / 4.0),
        ("⅓", 1.0 / 3.0),
        ("⅜", 3.0 / 8.0),
        ("⅖", 2.0 / 5.0),
        ("½", 1.0 / 2.0),
        ("⅗", 3.0 / 5.0),
        ("⅝", 5.0 / 8.0),
        ("⅔", 2.0 / 3.0),
        ("¾", 3.0 / 4.0),
        ("⅘", 4.0 / 5.0),
        ("⅚", 5.0 / 6.0),
        ("⅞", 7.0 / 8.0),
    ]

    /// Character → Double lookup for parsing user input
    private static let characterToValue: [Character: Double] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.character, $0.value) })
    }()

    /// Get the numeric value for a unicode fraction character
    static func value(for character: Character) -> Double? {
        characterToValue[character]
    }

    /// Get the unicode fraction character closest to a fractional value
    static func character(for value: Double) -> Character? {
        for entry in all {
            if abs(value - entry.value) < 0.01 {
                return entry.character
            }
        }
        return nil
    }
}
