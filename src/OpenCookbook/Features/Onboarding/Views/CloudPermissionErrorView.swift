//
//  CloudPermissionErrorView.swift
//  OpenCookbook
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct CloudPermissionErrorView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .accessibilityLabel("iCloud warning icon")

            Text("iCloud Access Required")
                .font(.title2)
                .bold()

            Text("Please enable iCloud Drive in Settings to use Open Cookbook. Your recipes will be stored in your iCloud Drive for access across devices.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .accessibilityLabel("Open Settings button")
            .accessibilityHint("Opens iOS Settings to enable iCloud Drive")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    CloudPermissionErrorView()
}
