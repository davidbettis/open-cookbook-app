//
//  URL+SecurityScoped.swift
//  OpenCookbook
//
//  Convenience extension for security-scoped resource access
//

import Foundation

extension URL {
    /// Execute a closure with security-scoped resource access, automatically
    /// starting access before and stopping access after the closure runs.
    func withSecurityScopedAccess<T>(_ body: () throws -> T) rethrows -> T {
        let didStartAccess = startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }
}
