import UIKit
import Display
import QrCode

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

@objc(WegramQrTestSceneDelegate)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        controller.view.backgroundColor = .white
        let label = UILabel(frame: CGRect(x: 20, y: 100, width: 350, height: 44))
        label.text = "WeGram QR rendering tests"
        controller.view.addSubview(label)
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
        // Keep the production renderer in the executable, before XCTest bundle injection.
        let _ = qrCode(string: "https://t.me/Wegram_QA_fixture", color: .black, icon: .cutout).start(next: { _, _ in })
    }
}
