import CoreGraphics
import Foundation

/// Everything the fighter can ask the app to do to somebody else's window.
enum Effect {
    case rattle(CGWindowID)
    case shove(CGWindowID, CGPoint)
    case minimize(CGWindowID)
    case close(CGWindowID)
    /// Launched from his hands; the app flies it and rattles the target when it bursts.
    case fireball(CGWindowID?)
}

struct World {
    var bounds: CGRect
    var platforms: [Platform]
    /// Front to back, so the first hit is the window you can actually see.
    var ordered: [ScannedWindow]
    var windows: [CGWindowID: ScannedWindow]
    var windowDelta: [CGWindowID: CGPoint]
    var mayTouchWindows: Bool
    var mayCloseWindows: Bool
    var napping: Bool
    /// Seconds since the mouse last moved.
    var idleSeconds: CGFloat

    /// The window whose face the fighter is standing in front of.
    func window(facing point: CGPoint) -> ScannedWindow? {
        ordered.first { $0.rect.contains(point) }
    }
}

/// One step of a beatdown: a pose to strike, and the thing that happens to the window mid-swing.
private struct Move {
    var state: State
    var duration: CGFloat
    var impact: Impact?
    var impactAt: CGFloat = 0.4
}

private enum Impact { case rattle, shove, minimize, close, fireball }

/// Walks around, stands on your windows, and eventually picks a fight with one.
final class Fighter {
    var pos: CGPoint
    var vel: CGPoint = .zero
    var facing: CGFloat = 1
    var scale: CGFloat = 2
    private(set) var state: State = .idle
    private(set) var effects: [Effect] = []
    /// Set while he is yelling, so the app can put it in a speech bubble.
    private(set) var speech: String?

    private var t: CGFloat = 0
    private var duration: CGFloat = 1
    private var walkPhase: CGFloat = 0
    private var anim: CGFloat = 0
    private var platform: Platform?
    private var goalX: CGFloat = 0
    private var plan: [Move] = []
    private var target: CGWindowID?
    private var impact: Impact?
    private var impactAt: CGFloat = 0
    private var sparks: [(pos: CGPoint, life: CGFloat)] = []
    private var blinkUntil: CGFloat = 0
    private var nextBlink: CGFloat = 3
    private var nextFightAt: CGFloat = 6

    private static let phrases = ["אני סתום", "אני סתום", "יאללה!", "מה קורה?!", "שוב באגים?!", "איפה הקפה?", "אני צריך הפסקה"]

    private var gravity: CGFloat { 820 * scale }
    private var walkSpeed: CGFloat { 52 * scale }

    init(bounds: CGRect) {
        pos = CGPoint(x: bounds.midX, y: bounds.minY)
        platform = Platform(minX: bounds.minX, maxX: bounds.maxX, y: bounds.minY, windowID: nil)
    }

    var standingOn: CGWindowID? { platform?.windowID }

    func pose() -> Pose {
        var p = Poses.build(state: state, t: t, duration: duration, walkPhase: walkPhase,
                            anim: anim, blinking: anim < blinkUntil)
        p.sparks = sparks.map(\.pos)
        p.sparkSize = 3 + (sparks.first.map { $0.life * 14 } ?? 0)
        return p
    }

    // MARK: - Frame

    func update(dt: CGFloat, world: World) {
        effects.removeAll()
        anim += dt
        t += dt
        if anim > nextBlink {
            blinkUntil = anim + 0.13
            nextBlink = anim + rnd(2.5, 7)
        }
        for i in sparks.indices { sparks[i].life -= dt }
        sparks.removeAll { $0.life <= 0 }

        follow(world)
        if state == .sleep, world.idleSeconds < 0.5 {
            begin(.hurt, 0.7)
            speech = "מה?! לא ישנתי"
        }
        if let pending = impact, t >= impactAt {
            fire(pending, world: world)
            impact = nil
        }

        switch state {
        case .walk: stepWalk(dt: dt, world: world)
        case .chair: stepChair(dt: dt, world: world)
        case .jump, .fall: stepAirborne(dt: dt, world: world)
        default:
            if t >= duration { think(world) }
        }
        pos.x = clamp(pos.x, world.bounds.minX + 4, world.bounds.maxX - 4)
    }

    /// Stay on the window he is standing on, even while you drag it around.
    private func follow(_ world: World) {
        guard state != .jump, state != .fall else { return }
        guard let current = platform else { return }
        guard let id = current.windowID else {
            platform = world.platforms.first { $0.windowID == nil } ?? current
            pos.y = platform?.y ?? pos.y
            return
        }
        let delta = world.windowDelta[id] ?? .zero
        if delta != .zero { pos.x += delta.x }
        guard let updated = world.platforms.first(where: { $0.windowID == id && $0.contains(x: pos.x, slack: 10) }) else {
            platform = nil
            begin(.fall, 4)
            vel = CGPoint(x: facing * 18 * scale, y: 0)
            plan.removeAll()
            return
        }
        platform = updated
        pos.y = updated.y
        if delta.length > 26 * scale, state != .hurt, state != .victory {
            plan.removeAll()
            begin(.hurt, 0.55)
        }
    }

