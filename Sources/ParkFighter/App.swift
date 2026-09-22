import AppKit
import QuartzCore

/// Transparent, click-through window covering the main screen, above everything else.
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws the current frame at the display's resolution and puts it where the feet go.
final class FighterLayer {
    let root = CALayer()

    init() {
        root.anchorPoint = CGPoint(x: 0.5, y: 0)
        root.magnificationFilter = .linear
        root.minificationFilter = .linear
        root.contentsGravity = .resize
        root.allowsEdgeAntialiasing = false
    }

    func apply(_ pose: Pose, at position: CGPoint, facing: CGFloat, scale: CGFloat, screenScale: CGFloat,
               photoHead: Bool) {
        root.contents = FighterArt.render(pose, pixelScale: scale * screenScale, photoHead: photoHead)
        root.contentsScale = screenScale
        root.bounds = CGRect(x: 0, y: 0,
                             width: FighterArt.canvasWidth * scale,
                             height: FighterArt.canvasHeight * scale)
        root.position = CGPoint(x: position.x.rounded(),
                                y: position.y.rounded() - FighterArt.originY * scale)
        root.transform = CATransform3DMakeScale(facing < 0 ? -1 : 1, 1, 1)
    }
}

/// White speech balloon with a tail, sized to whatever he is shouting.
final class BubbleLayer {
    let root = CALayer()
    private let balloon = CAShapeLayer()
    private let label = CATextLayer()

    init() {
        root.anchorPoint = CGPoint(x: 0.5, y: 0)
        root.isHidden = true
        balloon.fillColor = CGColor(gray: 1, alpha: 0.97)
        balloon.strokeColor = Art.outline
        balloon.lineJoin = .round
        label.alignmentMode = .center
        label.isWrapped = false
        root.addSublayer(balloon)
        root.addSublayer(label)
    }

    func show(_ text: String, at anchor: CGPoint, scale: CGFloat, within bounds: CGRect, screenScale: CGFloat) {
        let font = NSFont.systemFont(ofSize: 13 * scale, weight: .heavy)
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
        let textSize = attributed.size()
        let padX = 10 * scale, padY = 4 * scale, tail = 8 * scale
        let width = ceil(textSize.width) + padX * 2
        let height = ceil(textSize.height) + padY * 2

        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: 0, y: tail, width: width, height: height),
                            cornerWidth: 7 * scale, cornerHeight: 7 * scale)
        path.move(to: CGPoint(x: width / 2 - 6 * scale, y: tail + 1))
        path.addLine(to: CGPoint(x: width / 2 - scale, y: 0))
        path.addLine(to: CGPoint(x: width / 2 + 6 * scale, y: tail + 1))
        path.closeSubpath()
        balloon.path = path
        balloon.lineWidth = 1.8 * scale
        balloon.frame = CGRect(x: 0, y: 0, width: width, height: height + tail)

        label.string = attributed
        label.frame = CGRect(x: 0, y: tail + height - padY - textSize.height, width: width, height: textSize.height + 1)
        label.contentsScale = screenScale

        root.bounds = CGRect(x: 0, y: 0, width: width, height: height + tail)
        root.position = CGPoint(x: clamp(anchor.x, bounds.minX + width / 2 + 4, bounds.maxX - width / 2 - 4),
                                y: anchor.y)
        root.isHidden = false
    }

    func hide() { root.isHidden = true }
}

/// A fireball in flight: its own layer, flown and burst by the engine.
final class Projectile {
    let layer = CALayer()
    var position: CGPoint
    let velocity: CGPoint
    var life: CGFloat
    var burst: CGFloat = 0
    var phase: CGFloat = 0
    let target: CGWindowID?

    init(from origin: CGPoint, velocity: CGPoint, life: CGFloat, target: CGWindowID?) {
        position = origin
        self.velocity = velocity
        self.life = life
        self.target = target
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.magnificationFilter = .linear
    }

    var finished: Bool { burst >= 1 }

    /// Returns true on the frame it bursts.
    func advance(dt: CGFloat) -> Bool {
        phase += dt
        if burst > 0 {
            burst = min(burst + dt / 0.22, 1)
            return false
        }
        position += velocity * dt
        life -= dt
        if life <= 0 {
            burst = 0.01
            return true
        }
        return false
    }

    func render(scale: CGFloat, screenScale: CGFloat) {
        layer.contents = Body.renderFireball(pixelScale: scale * screenScale, phase: phase, burst: burst)
        layer.contentsScale = screenScale
        layer.bounds = CGRect(x: 0, y: 0, width: Body.fireballWidth * scale, height: Body.fireballHeight * scale)
        layer.position = position
        layer.transform = CATransform3DMakeScale(velocity.x < 0 ? -1 : 1, 1, 1)
    }
}

