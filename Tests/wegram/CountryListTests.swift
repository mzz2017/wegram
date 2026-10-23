import Foundation

@main
struct CountryListTests {
    static func main() {
        precondition(WegramCountryList.sectionKey("阿富汗") == "A")
        precondition(WegramCountryList.sectionKey("中国大陆") == "Z")
        precondition(WegramCountryList.sectionKey("Åland") == "A")
        precondition(WegramCountryList.sectionKey("123") == "#")
        precondition(WegramCountryList.sectionKey("") == "#")
        precondition(WegramCountryList.sortKey("阿富汗") < WegramCountryList.sortKey("中国大陆"))
        precondition(WegramCountryList.commonRegionIds(preferred: "CN", isChinese: true) == ["CN", "HK", "MO"])
        precondition(WegramCountryList.commonRegionIds(preferred: "SG", isChinese: true) == ["SG", "CN", "HK", "MO"])
        precondition(WegramCountryList.commonRegionIds(preferred: "SG", isChinese: false) == ["SG"])
        precondition(WegramCountryList.commonRegionIds(preferred: nil, isChinese: false).isEmpty)
        print("Country list collation and preferred-region checks passed")
    }
}