    private func stepWalk(dt: CGFloat, world: World) {
        guard let p = platform else { begin(.fall, 4); return }
        let speed = walkSpeed
        pos.x += facing * speed * dt
        walkPhase += dt * .pi * 2
        let margin: CGFloat = 12 * scale
        let offFront = facing > 0 ? pos.x > p.maxX - margin : pos.x < p.minX + margin
        if offFront {
            if p.windowID != nil, chance(0.3) {
                pos.x += facing * margin * 0.6
                platform = nil
                begin(.fall, 4)
                vel = CGPoint(x: facing * 30 * scale, y: 0)
                return
            }
            pos.x = clamp(pos.x, p.minX + margin, p.maxX - margin)
            facing = -facing
            think(world)
            return
        }
        if abs(pos.x - goalX) < speed * dt * 1.5 || t > duration { think(world) }
    }

    /// Rolling across the platform, slowing down, bouncing off the ends.
    private func stepChair(dt: CGFloat, world: World) {
        guard let p = platform else { begin(.fall, 4); return }
        pos.x += vel.x * dt
        vel.x *= pow(0.55, dt)
        let margin = 18 * scale
        if pos.x < p.minX + margin {
            pos.x = p.minX + margin
            vel.x = abs(vel.x) * 0.55
            facing = 1
        } else if pos.x > p.maxX - margin {
            pos.x = p.maxX - margin
            vel.x = -abs(vel.x) * 0.55
            facing = -1
        }
        if t >= duration {
            vel = .zero
            think(world)
        }
    }

    private func stepAirborne(dt: CGFloat, world: World) {
        let previous = pos
        vel.y -= gravity * dt
        pos += vel * dt
        state = vel.y > 0 ? .jump : .fall
        guard vel.y <= 0 else { return }
        var best: Platform?
        for p in world.platforms where p.contains(x: pos.x, slack: 2) {
            guard previous.y >= p.y - 1, pos.y <= p.y else { continue }
            if best == nil || p.y > best!.y { best = p }
        }
        if let landed = best {
            platform = landed
            pos.y = landed.y
            vel = .zero
            begin(.land, 0.2)
        } else if pos.y < world.bounds.minY {
            let ground = world.platforms.first { $0.windowID == nil }
            platform = ground
            pos.y = ground?.y ?? world.bounds.minY
            vel = .zero
            begin(.land, 0.2)
        }
    }

    // MARK: - Brain

    private func begin(_ next: State, _ seconds: CGFloat) {
        state = next
        t = 0
        duration = seconds
        impact = nil
        switch next {
        case .yell: speech = Fighter.phrases.randomElement()
        case .hadouken: speech = "הדוקן!"
        case .sleep: speech = "zZz…"
        default: speech = nil
        }
        if next != .walk { walkPhase = 0 }
    }

    private func think(_ world: World) {
        if !plan.isEmpty {
            let move = plan.removeFirst()
            begin(move.state, move.duration)
            impact = move.impact
            impactAt = move.duration * move.impactAt
            return
        }
        target = nil
        if world.napping { begin(.sit, rnd(4, 8)); return }
        if world.idleSeconds > 120, chance(0.7) { begin(.sleep, 3600); return }

        if world.mayTouchWindows, anim > nextFightAt, chance(0.4), let id = pickAFight(world) {
            startBeatdown(on: id, world: world)
            return
        }
        switch Double.random(in: 0..<1) {
        case ..<0.24: startWalk(world)
        case ..<0.36: leap(world)
        case ..<0.42: begin(.taunt, 0.95)
        case ..<0.48: begin(.dance, rnd(1.6, 2.6))
        case ..<0.53: begin(.stretch, 1.2)
        case ..<0.59: shadowBox()
        case ..<0.63: begin(.kick, 0.6)
        case ..<0.68: rollAround(world)
        case ..<0.73: begin(.yell, 1.8)
        case ..<0.76: begin(.vomit, rnd(2.4, 3.2))
        case ..<0.81: begin(.pushup, rnd(3, 5))
        case ..<0.86: begin(.coffee, 3.4)
        case ..<0.90: begin(.phone, rnd(4, 7))
        case ..<0.94: throwFireball()
        case ..<0.97: begin(.sit, rnd(2.5, 5))
        default: begin(.idle, rnd(0.7, 1.8))
        }
    }

    /// Whatever he is standing on, or failing that whatever he is standing in front of.
    private func pickAFight(_ world: World) -> CGWindowID? {
        if let id = platform?.windowID, world.windows[id] != nil { return id }
        let chest = CGPoint(x: pos.x + facing * 6 * scale, y: pos.y + 30 * scale)
        return world.window(facing: chest)?.id
    }

    private func startWalk(_ world: World) {
        let p = platform ?? world.platforms[0]
        goalX = p.randomX(inset: 16 * scale)
        facing = goalX >= pos.x ? 1 : -1
        begin(.walk, clamp(abs(goalX - pos.x) / walkSpeed, 0.4, 6))
    }

