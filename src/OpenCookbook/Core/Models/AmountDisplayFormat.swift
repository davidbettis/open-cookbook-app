//
//  AmountDisplayFormat.swift
//  OpenCookbook
//
//  Controls how ingredient amounts are displayed
//

import Foundation

enum AmountDisplayFormat: String, CaseIterable {
    case original   // Use Amount.rawText (current behavior)
    case decimal    // Format Amount.amount as decimal string
    case fraction   // Format Amount.amount as fraction/mixed number
}
