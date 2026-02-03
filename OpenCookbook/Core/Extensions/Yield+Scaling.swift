//
//  Yield+Scaling.swift
//  OpenCookbook
//
//  Extension for scaling RecipeMD Yield values
//

import Foundation
import RecipeMD

extension Yield {
    /// Returns a formatted string with all yield amounts scaled by the given multiplier
    /// - Parameter multiplier: The scaling factor (e.g., 0.5 for half, 2.0 for double)
    /// - Returns: Formatted string with scaled yields
    func formattedScaled(by multiplier: Double) -> String {
        // If multiplier is 1.0, just return the original formatted string
        if multiplier == 1.0 {
            return self.formatted
        }

        // Scale each amount in the yield
        let scaledAmounts = self.amount.map { amount -> String in
            amount.formattedScaled(by: multiplier)
        }

        return scaledAmounts.joined(separator: ", ")
    }
}
