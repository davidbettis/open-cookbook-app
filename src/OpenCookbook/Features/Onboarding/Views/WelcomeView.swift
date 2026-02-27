//
//  WelcomeView.swift
//  OpenCookbook
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

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

            Text("Open Cookbook stores your recipes in a folder on your device or in iCloud Drive. Your data stays under your control.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .accessibilityLabel("Get started button")
            .accessibilityHint("Proceeds to storage selection")
        }
    }
}

#Preview {
    WelcomeView(onContinue: {
        print("Get started tapped")
    })
}
