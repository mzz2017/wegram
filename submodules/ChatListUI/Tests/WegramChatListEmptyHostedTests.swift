import XCTest
import UIKit
import Display
import TelegramPresentationData
import TelegramUIPreferences

final class WegramChatListEmptyHostedTests: XCTestCase {
    private func views(_ view: UIView) -> [UIView] { return [view] + view.subviews.flatMap(self.views) }
    private func update(_ view: WegramChatListEmptyView, title: String = "No chats yet", description: String = "", action: String? = "New Message") {
        view.update(theme: defaultPresentationTheme, fontSize: .regular, title: title, description: description, actionTitle: action, loadingText: "Loading", isLoading: false)
    }
    func testLoadingNonEditableFilterAndRemovedViewRejectOldButtonsAndCanRecover() throws {
        var calls = 0
        XCTAssertEqual(Bundle.main.bundleIdentifier, "app.wegram.qrtesthost")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        let host = UIViewController()
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let view = WegramChatListEmptyView(action: { calls += 1 })
        host.view.addSubview(view)
        view.frame = host.view.bounds
        self.update(view)
        view.updateLayout(insets: .zero)
        let button = try XCTUnwrap(self.views(view).compactMap { $0 as? UIButton }.first)
        XCTAssertNotNil(view.window)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 1)
        view.updateIsLoading(true)
        XCTAssertTrue(button.isHidden)
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(self.views(view).compactMap { $0 as? UIActivityIndicatorView }.first?.isAnimating == true)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 1)
        self.update(view, description: "Only unread chats appear in this folder", action: nil)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 1, "A non-editable unread filter must not expose the previous edit action")
        self.update(view, title: "Empty folder", action: "Edit Folder")
        view.updateLayout(insets: .zero)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 2)
        view.removeFromSuperview()
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 2)
    }

}
