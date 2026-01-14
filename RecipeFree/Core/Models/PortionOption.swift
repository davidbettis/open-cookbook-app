//
//  PortionOption.swift
//  RecipeFree
//
//  Model representing portion scaling options
//

import Foundation

/// Represents a portion scaling option with a display label and multiplier
struct PortionOption: Identifiable, Hashable, Equatable {
    let id: String
    let label: String
    let multiplier: Double

    // MARK: - Preset Options

    static let half = PortionOption(id: "half", label: "Half (0.5x)", multiplier: 0.5)
    static let whole = PortionOption(id: "whole", label: "Whole (1x)", multiplier: 1.0)
    static let double = PortionOption(id: "double", label: "Double (2x)", multiplier: 2.0)

    /// All available portion options in display order
    static let allOptions: [PortionOption] = [.half, .whole, .double]
}