/// Owns the frame loop: scans windows, updates the fighter, carries out his effects.
final class Engine {
    let window: OverlayWindow
    let fighter: Fighter
    private(set) var screen: NSScreen
    private let scanner = WindowScanner()
    private let pranks = Pranks()
    private let layer = FighterLayer()
    private let bubble = BubbleLayer()
    private let worldLayer = CALayer()
    private var timer: Timer?
    private var last = CACurrentMediaTime()
    private var frameIndex = 0
    private var scanned: [ScannedWindow] = []
    private var previousRects: [CGWindowID: CGRect] = [:]
    private var deltas: [CGWindowID: CGPoint] = [:]
    private var lastLogged: State?
    private var projectiles: [Projectile] = []
    private var lastMouse = NSEvent.mouseLocation
    private var lastMouseMove = CACurrentMediaTime()

    init(screen: NSScreen) {
        self.screen = screen
        window = OverlayWindow(screen: screen)
        let root = window.contentView!.layer!
        worldLayer.position = CGPoint(x: -screen.frame.minX, y: -screen.frame.minY)
        root.addSublayer(worldLayer)
        worldLayer.addSublayer(layer.root)
        worldLayer.addSublayer(bubble.root)
        fighter = Fighter(bounds: screen.visibleFrame)
        fighter.scale = Settings.shared.scale
    }

    func start() {
        window.orderFrontRegardless()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.002
        RunLoop.main.add(t, forMode: .common)
        timer = t
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.screenChanged() }
    }

    private func screenChanged() {
        guard let s = NSScreen.screens.first else { return }
        screen = s
        window.setFrame(s.frame, display: true)
        worldLayer.position = CGPoint(x: -s.frame.minX, y: -s.frame.minY)
    }

    func world() -> World {
        let s = Settings.shared
        var byID: [CGWindowID: ScannedWindow] = [:]
        for w in scanned { byID[w.id] = w }
        return World(bounds: screen.visibleFrame,
                     platforms: WindowScanner.platforms(windows: scanned, bounds: screen.visibleFrame),
                     ordered: scanned, windows: byID, windowDelta: deltas,
                     mayTouchWindows: s.mayTouchWindows, mayCloseWindows: s.mayCloseWindows,
                     napping: s.napping, idleSeconds: CGFloat(CACurrentMediaTime() - lastMouseMove))
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(now - last, 1.0 / 20.0))
        last = now
        frameIndex += 1

        if frameIndex % 4 == 0 || scanned.isEmpty {
            let fresh = scanner.scan(screenHeight: NSScreen.screens[0].frame.height, screenFrame: screen.frame)
            deltas = [:]
            for w in fresh {
                if let old = previousRects[w.id], old.origin != w.rect.origin {
                    deltas[w.id] = CGPoint(x: w.rect.minX - old.minX, y: w.rect.minY - old.minY)
                }
            }
            previousRects = Dictionary(uniqueKeysWithValues: fresh.map { ($0.id, $0.rect) })
            scanned = fresh
        } else {
            deltas = [:]
        }

        let mouse = NSEvent.mouseLocation
        if abs(mouse.x - lastMouse.x) + abs(mouse.y - lastMouse.y) > 2 {
            lastMouse = mouse
            lastMouseMove = now
        }

        let w = world()
        fighter.scale = Settings.shared.scale
        fighter.update(dt: dt, world: w)
        perform(fighter.effects, world: w)
        pranks.update(dt: dt)
        flyProjectiles(dt: dt, world: w)

        if Settings.shared.debugLog, fighter.state != lastLogged {
            lastLogged = fighter.state
            fputs(String(format: "state=%@ pos=(%.0f,%.0f) on=%@ windows=%d platforms=%d\n",
                         fighter.state.rawValue, fighter.pos.x, fighter.pos.y,
                         fighter.standingOn.map(String.init) ?? "ground",
                         scanned.count, w.platforms.count), stderr)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scale = Settings.shared.scale
        layer.apply(fighter.pose(), at: fighter.pos, facing: fighter.facing,
                    scale: scale, screenScale: screen.backingScaleFactor,
                    photoHead: Settings.shared.photoHead && HeadPhoto.image != nil)
        for p in projectiles { p.render(scale: scale, screenScale: screen.backingScaleFactor) }
        if let speech = fighter.speech {
            bubble.show(speech, at: CGPoint(x: fighter.pos.x, y: fighter.pos.y + 76 * scale), scale: scale,
                        within: screen.visibleFrame, screenScale: screen.backingScaleFactor)
        } else {
            bubble.hide()
        }
        CATransaction.commit()
    }

    private func flyProjectiles(dt: CGFloat, world: World) {
        for p in projectiles where p.advance(dt: dt) {
            if let id = p.target, let w = world.windows[id] {
                touch(world) { $0.shake(w, power: 11); $0.shove(w, by: CGPoint(x: p.velocity.x > 0 ? 30 : -30, y: 0)) }
            }
        }
        for p in projectiles where p.finished { p.layer.removeFromSuperlayer() }
        projectiles.removeAll(where: \.finished)
    }

    private func spawnFireball(target: CGWindowID?) {
        let scale = Settings.shared.scale
        let origin = fighter.pos + CGPoint(x: fighter.facing * 20 * scale, y: 42 * scale)
        let p = Projectile(from: origin, velocity: CGPoint(x: fighter.facing * 560 * scale, y: 0),
                           life: 0.5, target: target)
        worldLayer.insertSublayer(p.layer, below: bubble.root)
        projectiles.append(p)
    }

    /// Runs a prank against the permission gate; in safe mode it is only logged.
    private func touch(_ world: World, _ action: (Pranks) -> Void) {
        if Settings.shared.safeMode {
            if Settings.shared.debugLog { fputs("  mimed window hit\n", stderr) }
            return
        }
        guard pranks.requestPermission() else { return }
        action(pranks)
    }

    private func perform(_ effects: [Effect], world: World) {
        guard !effects.isEmpty else { return }
        for effect in effects {
            if case let .fireball(target) = effect { spawnFireball(target: target) }
        }
        let touching = effects.filter { if case .fireball = $0 { return false } else { return true } }
        guard !touching.isEmpty else { return }
        if Settings.shared.safeMode {
            if Settings.shared.debugLog {
                for e in touching { fputs("  mimed \(e)\n", stderr) }
            }
            return
        }
        guard pranks.requestPermission() else { return }
        for effect in touching {
            switch effect {
            case .fireball:
                break
            case let .rattle(id):
                if let w = world.windows[id] { pranks.shake(w, power: 7) }
            case let .shove(id, delta):
                if let w = world.windows[id] { pranks.shove(w, by: CGPoint(x: delta.x, y: -delta.y)) }
            case let .minimize(id):
                if let w = world.windows[id] { pranks.minimize(w) }
            case let .close(id):
                if let w = world.windows[id] { pranks.close(w) }
            }
        }
    }

    var accessibilityGranted: Bool { pranks.isTrusted }
}

