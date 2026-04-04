import Foundation
import Testing
@testable import Aura

@Suite("KeychainHelper")
struct KeychainHelperTests {

    private let testKey = "aura_test_key_\(UUID().uuidString)"

    @Test func saveAndRead() {
        let saved = KeychainHelper.save(key: testKey, value: "secret123")
        #expect(saved)

        let read = KeychainHelper.read(key: testKey)
        #expect(read == "secret123")

        KeychainHelper.delete(key: testKey)
    }

    @Test func readNonExistent() {
        let result = KeychainHelper.read(key: "nonexistent_key_\(UUID().uuidString)")
        #expect(result == nil)
    }

    @Test func overwriteExistingValue() {
        _ = KeychainHelper.save(key: testKey, value: "old")
        _ = KeychainHelper.save(key: testKey, value: "new")

        let read = KeychainHelper.read(key: testKey)
        #expect(read == "new")

        KeychainHelper.delete(key: testKey)
    }

    @Test func deleteReturnsTrue() {
        _ = KeychainHelper.save(key: testKey, value: "todelete")
        let deleted = KeychainHelper.delete(key: testKey)
        #expect(deleted)

        let read = KeychainHelper.read(key: testKey)
        #expect(read == nil)
    }

    @Test func deleteNonExistentReturnsTrue() {
        let deleted = KeychainHelper.delete(key: "nonexistent_\(UUID().uuidString)")
        #expect(deleted)
    }
}
