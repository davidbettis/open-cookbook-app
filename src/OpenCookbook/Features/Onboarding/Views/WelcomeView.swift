//
//  WelcomeView.swift
//  OpenCookbook
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

            Text("Welcome to Open Cookbook")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text("Open Cookbook stores your recipes on a folder on your device or in iCloud drive. Your data stays under your control. ")
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
