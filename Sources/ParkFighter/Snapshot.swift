import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Offscreen renders: `--snapshot` to eyeball the animation frames, `--render-icon` for the app icon.
enum Snapshot {
    private struct Cell {
        var name: String
        var image: CGImage?
        var width: CGFloat
        var height: CGFloat
    }

    static func renderSheet(to path: String) {
        let zoom: CGFloat = 3
        var cells: [Cell] = []

        func add(_ name: String, _ state: State, duration: CGFloat = 1, at frac: CGFloat = 0.5,
                 phase: CGFloat = 0, anim: CGFloat = 0, blinking: Bool = false) {
            let pose = Poses.build(state: state, t: duration * frac, duration: duration,
                                   walkPhase: phase, anim: anim, blinking: blinking)
            cells.append(Cell(name: name, image: FighterArt.render(pose, pixelScale: zoom, photoHead: HeadPhoto.image != nil),
                              width: FighterArt.canvasWidth, height: FighterArt.canvasHeight))
        }

        for (name, face) in [("calm", Face.calm), ("grin", .grin), ("shout", .shout), ("hurt", .hurt),
                             ("blink", .blink), ("sick", .sick)] {
            cells.append(Cell(name: "face \(name)", image: head(face, pixelScale: zoom * 3.0),
                              width: 32 * 3.0, height: 32 * 3.0))
        }
        for _ in 0..<2 { cells.append(Cell(name: "", image: nil, width: 1, height: 1)) }

        add("idle", .idle, anim: 0.3)
        add("idle blink", .idle, anim: 0.3, blinking: true)
        for i in 0..<8 { add("walk \(i + 1)", .walk, phase: CGFloat(i) / 8 * .pi * 2) }
        add("punch wind", .punch, duration: 0.42, at: 0.2)
        add("punch hit", .punch, duration: 0.42, at: 0.5)
        add("punch back", .punch, duration: 0.42, at: 0.85)
        add("kick wind", .kick, duration: 0.6, at: 0.15)
        add("kick out", .kick, duration: 0.6, at: 0.55)
        add("stomp up", .stomp, duration: 0.6, at: 0.35)
        add("stomp down", .stomp, duration: 0.6, at: 0.8)
        add("taunt a", .taunt, duration: 0.9, at: 0.25)
        add("taunt b", .taunt, duration: 0.9, at: 0.42)
        add("jump", .jump)
        add("fall", .fall)
        add("land", .land, duration: 0.2, at: 0.15)
        add("victory", .victory, duration: 1.4, at: 0.5, anim: 0.2)
        add("hurt", .hurt, duration: 0.55, at: 0.5)
        add("dance a", .dance, duration: 2, at: 0.1)
        add("dance b", .dance, duration: 2, at: 0.3)
        add("stretch", .stretch, duration: 1.2, at: 0.5)
        add("sit", .sit, anim: 0.4)
        add("chair a", .chair, anim: 0.2)
        add("chair b", .chair, anim: 0.75)
        add("yell", .yell, duration: 1.8, at: 0.5, anim: 0.3)
        add("vomit a", .vomit, duration: 2.6, at: 0.3, anim: 0.4)
        add("vomit b", .vomit, duration: 2.6, at: 0.6, anim: 0.5)
        add("vomit c", .vomit, duration: 2.6, at: 0.95, anim: 0.6)
        add("pushup down", .pushup, anim: 0.0)
        add("pushup up", .pushup, anim: 0.63)
        add("coffee", .coffee, duration: 3.4, at: 0.1, anim: 0.5)
        add("coffee sip", .coffee, duration: 3.4, at: 0.5, anim: 0.9)
        add("phone", .phone, anim: 0.4)
        add("hadouken a", .hadouken, duration: 1.15, at: 0.3)
        add("hadouken b", .hadouken, duration: 1.15, at: 0.5)
        add("sleep", .sleep, anim: 0.4)
        cells.append(Cell(name: "fireball", image: Body.renderFireball(pixelScale: zoom * 1.6, phase: 0.3, burst: 0),
                          width: Body.fireballWidth * 1.6, height: Body.fireballHeight * 1.6))
        cells.append(Cell(name: "fireball burst", image: Body.renderFireball(pixelScale: zoom * 1.6, phase: 0.3, burst: 0.4),
                          width: Body.fireballWidth * 1.6, height: Body.fireballHeight * 1.6))
        cells.append(Cell(name: "speech", image: bubble("אני סתום", pixelScale: zoom),
                          width: FighterArt.canvasWidth, height: FighterArt.canvasHeight))

        let cols = 8
        let cellW = Int(FighterArt.canvasWidth * zoom) + 16
        let cellH = Int(FighterArt.canvasHeight * zoom) + 26
        let rows = (cells.count + cols - 1) / cols
        let width = cols * cellW
        let height = rows * cellH
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(red: 0.45, green: 0.47, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.black,
        ]

        for (i, cell) in cells.enumerated() {
            guard let image = cell.image else { continue }
            let col = i % cols, row = i / cols
            let originX = CGFloat(col * cellW)
            let originY = CGFloat(height - (row + 1) * cellH)
            let drawn = CGRect(x: originX + (CGFloat(cellW) - cell.width * zoom) / 2, y: originY + 20,
                               width: cell.width * zoom, height: cell.height * zoom)
            ctx.draw(image, in: drawn)
            (cell.name as NSString).draw(at: NSPoint(x: originX + 8, y: originY + 4), withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let out = ctx.makeImage() else { return }
        write(out, to: path)
    }

    /// Just the faces, big, for judging the likeness.
    static func renderFaces(to path: String) {
        let zoom: CGFloat = 9
        let side: CGFloat = 32
        let faces: [(String, Face)] = [("calm", .calm), ("grin", .grin), ("shout", .shout),
                                       ("hurt", .hurt), ("blink", .blink), ("sick", .sick)]
        let cell: CGFloat = side * zoom
        let cols = 3
        let rows: Int = (faces.count + cols - 1) / cols
        let width: CGFloat = CGFloat(cols) * cell
        let height: CGFloat = CGFloat(rows) * cell
        guard let ctx = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(red: 0.45, green: 0.47, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (i, entry) in faces.enumerated() {
            guard let image = head(entry.1, pixelScale: zoom) else { continue }
            let col: CGFloat = CGFloat(i % cols)
            let row: CGFloat = CGFloat(rows - (i / cols) - 1)
            ctx.draw(image, in: CGRect(x: col * cell, y: row * cell, width: cell, height: cell))
        }
        guard let out = ctx.makeImage() else { return }
        write(out, to: path)
    }

    /// The speech balloon as the overlay builds it, to check the text renders.
    private static func bubble(_ text: String, pixelScale: CGFloat) -> CGImage? {
        let balloon = BubbleLayer()
        balloon.show(text, at: .zero, scale: 2,
                     within: CGRect(x: -400, y: -400, width: 800, height: 800), screenScale: pixelScale)
        let size = balloon.root.bounds.size
        guard size.width > 1, let ctx = CGContext(data: nil, width: Int(size.width * pixelScale),
                                                  height: Int(size.height * pixelScale), bitsPerComponent: 8,
                                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.scaleBy(x: pixelScale, y: pixelScale)
        balloon.root.render(in: ctx)
        return ctx.makeImage()
    }

    /// The head on its own, blown up, for judging the face.
    private static func head(_ face: Face, pixelScale: CGFloat) -> CGImage? {
        let side = 32
        guard let ctx = CGContext(data: nil, width: Int(CGFloat(side) * pixelScale), height: Int(CGFloat(side) * pixelScale),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: pixelScale, y: pixelScale)
        ctx.translateBy(x: 13, y: 5)
        Body.neck(ctx, at: .zero)
        Head.draw(ctx, at: .zero, face: face)
        return ctx.makeImage()
    }

    /// App icon: mid-punch on a sky-blue tile.
    static func renderIcon(to path: String, size: Int) {
        let s = CGFloat(size)
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        let inset = s * 0.06
        ctx.addPath(CGPath(roundedRect: CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2),
                           cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil))
        ctx.setFillColor(CGColor(red: 0.42, green: 0.72, blue: 0.86, alpha: 1))
        ctx.fillPath()

        let pose = Poses.build(state: .punch, t: 0.21, duration: 0.42, walkPhase: 0, anim: 0, blinking: false)
        let pixelScale = s * 0.95 / FighterArt.canvasHeight
        guard let image = FighterArt.render(pose, pixelScale: pixelScale, photoHead: HeadPhoto.image != nil) else { return }
        let w = FighterArt.canvasWidth * pixelScale
        let h = FighterArt.canvasHeight * pixelScale
        ctx.draw(image, in: CGRect(x: (s - w) / 2, y: s * 0.02, width: w, height: h))
        guard let out = ctx.makeImage() else { return }
        write(out, to: path)
    }

    static func dumpWindows() {
        guard let screen = NSScreen.screens.first else { return }
        let windows = WindowScanner().scan(screenHeight: screen.frame.height, screenFrame: screen.frame)
        print("bounds:", screen.visibleFrame)
        for w in windows { print("window", w.id, w.owner, w.rect) }
        for p in WindowScanner.platforms(windows: windows, bounds: screen.visibleFrame) {
            print("platform y=\(Int(p.y)) x=\(Int(p.minX))...\(Int(p.maxX)) window=\(p.windowID.map(String.init) ?? "ground")")
        }
    }

    private static func write(_ image: CGImage, to path: String) {
        guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                         UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
