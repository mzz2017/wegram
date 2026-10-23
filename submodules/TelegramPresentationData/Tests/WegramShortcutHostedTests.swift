import XCTest
import UIKit
import Display

final class WegramShortcutHostedTests: XCTestCase {
    private func items(_ titles: [String]) -> [WegramShortcutMenuItem] {
        return titles.map { WegramShortcutMenuItem(title: $0, image: UIImage(systemName: "star")) }
    }
    private func window(source: UIView) throws -> UIWindow {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "app.wegram.qrtesthost")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(source)
        window.isHidden = false
        return window
    }
    func testActualControllerRejectsButtonsAsSoonAsDismissalBegins() throws {
        for useLifecycleCallback in [false, true] {
            let source = UIView(frame: CGRect(x: 20, y: 44, width: 44, height: 44))
            let window = try self.window(source: source)
            defer { window.isHidden = true }
            var calls = 0
            let controller = WegramShortcutMenuController(sourceView: source, items: self.items(["Saved Messages"]), actions: [{ calls += 1 }], fontSize: 17, alignLeft: true)
            let content = try XCTUnwrap(controller.displayNode.view.subviews.compactMap { $0 as? WegramShortcutMenuView }.first)
            let oldButton = try XCTUnwrap(content.buttons.first)
            XCTAssertNotNil(source.window)
            if useLifecycleCallback {
                controller.viewWillDisappear(true)
            } else {
                controller.dismiss()
            }
            oldButton.sendActions(for: .touchUpInside)
            oldButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(calls, 0, "A closing shortcut menu must not navigate from an old button before viewDidDisappear")
            withExtendedLifetime(window) {}
        }
    }

    func testActualControllerKeepsSelectionAndSourceWindowValidation() throws {
        for removeSource in [false, true] {
            let source = UIView(frame: CGRect(x: 20, y: 44, width: 44, height: 44))
            let window = try self.window(source: source)
            defer { window.isHidden = true }
            var calls = 0
            let controller = WegramShortcutMenuController(sourceView: source, items: self.items(["Saved Messages"]), actions: [{ calls += 1 }], fontSize: 17, alignLeft: true)
            let content = try XCTUnwrap(controller.displayNode.view.subviews.compactMap { $0 as? WegramShortcutMenuView }.first)
            if removeSource { source.removeFromSuperview() }
            content.buttons[0].sendActions(for: .touchUpInside)
            content.buttons[0].sendActions(for: .touchUpInside)
            XCTAssertEqual(calls, removeSource ? 0 : 1)
            withExtendedLifetime(window) {}
        }
    }

    func testDismissalBeforeViewLoadingCannotReactivateItsButtons() throws {
        let source = UIView(frame: CGRect(x: 20, y: 44, width: 44, height: 44))
        let window = try self.window(source: source)
        defer { window.isHidden = true }
        var calls = 0
        let controller = WegramShortcutMenuController(sourceView: source, items: self.items(["Saved Messages"]), actions: [{ calls += 1 }], fontSize: 17, alignLeft: true)
        controller.dismiss()
        let content = try XCTUnwrap(controller.displayNode.view.subviews.compactMap { $0 as? WegramShortcutMenuView }.first)
        content.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 0)
        withExtendedLifetime(window) {}
    }

}
