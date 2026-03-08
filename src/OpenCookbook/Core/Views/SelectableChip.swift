//
//  SelectableChip.swift
//  OpenCookbook
//
//  Shared selectable chip/tag component used in tag filter bar, tag picker, and bulk tag views
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A capsule-shaped chip that toggles between selected and unselected states.
///
/// Used by `TagFilterBar`, `TagPickerView`, and `BulkTagRemoveView`.
struct SelectableChip: View {
    let text: String
    let badge: String?
    let isSelected: Bool
    let showCheckmark: Bool
    let action: () -> Void

    init(
        _ text: String,
        badge: String? = nil,
        isSelected: Bool,
        showCheckmark: Bool = false,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.badge = badge
        self.isSelected = isSelected
        self.showCheckmark = showCheckmark
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                if showCheckmark && isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(text)
                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            isSelected
                                ? Color.white.opacity(0.3)
                                : Color(.systemGray4)
                        )
                        .clipShape(Capsule())
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color(.systemGray4),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
