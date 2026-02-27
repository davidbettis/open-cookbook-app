//
//  ToastView.swift
//  OpenCookbook
//
//  Reusable toast component for temporary confirmation messages
//

import SwiftUI

enum ToastStyle {
    case success
    case error

    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .success: .green
        case .error: .red
        }
    }
}

struct ToastView: View {
    let message: String
    var style: ToastStyle = .success

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.iconName)
                .foregroundStyle(style.tintColor)
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - View Modifier

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    var style: ToastStyle = .success
    var duration: TimeInterval = 2.0

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                ToastView(message: message, style: style)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, style: ToastStyle = .success, duration: TimeInterval = 2.0) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, style: style, duration: duration))
    }
}

// MARK: - Previews

#Preview("Success Toast") {
    Color.clear
        .overlay(alignment: .bottom) {
            ToastView(message: "Added 2 tags to 5 recipes", style: .success)
                .padding(.bottom, 16)
        }
}

#Preview("Error Toast") {
    Color.clear
        .overlay(alignment: .bottom) {
            ToastView(message: "Updated 6 of 8 recipes. 2 could not be updated.", style: .error)
                .padding(.bottom, 16)
        }
}
