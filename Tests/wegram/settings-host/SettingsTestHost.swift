import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

@objc(WegramSettingsTestSceneDelegate)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = SettingsFixtureController()
        self.window = window
        window.makeKeyAndVisible()
    }
}

// A fixture for real touch delivery. No AccountContext, settings storage or requests.
final class SettingsFixtureController: UIViewController {
    private let content = WegramDarkModeContentView()
    private let titleLabel = UILabel()
    private let status = UILabel()
    private let lock = UIButton(type: .system)
    private var mode: WegramDarkMode = .light
    private var eventCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        self.titleLabel.text = "UI TEST • 深色模式"
        self.titleLabel.textAlignment = .center
        self.titleLabel.font = .systemFont(ofSize: 17)
        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.content)
        self.view.addSubview(self.status)
        self.view.addSubview(self.lock)
        self.status.numberOfLines = 0
        self.status.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        self.status.accessibilityIdentifier = "Fixture.Status"
        self.lock.setTitle("Lock / Unlock", for: .normal)
        self.lock.accessibilityIdentifier = "Fixture.Lock"
        self.lock.addAction(UIAction(handler: { [weak self] _ in
            guard let self else { return }
            self.content.submitting.toggle()
            self.refresh()
        }), for: .touchUpInside)
        self.content.change = { [weak self] mode in
            guard let self else { return }
            self.eventCount += 1
            self.mode = mode
            self.refresh()
        }
        if #available(iOS 17.0, *) {
            self.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: SettingsFixtureController, _: UITraitCollection) in self.refresh() }
        }
        self.refresh()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17.0) { self.refresh() }
    }
    private func refresh() {
        let style: UIUserInterfaceStyle = self.mode == .system ? .unspecified : (self.mode == .dark ? .dark : .light)
        if self.overrideUserInterfaceStyle != style { self.overrideUserInterfaceStyle = style }
        let dark = self.mode == .dark || (self.mode == .system && self.traitCollection.userInterfaceStyle == .dark)
        self.view.backgroundColor = dark ? .black : .white
        self.titleLabel.textColor = dark ? .white : .black
        self.status.textColor = dark ? .white : .black
        self.content.update(dark: dark, fontSize: 17, chinese: true)
        self.content.load(mode: self.mode)
        self.status.text = "fixture only • events=\(self.eventCount)\nmode=\(self.mode) • locked=\(self.content.submitting)"
        self.status.accessibilityValue = self.status.text
        self.view.setNeedsLayout()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = self.view.safeAreaInsets.top
        let bottom = self.view.bounds.height - self.view.safeAreaInsets.bottom
        let width = self.view.bounds.width
        self.titleLabel.frame = CGRect(x: 0, y: top, width: width, height: 44)
        self.content.frame = CGRect(x: 0, y: top + 44, width: width, height: max(0, bottom - top - 152))
        self.status.frame = CGRect(x: 16, y: bottom - 104, width: width - 32, height: 60)
        self.lock.frame = CGRect(x: 16, y: bottom - 44, width: width - 32, height: 44)
    }
}
