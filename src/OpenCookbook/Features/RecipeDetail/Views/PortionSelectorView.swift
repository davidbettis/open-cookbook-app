//
//  PortionSelectorView.swift
//  OpenCookbook
//
//  Dropdown picker for selecting portion size multiplier
//

import SwiftUI

/// A dropdown picker for selecting portion size (half, whole, double)
struct PortionSelectorView: View {
    @Binding var selectedPortion: PortionOption

    var body: some View {
        HStack {
            Text("Portions:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Portion size", selection: $selectedPortion) {
                ForEach(PortionOption.allOptions) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Portion size")
            .accessibilityHint("Select portion multiplier for ingredient quantities")
        }
    }
}

// MARK: - Previews

#Preview("Portion Selector") {
    struct PreviewWrapper: View {
        @State private var portion = PortionOption.whole

        var body: some View {
            VStack(spacing: 20) {
                PortionSelectorView(selectedPortion: $portion)

                Text("Multiplier: \(portion.multiplier, specifier: "%.1f")")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
