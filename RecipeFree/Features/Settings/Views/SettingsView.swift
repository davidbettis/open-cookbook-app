//
//  SettingsView.swift
//  RecipeFree
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(FolderManager.self) private var folderManager
    @AppStorage("autoNumberInstructions") private var autoNumberInstructions = true
    @State private var showFolderPicker = false
    @State private var showChangeConfirmation = false
    @State private var selectedURL: URL?
    @State private var isLoadingSamples = false
    @State private var showSampleLoadError = false
    @State private var sampleLoadError: Error?
    @State private var samplesLoadedCount = 0
    @State private var showSamplesSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipe Folder")
                            .font(.headline)
                        if let displayName = folderManager.selectedFolderDisplayName {
                            Label(displayName, systemImage: folderManager.isCloudFolder ? "icloud" : "folder")
                                .font(.subheadline)
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
                    Toggle("Auto-number Instructions", isOn: $autoNumberInstructions)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Automatically add step numbers to recipe instructions that don't already have numbering.")
                }

                #if DEBUG
                Section {
                    Button {
                        loadSampleRecipes()
                    } label: {
                        HStack {
                            if isLoadingSamples {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text("Load Sample Recipes")
                        }
                    }
                    .disabled(isLoadingSamples)
                } header: {
                    Text("Testing")
                } footer: {
                    Text("Add 5 sample recipes in RecipeMD format to your selected folder for testing.")
                }
                #endif

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
            .alert("Error Loading Samples", isPresented: $showSampleLoadError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = sampleLoadError {
                    Text(error.localizedDescription)
                }
            }
            .alert("Samples Loaded", isPresented: $showSamplesSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(samplesLoadedCount) sample recipes were added to your folder.")
            }
        }
    }

    // MARK: - Helper Methods

    private func loadSampleRecipes() {
        isLoadingSamples = true
        defer { isLoadingSamples = false }

        // Check if folder is selected
        guard let selectedFolder = folderManager.selectedFolderURL else {
            sampleLoadError = NSError(
                domain: "SettingsView",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Please select a recipe folder first before loading sample recipes."]
            )
            showSampleLoadError = true
            return
        }

        do {
            // Copy sample recipes (fast operation for 5 small files)
            let copiedFiles = try SampleRecipeLoader.copySampleRecipes(to: selectedFolder)
            samplesLoadedCount = copiedFiles.count
            showSamplesSuccess = true
        } catch {
            sampleLoadError = error
            showSampleLoadError = true
        }
    }
}

#Preview {
    SettingsView()
        .environment(FolderManager())
}