    /// Needs room to roll, so he only wheels the chair out on a wide platform.
    private func rollAround(_ world: World) {
        guard let p = platform, p.width > 260 * scale else { startWalk(world); return }
        facing = pos.x < p.midX ? 1 : -1
        vel = CGPoint(x: facing * rnd(150, 230) * scale, y: 0)
        begin(.chair, rnd(3.5, 6))
    }

    private func throwFireball() {
        begin(.hadouken, 1.15)
        impact = .fireball
        impactAt = 0.5
    }

    private func shadowBox() {
        plan = [Move(state: .punch, duration: 0.42, impact: nil),
                Move(state: .punch, duration: 0.42, impact: nil)]
        begin(.punch, 0.42)
    }

    /// Jump to another window top (or the floor) if there is one within reach.
    private func leap(_ world: World) {
        let reach = 380 * scale
        let candidates = world.platforms.filter { p in
            guard p.y != platform?.y || p.windowID != platform?.windowID else { return false }
            guard p.width > 40 * scale else { return false }
            let x = clamp(pos.x, p.minX + 20, p.maxX - 20)
            return abs(x - pos.x) < reach && p.y < pos.y + 150 * scale && p.y > pos.y - 500 * scale
        }
        guard let destination = candidates.randomElement() else { startWalk(world); return }
        let targetX = destination.randomX(inset: 24 * scale)
        let dx = targetX - pos.x
        let dy = destination.y - pos.y
        let apex = max(dy, 0) + 48 * scale
        let vy = sqrt(2 * gravity * apex)
        let timeUp = vy / gravity
        let timeDown = sqrt(2 * max(apex - dy, 1) / gravity)
        vel = CGPoint(x: dx / max(timeUp + timeDown, 0.15), y: vy)
        facing = dx >= 0 ? 1 : -1
        platform = nil
        begin(.jump, 4)
    }

    /// Taunt, work the window over, and sometimes finish it off.
    private func startBeatdown(on id: CGWindowID, world: World) {
        target = id
        nextFightAt = anim + rnd(14, 34)
        var moves: [Move] = chance(0.4)
            ? [Move(state: .hadouken, duration: 1.15, impact: .fireball, impactAt: 0.44)]
            : [Move(state: .taunt, duration: 0.85, impact: nil)]
        moves.append(Move(state: .punch, duration: 0.42, impact: .rattle, impactAt: 0.42))
        if chance(0.6) { moves.append(Move(state: .punch, duration: 0.40, impact: .rattle, impactAt: 0.42)) }
        if chance(0.7) { moves.append(Move(state: .kick, duration: 0.62, impact: .shove, impactAt: 0.46)) }

        if world.mayCloseWindows, chance(0.3) {
            moves.append(Move(state: .stomp, duration: 0.62, impact: .close, impactAt: 0.58))
            moves.append(Move(state: .victory, duration: 1.5, impact: nil))
        } else if world.mayCloseWindows, chance(0.4) {
            moves.append(Move(state: .stomp, duration: 0.62, impact: .minimize, impactAt: 0.58))
            moves.append(Move(state: .victory, duration: 1.3, impact: nil))
        } else {
            moves.append(Move(state: .stomp, duration: 0.6, impact: .rattle, impactAt: 0.58))
        }
        plan = moves
        think(world)
    }

    private func fire(_ impact: Impact, world: World) {
        if case .fireball = impact {
            effects.append(.fireball(target.flatMap { world.windows[$0] != nil ? $0 : nil }))
            return
        }
        guard let id = target, world.windows[id] != nil else { return }
        switch impact {
        case .rattle:
            effects.append(.rattle(id))
            spark(at: state == .kick ? CGPoint(x: 24, y: 22) : CGPoint(x: 21, y: 39))
        case .shove:
            effects.append(.shove(id, CGPoint(x: facing * 44 * scale, y: 0)))
            spark(at: CGPoint(x: 24, y: 24))
        case .minimize:
            effects.append(.minimize(id))
            spark(at: CGPoint(x: 6, y: 2))
        case .close:
            effects.append(.close(id))
            spark(at: CGPoint(x: 6, y: 2))
        case .fireball:
            break
        }
    }

    private func spark(at p: CGPoint) {
        sparks = [(pos: p, life: 0.16)]
    }

    // MARK: - Menu pokes

    func orderTaunt() {
        plan.removeAll()
        begin(.taunt, 1.0)
    }

    /// The chair, the yelling or the being sick, whichever the dice pick.
    func orderNonsense(_ world: World) {
        plan.removeAll()
        switch Int.random(in: 0..<7) {
        case 0: rollAround(world)
        case 1: begin(.yell, 1.8)
        case 2: begin(.vomit, rnd(2.4, 3.2))
        case 3: begin(.pushup, rnd(3, 5))
        case 4: begin(.coffee, 3.4)
        case 5: begin(.phone, rnd(4, 7))
        default: throwFireball()
        }
    }

    func orderAttack(_ world: World) {
        plan.removeAll()
        nextFightAt = 0
        guard let id = pickAFight(world) else {
            shadowBox()
            return
        }
        startBeatdown(on: id, world: world)
    }
}
