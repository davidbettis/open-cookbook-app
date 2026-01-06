//
//  SettingsView.swift
//  DoctorRecipe
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(FolderManager.self) private var folderManager
    @State private var showFolderPicker = false
    @State private var showChangeConfirmation = false
    @State private var selectedURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipe Folder")
                            .font(.headline)
                        if let url = folderManager.selectedFolderURL {
                            Text(url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else {
                            Text("No folder selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button("Change Folder Location") {
                        showChangeConfirmation = true
                    }
                    .foregroundStyle(.blue)
                } header: {
                    Text("Storage")
                }

                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Change Folder?",
                isPresented: $showChangeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Change Folder", role: .destructive) {
                    showFolderPicker = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Changing your folder will switch to a different recipe collection. Your current recipes will not be moved.")
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPicker(
                    selectedURL: $selectedURL,
                    onSelect: { url in
                        try? folderManager.saveFolder(url)
                        showFolderPicker = false
                    },
                    onCancel: {
                        showFolderPicker = false
                    }
                )
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(FolderManager())
}
