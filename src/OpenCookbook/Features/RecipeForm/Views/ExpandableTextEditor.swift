//
//  ExpandableTextEditor.swift
//  OpenCookbook
//
//  Reusable fixed-height TextEditor with expand-to-sheet button
//

import SwiftUI

/// A fixed-height TextEditor with a button to expand into a full-screen sheet
struct ExpandableTextEditor: View {
    @Binding var text: String
    let title: String
    let fixedHeight: CGFloat

    @State private var isExpanded = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: $text)
                .frame(height: fixedHeight)
                .scrollDisabled(true)

            Button {
                isExpanded = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
            .accessibilityLabel("Expand \(title)")
        }
        .sheet(isPresented: $isExpanded) {
            NavigationStack {
                TextEditor(text: $text)
                    .padding(.horizontal)
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isExpanded = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    @Previewable @State var text = "Some sample text\nwith multiple lines"
    Form {
        Section("Description") {
            ExpandableTextEditor(text: $text, title: "Description", fixedHeight: 80)
        }
    }
}
