//
//  WelcomeView.swift
//  RecipeFree
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct WelcomeView: View {
    let onSelectFolder: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityLabel("Folder icon")

            Text("Welcome to RecipeFree")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text("Store your recipes in RecipeMD format. Choose a local folder or iCloud Drive. Your data stays under your control.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onSelectFolder) {
                Text("Select Folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .accessibilityLabel("Select folder button")
            .accessibilityHint("Opens folder picker to choose where recipes will be stored")
        }
    }
}

#Preview {
    WelcomeView(onSelectFolder: {
        print("Select folder tapped")
    })
}
