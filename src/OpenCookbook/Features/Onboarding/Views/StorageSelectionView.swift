//
//  StorageSelectionView.swift
//  OpenCookbook
//
//  Created by Claude Code on 2/26/26.
//

import SwiftUI

struct StorageSelectionView: View {
    let onSelectLocal: () -> Void
    let onSelectCustom: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Where should we store your recipes?")
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 16) {
                StorageOptionButton(
                    icon: "folder",
                    title: "Use a default folder on your device",
                    subtitle: "Documents/Recipes",
                    action: onSelectLocal
                )

                StorageOptionButton(
                    icon: "folder.badge.questionmark",
                    title: "Pick your own folder",
                    subtitle: "Choose a local or iCloud Drive folder",
                    action: onSelectCustom
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

private struct StorageOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

#Preview {
    StorageSelectionView(
        onSelectLocal: {},
        onSelectCustom: {}
    )
}
