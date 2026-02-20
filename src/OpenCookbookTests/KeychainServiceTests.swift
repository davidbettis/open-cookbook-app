//
//  KeychainServiceTests.swift
//  OpenCookbookTests
//
//  Tests for KeychainService
//

import Foundation
import Testing
@testable import OpenCookbook

@Suite("KeychainService Tests")
struct KeychainServiceTests {

    @Test("Save and read round-trip")
    func saveAndRead() throws {
        try KeychainService.save(key: "test-key", value: "test-value")
        let result = try KeychainService.read(key: "test-key")
        #expect(result == "test-value")
        try KeychainService.delete(key: "test-key")
    }

    @Test("Read returns nil for missing key")
    func readMissing() throws {
        let result = try KeychainService.read(key: "nonexistent-key-\(UUID().uuidString)")
        #expect(result == nil)
    }

    @Test("Delete succeeds for non-existent key")
    func deleteNonExistent() throws {
        try KeychainService.delete(key: "nonexistent-key-\(UUID().uuidString)")
    }

    @Test("Overwrite existing key")
    func overwrite() throws {
        let key = "test-overwrite-\(UUID().uuidString)"
        try KeychainService.save(key: key, value: "first")
        try KeychainService.save(key: key, value: "second")
        let result = try KeychainService.read(key: key)
        #expect(result == "second")
        try KeychainService.delete(key: key)
    }

    @Test("Delete removes key")
    func deleteRemovesKey() throws {
        let key = "test-delete-\(UUID().uuidString)"
        try KeychainService.save(key: key, value: "value")
        try KeychainService.delete(key: key)
        let result = try KeychainService.read(key: key)
        #expect(result == nil)
    }
}