/// Menu bar item. The overlay is click-through, so this is the only place with controls.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let engine: Engine
    private let beatUp = NSMenuItem(title: "Beat up my windows", action: #selector(toggleBeatUp), keyEquivalent: "")
    private let closing = NSMenuItem(title: "Let him close windows", action: #selector(toggleClosing), keyEquivalent: "")
    private let nap = NSMenuItem(title: "Nap time (leave me alone)", action: #selector(toggleNap), keyEquivalent: "n")
    private let photo = NSMenuItem(title: "Use his real head", action: #selector(togglePhoto), keyEquivalent: "")
    private let access = NSMenuItem(title: "Grant Accessibility access…", action: #selector(openAccessibility), keyEquivalent: "")
    private let sizes: [(String, CGFloat)] = [("Small", 1.5), ("Normal", 2.2), ("Large", 3.2), ("Huge", 4.4)]
    private var sizeItems: [NSMenuItem] = []

    init(engine: Engine) {
        self.engine = engine
        super.init()
        item.button?.title = "🥊"
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Pick a fight right now", action: #selector(fight), keyEquivalent: "f")
        menu.addItem(withTitle: "Taunt", action: #selector(taunt), keyEquivalent: "t")
        menu.addItem(withTitle: "Do something stupid", action: #selector(stupid), keyEquivalent: "s")
        menu.addItem(.separator())
        for i in [beatUp, closing, nap, photo] { menu.addItem(i) }
        let sizeMenu = NSMenu()
        for (name, value) in sizes {
            let mi = NSMenuItem(title: name, action: #selector(setSize(_:)), keyEquivalent: "")
            mi.representedObject = value
            mi.target = self
            sizeMenu.addItem(mi)
            sizeItems.append(mi)
        }
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        menu.setSubmenu(sizeMenu, for: sizeItem)
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        menu.addItem(access)
        menu.addItem(withTitle: "Quit Park Fighter", action: #selector(quit), keyEquivalent: "q")
        for mi in menu.items { mi.target = self }
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let s = Settings.shared
        beatUp.state = s.beatUpWindows ? .on : .off
        closing.state = s.closeWindows ? .on : .off
        closing.isEnabled = s.beatUpWindows
        nap.state = s.napping ? .on : .off
        photo.state = s.photoHead ? .on : .off
        photo.isHidden = HeadPhoto.image == nil
        beatUp.title = s.safeMode ? "Beat up my windows (miming, --safe)" : "Beat up my windows"
        access.isHidden = engine.accessibilityGranted
        for mi in sizeItems { mi.state = abs((mi.representedObject as? CGFloat ?? 1) - s.scale) < 0.01 ? .on : .off }
    }

    @objc private func toggleBeatUp() { Settings.shared.beatUpWindows.toggle() }
    @objc private func toggleClosing() { Settings.shared.closeWindows.toggle() }
    @objc private func toggleNap() { Settings.shared.napping.toggle() }
    @objc private func togglePhoto() { Settings.shared.photoHead.toggle() }
    @objc private func setSize(_ sender: NSMenuItem) { Settings.shared.scale = sender.representedObject as? CGFloat ?? 2.2 }
    @objc private func fight() { engine.fighter.orderAttack(engine.world()) }
    @objc private func taunt() { engine.fighter.orderTaunt() }
    @objc private func stupid() { engine.fighter.orderNonsense(engine.world()) }
    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: Engine?
    private var menu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let screen = NSScreen.screens.first else { NSApp.terminate(nil); return }
        let engine = Engine(screen: screen)
        self.engine = engine
        menu = StatusMenu(engine: engine)
        engine.start()
    }
}
