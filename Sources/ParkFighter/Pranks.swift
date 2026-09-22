import AppKit
import ApplicationServices

/// Everything that reaches out of the overlay and touches somebody else's window.
/// All of it needs Accessibility permission; without it the fighter just swings at air.
final class Pranks {
    private var cache: [CGWindowID: AXUIElement] = [:]
    private var shakes: [CGWindowID: Shake] = [:]
    private var promptedForPermission = false

    private struct Shake {
        var element: AXUIElement
        var home: CGPoint
        var power: CGFloat
        var left: CGFloat
    }

    var isTrusted: Bool { AXIsProcessTrusted() }

    /// Asks once per launch, and only when the fighter actually tries something.
    @discardableResult
    func requestPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        guard !promptedForPermission else { return false }
        promptedForPermission = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func forget(_ id: CGWindowID) {
        cache[id] = nil
        shakes[id] = nil
    }

    // MARK: - Actions

    /// A punch: the window rattles in place and settles back where it was.
    func shake(_ window: ScannedWindow, power: CGFloat) {
        guard let element = resolve(window), let home = position(of: element) else { return }
        shakes[window.id] = Shake(element: element, home: home, power: power, left: 0.32)
    }

    /// A kick: the window actually slides across the desk and stays there.
    func shove(_ window: ScannedWindow, by delta: CGPoint) {
        guard let element = resolve(window), let home = position(of: element) else { return }
        guard let screen = NSScreen.screens.first else { return }
        let bounds = screen.frame
        let target = CGPoint(
            x: clamp(home.x + delta.x, bounds.minX - window.cgRect.width * 0.25, bounds.maxX - window.cgRect.width * 0.55),
            y: clamp(home.y + delta.y, 0, bounds.height - 90))
        setPosition(element, target)
        shakes[window.id] = nil
    }

    func minimize(_ window: ScannedWindow) {
        guard let element = resolve(window) else { return }
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        forget(window.id)
    }

    /// The finisher: presses the window's own red close button, so apps still get to ask about unsaved work.
    @discardableResult
    func close(_ window: ScannedWindow) -> Bool {
        guard let element = resolve(window) else { return false }
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &button) == .success,
              let raw = button, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return false }
        let result = AXUIElementPerformAction(raw as! AXUIElement, kAXPressAction as CFString)
        forget(window.id)
        return result == .success
    }

    /// Decaying rattle, driven from the frame loop.
    func update(dt: CGFloat) {
        guard !shakes.isEmpty else { return }
        for (id, var shake) in shakes {
            shake.left -= dt
            if shake.left <= 0 {
                setPosition(shake.element, shake.home)
                shakes[id] = nil
                continue
            }
            let decay = shake.left / 0.32
            let offset = CGPoint(x: rnd(-1, 1) * shake.power * decay, y: rnd(-1, 1) * shake.power * decay * 0.6)
            setPosition(shake.element, CGPoint(x: shake.home.x + offset.x, y: shake.home.y + offset.y))
            shakes[id] = shake
        }
    }

    // MARK: - AX plumbing

    /// CGWindowID has no public bridge to AXUIElement, so match the owning app's windows by geometry.
    private func resolve(_ window: ScannedWindow) -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        if let cached = cache[window.id], let p = position(of: cached),
           abs(p.x - window.cgRect.minX) < 3, abs(p.y - window.cgRect.minY) < 3 {
            return cached
        }
        let app = AXUIElementCreateApplication(window.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        for candidate in windows {
            guard let p = position(of: candidate), let s = size(of: candidate) else { continue }
            guard abs(p.x - window.cgRect.minX) < 3, abs(p.y - window.cgRect.minY) < 3,
                  abs(s.width - window.cgRect.width) < 3, abs(s.height - window.cgRect.height) < 3 else { continue }
            cache[window.id] = candidate
            return candidate
        }
        return nil
    }

    private func position(of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func size(of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func setPosition(_ element: AXUIElement, _ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }
}
