import UIKit
import InvisibleInkDustNode

@objc(Application)
public final class Application: UIApplication {}

@objc(AppDelegate)
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@objc(SceneDelegate)
public final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    public var window: UIWindow?
    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let root = ScratchReviewRoot()
        root.view.backgroundColor = .black
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
    }
}

private final class ScratchReviewRoot: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let preview = ScratchCardPreviewView(frame: CGRect(x: 30, y: 180, width: 300, height: 360))
        preview.setCover(.heart)
        preview.layer.cornerRadius = 22
        view.addSubview(preview)
    }
}
