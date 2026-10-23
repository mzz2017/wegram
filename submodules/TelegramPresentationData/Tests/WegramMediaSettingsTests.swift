import XCTest
import UIKit
import TelegramUIPreferences

final class WegramMediaSettingsTests: XCTestCase {
    private func cell(_ view: WegramMediaSettingsContentView, section: Int, row: Int) throws -> WegramMediaSettingsCell {
        let path = IndexPath(row: row, section: section)
        view.table.scrollToRow(at: path, at: .middle, animated: false)
        view.table.layoutIfNeeded()
        return try XCTUnwrap(view.table.cellForRow(at: path) as? WegramMediaSettingsCell)
    }
    func testOnlyTheExplicitMediaPreferenceChanges() {
        let photos = GeneratedMediaStoreSettings(storeEditedPhotos: true, storeCapturedMedia: false)
        let result = WegramMediaSetting.editedPhotos.applying(false, to: photos)
        XCTAssertFalse(result.storeEditedPhotos)
        XCTAssertFalse(result.storeCapturedMedia, "Editing preference must not change camera capture saving")
        let calls = VoiceCallSettings(dataSaving: .cellular, enableSystemIntegration: false)
        let enabled = WegramMediaSetting.calls.applying(true, to: calls)
        XCTAssertEqual(enabled.dataSaving, .always)
        XCTAssertFalse(enabled.enableSystemIntegration)
        XCTAssertEqual(WegramMediaSetting.calls.applying(false, to: calls).dataSaving, .never)
        XCTAssertEqual(WegramMediaSetting.editedPhotos.applying(false, to: calls), calls)
        XCTAssertEqual(WegramMediaSetting.calls.applying(false, to: photos), photos)
        XCTAssertEqual(Set((WegramMediaSettingsContentView.sections + WegramMediaSettingsContentView.automaticDownloadSections).flatMap { $0 }), Set(WegramMediaSetting.allCases))
    }
    func testLoadingBusyAccessibilityAndOriginalDestinationIntents() throws {
        let view = WegramMediaSettingsContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        view.layoutIfNeeded()
        var changes: [(WegramMediaSetting, Bool)] = []
        var opened: [WegramMediaSetting] = []
        view.change = { changes.append(($0, $1)) }
        view.open = { opened.append($0) }
        let unloaded = try self.cell(view, section: 1, row: 3)
        XCTAssertFalse(unloaded.toggle.isEnabled)
        XCTAssertTrue(unloaded.toggle.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(unloaded.toggle.accessibilityValue, "正在加载")
        unloaded.toggle.sendActions(for: .valueChanged)
        XCTAssertTrue(changes.isEmpty)
        view.load(editedPhotos: true, lessCallData: true, callScope: "当前仅移动网络省流量")
        let photos = try self.cell(view, section: 1, row: 3)
        XCTAssertTrue(photos.toggle.isOn)
        XCTAssertTrue(photos.toggle.isEnabled)
        photos.toggle.isOn = false
        photos.toggle.sendActions(for: .valueChanged)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].0, .editedPhotos)
        XCTAssertFalse(changes[0].1)
        let calls = try self.cell(view, section: 2, row: 0)
        XCTAssertEqual(calls.toggle.accessibilityHint, "当前仅移动网络省流量")
        XCTAssertTrue(calls.toggle.isOn)
        for (section, rows) in WegramMediaSettingsContentView.sections.enumerated() {
            for (row, field) in rows.enumerated() where !field.isToggle {
                view.tableView(view.table, didSelectRowAt: IndexPath(row: row, section: section))
            }
        }
        XCTAssertEqual(opened, [.cellular, .wifi, .privateChats, .groups, .channels])
        view.busy = true
        calls.toggle.sendActions(for: .valueChanged)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(opened.count, 5)
        let busy = try self.cell(view, section: 2, row: 0)
        XCTAssertFalse(busy.toggle.isEnabled)
        XCTAssertTrue(busy.toggle.accessibilityTraits.contains(.notEnabled))
        view.busy = false
        let restored = try self.cell(view, section: 1, row: 3)
        XCTAssertTrue(restored.toggle.isOn, "An intent must not replace the stored preference with optimistic state")
        XCTAssertFalse(restored.toggle.accessibilityTraits.contains(.notEnabled))
    }
    func testAutodownloadMasterOnlyChangesTheChosenConnection() {
        var settings = MediaAutoDownloadSettings.defaultSettings
        settings.cellular.preset = .custom
        settings.cellular.custom = settings.presets.high
        settings.wifi.preset = .low
        settings.wifi.custom = settings.presets.medium
        settings.downloadInBackground = false
        settings.highQualityStories = true
        let mobile = WegramMediaSetting.master.applying(false, to: settings, network: .cellular)
        XCTAssertFalse(mobile.cellular.enabled)
        XCTAssertEqual(mobile.cellular.preset, settings.cellular.preset)
        XCTAssertEqual(mobile.cellular.custom, settings.cellular.custom)
        XCTAssertEqual(mobile.wifi, settings.wifi)
        XCTAssertEqual(mobile.presets, settings.presets)
        XCTAssertEqual(mobile.energyUsageSettings, settings.energyUsageSettings)
        XCTAssertFalse(mobile.downloadInBackground)
        XCTAssertTrue(mobile.highQualityStories)
        let wifi = WegramMediaSetting.master.applying(false, to: settings, network: .wifi)
        XCTAssertFalse(wifi.wifi.enabled)
        XCTAssertEqual(wifi.cellular, settings.cellular)
        XCTAssertEqual(wifi.wifi.preset, settings.wifi.preset)
        XCTAssertEqual(wifi.wifi.custom, settings.wifi.custom)
        XCTAssertEqual(WegramMediaSetting.photos.applying(false, to: settings, network: .wifi), settings)
    }
    func testAutodownloadLoadingDisabledMasterAndBusyRejectOldActions() throws {
        let view = WegramMediaSettingsContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        view.automaticDownload = true
        view.loadAutomaticDownload(enabled: nil, summaries: [:], voiceInfo: "Voice messages use the original download rules")
        view.layoutIfNeeded()
        var opens: [WegramMediaSetting] = []
        var changes: [Bool] = []
        view.open = { opens.append($0) }
        view.change = { field, value in
            XCTAssertEqual(field, .master)
            changes.append(value)
        }
        let loading = try self.cell(view, section: 0, row: 0)
        XCTAssertFalse(loading.toggle.isEnabled)
        XCTAssertEqual(loading.toggle.accessibilityValue, "正在加载")
        loading.toggle.sendActions(for: .valueChanged)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertTrue(opens.isEmpty)
        XCTAssertTrue(changes.isEmpty)
        view.loadAutomaticDownload(enabled: false, summaries: [.photos: "Contacts only"], voiceInfo: "Original voice rules")
        let disabled = try self.cell(view, section: 1, row: 0)
        XCTAssertTrue(disabled.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(disabled.accessibilityValue, "Contacts only")
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertTrue(opens.isEmpty)
        view.loadAutomaticDownload(enabled: true, summaries: [.photos: "Contacts only"], voiceInfo: "Original voice rules")
        for row in 0..<3 { view.tableView(view.table, didSelectRowAt: IndexPath(row: row, section: 1)) }
        XCTAssertEqual(opens, [.photos, .videos, .files])
        let master = try self.cell(view, section: 0, row: 0)
        master.toggle.isOn = false
        master.toggle.sendActions(for: .valueChanged)
        XCTAssertEqual(changes, [false])
        view.busy = true
        master.toggle.sendActions(for: .valueChanged)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(changes, [false])
        XCTAssertEqual(opens.count, 3)
        view.busy = false
        view.loadAutomaticDownload(enabled: false, summaries: [:], voiceInfo: "Original voice rules")
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(opens.count, 3, "An old category intent cannot run after master is disabled")
    }
    func testAutodownloadSummariesWrapAndReflowWithoutClipping() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                let view = WegramMediaSettingsContentView(frame: .zero)
                view.automaticDownload = true
                view.update(dark: dark, fontSize: font, chinese: true)
                let summary = "最多 1.5 GB，联系人、其他私聊、群组和频道；保留原大小限制和会话范围"
                view.loadAutomaticDownload(enabled: true, summaries: [.photos: summary, .videos: summary, .files: summary], voiceInfo: "测试说明：语音消息沿用原有自动下载规则。")
                for width: CGFloat in [402, 320, 720, 402] {
                    view.frame = CGRect(x: 0, y: 0, width: width, height: 800)
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    for row in 0..<3 {
                        let cell = try self.cell(view, section: 1, row: row)
                        cell.layoutIfNeeded()
                        XCTAssertFalse(cell.accessibilityTraits.contains(.notEnabled))
                        XCTAssertEqual(cell.accessibilityValue, summary)
                        XCTAssertGreaterThanOrEqual(cell.summary.frame.minY - cell.name.frame.maxY, 4)
                        XCTAssertLessThanOrEqual(cell.summary.frame.maxY, cell.bounds.height - 12)
                        XCTAssertLessThan(cell.summary.frame.maxX, cell.arrow.frame.minX)
                        XCTAssertLessThanOrEqual(cell.summary.sizeThatFits(CGSize(width: cell.summary.bounds.width, height: .greatestFiniteMagnitude)).height, cell.summary.bounds.height + 1)
                        XCTAssertFalse(cell.summary.isAccessibilityElement)
                    }
                    if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        view.table.setContentOffset(.zero, animated: false)
                        view.table.layoutIfNeeded()
                        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "autodownload-dark-component.png" : "autodownload-light-component.png"))
                    }
                }
            }
        }
    }
    func testFirstLayoutAndRotationReflowTheExistingExplanationHeader() throws {
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        let view = WegramMediaSettingsContentView(frame: .zero)
        view.update(dark: false, fontSize: 34, chinese: false)
        view.load(editedPhotos: true, lessCallData: false, callScope: "Data saving is off")
        for width: CGFloat in [402, 320, 720, 402] {
            view.frame = CGRect(x: 0, y: 0, width: width, height: 800)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            view.table.setContentOffset(.zero, animated: false)
            view.table.layoutIfNeeded()
            let explanation = try XCTUnwrap(descendants(view.table).compactMap { $0 as? UILabel }.first { $0.text?.hasPrefix("Choose automatic downloads") == true })
            XCTAssertEqual(explanation.bounds.width, width - 32, "Existing explanation did not reflow when the page width changed")
            let expected = explanation.sizeThatFits(CGSize(width: width - 32, height: .greatestFiniteMagnitude)).height
            XCTAssertGreaterThanOrEqual(explanation.bounds.height + 1, expected, "Rotation clipped the explanation")
        }
    }
    func testFlatRowsWrapLongLabelsAndRetainSwitchTouchArea() throws {
        for width: CGFloat in [320, 402, 720] {
            for font: CGFloat in [17, 34] {
                let view = WegramMediaSettingsContentView(frame: CGRect(x: 0, y: 0, width: width, height: 800))
                view.update(dark: false, fontSize: font, chinese: false)
                view.load(editedPhotos: true, lessCallData: false, callScope: "Data saving is off")
                view.layoutIfNeeded()
                for (section, rows) in WegramMediaSettingsContentView.sections.enumerated() {
                    for (row, field) in rows.enumerated() {
                        let cell = try self.cell(view, section: section, row: row)
                        cell.layoutIfNeeded()
                        XCTAssertEqual(cell.frame.width, width)
                        XCTAssertEqual(cell.name.frame.minX, 16)
                        XCTAssertGreaterThanOrEqual(cell.frame.height, 56)
                        let measured = cell.name.sizeThatFits(CGSize(width: cell.name.bounds.width, height: .greatestFiniteMagnitude)).height
                        XCTAssertLessThanOrEqual(measured, cell.name.bounds.height + 1, "Media title is clipped at width \(width), font \(font)")
                        if field.isToggle {
                            XCTAssertGreaterThanOrEqual(cell.toggle.bounds.height, 44)
                            XCTAssertGreaterThanOrEqual(cell.toggle.bounds.width, 44)
                            XCTAssertLessThan(cell.name.frame.maxX, cell.toggle.frame.minX)
                            XCTAssertEqual(cell.contentView.bounds.width - cell.toggle.frame.maxX, 16)
                            XCTAssertFalse(cell.isAccessibilityElement)
                        } else {
                            XCTAssertLessThan(cell.name.frame.maxX, cell.arrow.frame.minX)
                            XCTAssertTrue(cell.isAccessibilityElement)
                        }
                    }
                }
                if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    view.table.setContentOffset(.zero, animated: false)
                    view.table.layoutIfNeeded()
                    let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("media-settings-component.png"))
                }
            }
        }
    }
}
