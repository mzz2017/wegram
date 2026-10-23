import Foundation

@main
struct HeaderGeometryTests {
    static func main() {
        var failures: [String] = []
        for lowerBound: CGFloat in [800, 1000, 1200] {
            let y = ListViewHeaderGeometry.bottomOriginY(upperBound: 200, lowerBound: lowerBound, displayBound: 800, height: 40, isSticky: false)
            if y != lowerBound - 40 { failures.append("Non-sticky avatar stayed at viewport edge while message scrolled: \(y), expected \(lowerBound - 40)") }
        }
        let sticky = ListViewHeaderGeometry.bottomOriginY(upperBound: 200, lowerBound: 1000, displayBound: 800, height: 40, isSticky: true)
        if sticky != 760 { failures.append("Sticky header no longer stays at viewport edge") }
        let short = ListViewHeaderGeometry.bottomOriginY(upperBound: 790, lowerBound: 800, displayBound: 800, height: 40, isSticky: false)
        if short != 790 { failures.append("Header escaped its message boundary") }
        if !failures.isEmpty {
            for failure in failures { print("FAIL: \(failure)") }
            exit(1)
        }
        print("Header scrolling behavior checks passed")
    }
}
