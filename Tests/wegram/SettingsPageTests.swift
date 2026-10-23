import Foundation

@main struct SettingsPageTests {
    static func main() {
        let root = WegramSettingsPage.root.sections
        precondition(root.count == 5 && root.first == [.security])
        precondition(root.suffix(2) == [[.accounts], [.logout]], "Account controls must remain separate centered rows")
        precondition(WegramSettingsPage.general.sections.contains([.wallpaper]), "Chat background must be reachable directly from General")
        precondition(WegramSettingsPage.wallpaper.sections == [[.wallpaperPresets], [.wallpaperPhoto, .wallpaperCamera]], "Background choices must have distinct working routes")
        let pages: [WegramSettingsPage] = [.root, .general, .personal, .personalMore, .security, .wallpaper]
        let visible = pages.flatMap { $0.sections.flatMap { $0 } }
        for page in pages {
            let rows = page.sections.flatMap { $0 }
            precondition(Set(rows).count == rows.count, "Duplicate destination within a settings page")
        }
        precondition(Set(visible + [.advanced]) == Set(WegramSettingsDestination.allCases), "Setting lost from visible or more entry")
        for destination in WegramSettingsDestination.allCases {
            precondition(!destination.title(chinese: true).isEmpty && !destination.title(chinese: false).isEmpty)
        }
        precondition(WegramSettingsDestination.about.title(chinese: true).contains("WeGram"))
        precondition(WegramSettingsDestination.about.title(chinese: false).contains("WeGram"))
        print("Settings grouping, destination coverage, distinct account controls and app naming checks passed")
    }
}
