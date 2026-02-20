//
//  ImportRecipeView.swift
//  OpenCookbook
//
//  URL input sheet for importing recipes from websites via Claude
//

import SwiftUI

extension Notification.Name {
    static let importRecipeCompleted = Notification.Name("importRecipeCompleted")
}

struct ImportRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ImportRecipeViewModel()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.hasAPIKey {
                    noAPIKeySection
                } else {
                    urlInputSection
                    if viewModel.isImporting {
                        loadingSection
                    }
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("Try Again") { viewModel.state = .idle }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: viewModel.state) { _, newState in
                switch newState {
                case .success(let markdown):
                    NotificationCenter.default.post(
                        name: .importRecipeCompleted,
                        object: nil,
                        userInfo: ["markdown": markdown]
                    )
                    dismiss()
                case .error(let message):
                    errorMessage = message
                    showError = true
                default:
                    break
                }
            }
        }
    }

    private var noAPIKeySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "key")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Set up your API key in Settings to import recipes.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private var urlInputSection: some View {
        Section {
            TextField("Paste recipe URL here", text: $viewModel.urlText)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                Task { await viewModel.importRecipe() }
            } label: {
                Text("Import Recipe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.urlText.isEmpty || viewModel.isImporting)
        } header: {
            Text("Paste a recipe URL and Claude will extract the recipe for you.")
        }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        }
    }
}
