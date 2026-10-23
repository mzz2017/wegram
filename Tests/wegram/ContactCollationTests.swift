import Foundation

@main
struct ContactCollationTests {
    static func main() {
        var failures: [String] = []
        for (name, expected) in [("王小明", "W"), ("张三", "Z"), ("陈晨", "C"), ("欧阳", "O"), ("Élodie", "E"), ("  李雷", "L"), ("Ａlice", "A"), ("123", "#"), ("🙂朋友", "#"), ("", "#")] {
            let actual = WegramContactCollation.section(forKey: WegramContactCollation.sortKey(name))
            if actual != expected { failures.append("\(name): expected section \(expected), got \(actual)") }
        }
        let names = ["张三", "王小明", "陈晨"]
        let sorted = names.sorted { WegramContactCollation.sortKey($0) < WegramContactCollation.sortKey($1) }
        if sorted != ["陈晨", "王小明", "张三"] { failures.append("Chinese contacts sorted out of pinyin order: \(sorted)") }
        let givenFirst = WegramContactCollation.sortKey(firstName: "小明", lastName: "王", lastNameFirst: false)
        let familyFirst = WegramContactCollation.sortKey(firstName: "小明", lastName: "王", lastNameFirst: true)
        if WegramContactCollation.section(forKey: givenFirst) != "X" || WegramContactCollation.section(forKey: familyFirst) != "W" { failures.append("Name order preference was ignored") }
        if !failures.isEmpty {
            for failure in failures { print("FAIL: \(failure)") }
            exit(1)
        }
        print("Contact collation behavior checks passed")
    }
}
