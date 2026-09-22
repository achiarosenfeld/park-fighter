import AppKit

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
    Snapshot.renderSheet(to: args[i + 1])
    exit(0)
}
if let i = args.firstIndex(of: "--render-icon"), i + 2 < args.count, let size = Int(args[i + 2]) {
    Snapshot.renderIcon(to: args[i + 1], size: size)
    exit(0)
}
if args.contains("--bench") {
    let pose = Poses.build(state: .walk, t: 0, duration: 1, walkPhase: 1, anim: 1, blinking: false)
    let start = Date()
    for _ in 0..<300 { _ = FighterArt.render(pose, pixelScale: 3, photoHead: HeadPhoto.image != nil) }
    print(String(format: "300 frames at 3px/unit: %.1f ms total, %.2f ms per frame",
                 Date().timeIntervalSince(start) * 1000, Date().timeIntervalSince(start) * 1000 / 300))
    exit(0)
}
if let i = args.firstIndex(of: "--cut-head"), i + 2 < args.count {
    do {
        let index = i + 3 < args.count ? Int(args[i + 3]) : nil
        try HeadPhoto.cutOut(photo: URL(fileURLWithPath: args[i + 1]), to: URL(fileURLWithPath: args[i + 2]),
                             faceIndex: index)
        print("wrote \(args[i + 2])")
    } catch {
        fputs("cut-head failed: \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}
if let i = args.firstIndex(of: "--faces"), i + 1 < args.count {
    Snapshot.renderFaces(to: args[i + 1])
    exit(0)
}
if args.contains("--dump-windows") {
    Snapshot.dumpWindows()
    exit(0)
}
if args.contains("--safe") { Settings.shared.safeMode = true }
if args.contains("--log") { Settings.shared.debugLog = true }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
