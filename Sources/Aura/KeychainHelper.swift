import Foundation

// Stores credentials in ~/Library/Application Support/Aura/
// Avoids Keychain password prompts for unsigned/dev builds.
enum KeychainHelper {

    private static var storageURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Aura", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("credentials.plist")
    }

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: storageURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return dict
    }

    private static func save(_ dict: [String: String]) {
        let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        try? data?.write(to: storageURL, options: .atomic)
    }

    static func save(key: String, value: String) -> Bool {
        var dict = load()
        dict[key] = value
        save(dict)
        return true
    }

    static func read(key: String) -> String? {
        load()[key]
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        var dict = load()
        dict.removeValue(forKey: key)
        save(dict)
        return true
    }
}
