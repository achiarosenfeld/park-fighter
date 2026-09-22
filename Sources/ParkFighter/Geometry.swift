import CoreGraphics
import Foundation

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
    static func += (a: inout CGPoint, b: CGPoint) { a = a + b }
    var length: CGFloat { hypot(x, y) }
}

func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { a + (b - a) * t }
func rnd(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo < hi ? CGFloat.random(in: lo...hi) : lo }
func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }
func smoothstep(_ t: CGFloat) -> CGFloat { let x = clamp(t, 0, 1); return x * x * (3 - 2 * x) }

/// A horizontal segment the fighter can stand on. `windowID == nil` means the ground.
struct Platform {
    var minX: CGFloat
    var maxX: CGFloat
    var y: CGFloat
    var windowID: CGWindowID?

    var width: CGFloat { maxX - minX }
    var midX: CGFloat { (minX + maxX) / 2 }
    func contains(x: CGFloat, slack: CGFloat = 0) -> Bool { x >= minX - slack && x <= maxX + slack }
    func randomX(inset: CGFloat = 24) -> CGFloat {
        width > inset * 2 ? rnd(minX + inset, maxX - inset) : midX
    }
}

/// One on-screen window. `rect` is AppKit space (y up); `cgRect` is Quartz/AX space (y down) for AX lookups.
struct ScannedWindow {
    var id: CGWindowID
    var pid: pid_t
    var owner: String
    var rect: CGRect
    var cgRect: CGRect
}
