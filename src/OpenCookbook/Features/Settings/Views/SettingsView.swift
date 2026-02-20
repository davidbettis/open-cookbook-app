//
//  SettingsView.swift
//  OpenCookbook
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(FolderManager.self) private var folderManager
    @AppStorage("autoNumberInstructions") private var autoNumberInstructions = true
    @AppStorage("amountDisplayFormat") private var amountDisplayFormat: String = AmountDisplayFormat.original.rawValue
    @AppStorage("importProvider") private var importProvider: String = "claude"
    @AppStorage("claudeModel") private var claudeModelRawValue: String = AnthropicAPIService.ClaudeModel.sonnet.rawValue
    @State private var apiKey: String = ""
    @State private var isVerifyingKey = false
    @State private var keyVerified = false
    @State private var showKeyError = false
    @State private var keyErrorMessage = ""
    @State private var showAPIKey = false
    @State private var showFolderPicker = false
    @State private var showChangeConfirmation = false
    @State private var selectedURL: URL?
    @State private var isLoadingSamples = false
    @State private var showSampleLoadError = false
    @State private var sampleLoadError: Error?
    @State private var samplesLoadedCount = 0
    @State private var showSamplesSuccess = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

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

                    Picker("Amount Format", selection: $amountDisplayFormat) {
                        Text("Original").tag(AmountDisplayFormat.original.rawValue)
                        Text("Decimal").tag(AmountDisplayFormat.decimal.rawValue)
                        Text("Fraction").tag(AmountDisplayFormat.fraction.rawValue)
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Choose how ingredient amounts are displayed. Original shows amounts as written in the recipe file.")
                }

                importRecipeSection

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
                    Link(destination: URL(string: "mailto:opencookbook@davidbettis.com?subject=OpenCookbook%20Feedback")!) {
                        HStack {
                            Label("Send Feedback", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Open Cookbook is still a work in progress. We'd love to hear your suggestions and feedback.")
                }

                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(appVersion)
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
            .onAppear { loadAPIKey() }
            .alert("API Key Error", isPresented: $showKeyError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(keyErrorMessage)
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

    // MARK: - Subviews

    private var importRecipeSection: some View {
        Section {
            Picker("Provider", selection: $importProvider) {
                Text("Claude (Anthropic)").tag("claude")
            }

            if importProvider == "claude" {
                Picker("Model", selection: $claudeModelRawValue) {
                    ForEach(AnthropicAPIService.ClaudeModel.allCases) { model in
                        Text(model.displayName).tag(model.rawValue)
                    }
                }

                HStack {
                    if showAPIKey {
                        TextField("API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textContentType(.password)
                    }
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .onSubmit { saveAPIKey() }
                .onChange(of: apiKey) { _, _ in keyVerified = false }

                verifyKeyButton
            }
        } header: {
            Text("Import Recipe")
        } footer: {
            Text("Sign up for Claude and get a key at [platform.claude.com/settings/keys](https://platform.claude.com/settings/keys)")
        }
    }

    private var verifyKeyButton: some View {
        Button {
            Task { await verifyKey() }
        } label: {
            HStack {
                Text("Verify Key")
                Spacer()
                if isVerifyingKey {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if keyVerified {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .disabled(apiKey.isEmpty || isVerifyingKey)
    }

    // MARK: - Helper Methods

    private func loadAPIKey() {
        if let key = try? KeychainService.read(key: "anthropic-api-key") {
            apiKey = key
        }
    }

    private func saveAPIKey() {
        do {
            if apiKey.isEmpty {
                try KeychainService.delete(key: "anthropic-api-key")
            } else {
                try KeychainService.save(key: "anthropic-api-key", value: apiKey)
            }
        } catch {
            keyErrorMessage = error.localizedDescription
            showKeyError = true
        }
    }

    private func verifyKey() async {
        saveAPIKey()
        isVerifyingKey = true
        defer { isVerifyingKey = false }

        do {
            let service = AnthropicAPIService()
            _ = try await service.verifyAPIKey(apiKey)
            keyVerified = true
        } catch {
            keyErrorMessage = error.localizedDescription
            showKeyError = true
        }
    }

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
