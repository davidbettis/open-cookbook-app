//
//  FolderConfirmationView.swift
//  OpenCookbook
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct FolderConfirmationView: View {
    let folderURL: URL
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .accessibilityLabel("Success checkmark")

            Text("Folder Selected")
                .font(.largeTitle)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("Your recipes will be stored in:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(folderURL.path)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .accessibilityLabel("Folder path: \(folderURL.path)")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .accessibilityLabel("Continue button")
            .accessibilityHint("Proceeds to the main app")
        }
    }
}

#Preview {
    FolderConfirmationView(
        folderURL: URL(fileURLWithPath: "/Users/example/iCloud/Recipes"),
        onContinue: {
            print("Continue tapped")
        }
    )
}
