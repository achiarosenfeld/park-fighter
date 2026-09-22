import AppKit
import CoreGraphics

/// Finds on-screen windows and turns their top edges into platforms the fighter can stand on.
final class WindowScanner {
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func scan(screenHeight: CGFloat, screenFrame: CGRect) -> [ScannedWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        var result: [ScannedWindow] = []
        result.reserveCapacity(list.count)
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID else { continue }
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha < 0.05 { continue }
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"] else { continue }
            guard w >= 140, h >= 80 else { continue }
            let rect = CGRect(x: x, y: screenHeight - (y + h), width: w, height: h)
            guard rect.intersects(screenFrame) else { continue }
            let owner = info[kCGWindowOwnerName as String] as? String ?? "?"
            result.append(ScannedWindow(id: id, pid: pid, owner: owner, rect: rect,
                                        cgRect: CGRect(x: x, y: y, width: w, height: h)))
        }
        return result
    }

    /// Visible top-edge segments (front windows occlude the ones behind them), plus the ground.
    static func platforms(windows: [ScannedWindow], bounds: CGRect) -> [Platform] {
        var platforms: [Platform] = [Platform(minX: bounds.minX, maxX: bounds.maxX, y: bounds.minY, windowID: nil)]
        for (i, w) in windows.enumerated() {
            let y = w.rect.maxY
            guard y > bounds.minY + 20, y < bounds.maxY - 30 else { continue }
            var intervals: [(CGFloat, CGFloat)] = [(max(w.rect.minX, bounds.minX), min(w.rect.maxX, bounds.maxX))]
            for front in windows[..<i] {
                let f = front.rect
                guard f.minY < y - 0.5, f.maxY > y + 0.5 else { continue }
                intervals = subtract(intervals, (f.minX, f.maxX))
                if intervals.isEmpty { break }
            }
            for (a, b) in intervals where b - a >= 90 {
                platforms.append(Platform(minX: a, maxX: b, y: y, windowID: w.id))
            }
        }
        return platforms
    }

    private static func subtract(_ intervals: [(CGFloat, CGFloat)], _ cut: (CGFloat, CGFloat)) -> [(CGFloat, CGFloat)] {
        var out: [(CGFloat, CGFloat)] = []
        for (a, b) in intervals {
            if cut.1 <= a || cut.0 >= b { out.append((a, b)); continue }
            if cut.0 > a { out.append((a, cut.0)) }
            if cut.1 < b { out.append((cut.1, b)) }
        }
        return out
    }
}
