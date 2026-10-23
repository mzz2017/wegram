import Foundation

enum WegramCountryList {
    static func sortKey(_ name: String) -> String {
        let latin = name.applyingTransform(.toLatin, reverse: false) ?? name
        return latin.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).uppercased()
    }

    static func sectionKey(_ name: String) -> String {
        guard let first = self.sortKey(name).unicodeScalars.first, (65...90).contains(first.value) else { return "#" }
        return String(first)
    }

    static func commonRegionIds(preferred: String?, isChinese: Bool) -> [String] {
        var result: [String] = []
        for id in [preferred].compactMap({ $0 }) + (isChinese ? ["CN", "HK", "MO"] : []) {
            if !id.isEmpty && !result.contains(id) { result.append(id) }
        }
        return result
    }
}
