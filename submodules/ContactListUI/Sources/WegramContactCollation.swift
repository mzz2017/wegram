import Foundation

enum WegramContactCollation {
    static func sortKey(_ name: String) -> String {
        let latin = name.applyingTransform(.toLatin, reverse: false) ?? name
        return latin.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func section(forKey key: String) -> String {
        guard let first = key.unicodeScalars.first, (65...90).contains(first.value) else { return "#" }
        return String(first)
    }

    static func sortKey(firstName: String, lastName: String, lastNameFirst: Bool) -> String {
        let parts = lastNameFirst ? [lastName, firstName] : [firstName, lastName]
        return self.sortKey(parts.filter { !$0.isEmpty }.joined(separator: " "))
    }
}
