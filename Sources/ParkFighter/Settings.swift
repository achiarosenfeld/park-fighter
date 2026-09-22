import Foundation

/// Menu-bar toggles, persisted in UserDefaults. `--safe` forces every prank that touches another app off.
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    /// Punching, kicking and shoving other apps' windows around.
    var beatUpWindows: Bool { get { flag("beatUpWindows", true) } set { d.set(newValue, forKey: "beatUpWindows") } }
    /// The finishers: closing and minimising the window he just beat up.
    var closeWindows: Bool { get { flag("closeWindows", true) } set { d.set(newValue, forKey: "closeWindows") } }
    /// His photographed head on the drawn body, when a head.png is available.
    var photoHead: Bool { get { flag("photoHead", true) } set { d.set(newValue, forKey: "photoHead") } }
    var scale: CGFloat {
        get { let v = d.double(forKey: "scale"); return v > 0 ? CGFloat(v) : 2.2 }
        set { d.set(Double(newValue), forKey: "scale") }
    }
    var napping = false
    var safeMode = false
    var debugLog = false

    /// `--safe` does not stop him swinging, it stops the swings landing (see Engine.perform).
    var mayTouchWindows: Bool { beatUpWindows && !napping }
    var mayCloseWindows: Bool { mayTouchWindows && closeWindows }

    private func flag(_ key: String, _ fallback: Bool) -> Bool {
        d.object(forKey: key) == nil ? fallback : d.bool(forKey: key)
    }
}
