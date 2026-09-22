import CoreGraphics
import Foundation

enum Face { case calm, grin, shout, hurt, blink, sick }

/// What the fighter is doing. Each case has one pose function and one duration.
enum State: String, CaseIterable {
    case idle, walk, jump, fall, land, punch, kick, stomp, taunt, victory, hurt, dance, stretch, sit
    case chair, vomit, yell
    case pushup, coffee, phone, hadouken, sleep
}

enum Prop { case none, mug, phone }

/// A skeleton in character space: origin between the feet, y up, facing right.
/// `frontFoot` / `backFoot` are ankle points; the shoe is drawn below and forward of them.
struct Pose {
    var hip = CGPoint(x: 0, y: 26)
    var shoulder = CGPoint(x: 1, y: 43)
    var neck = CGPoint(x: 2, y: 45)
    var frontElbow = CGPoint(x: 6.8, y: 36)
    var frontHand = CGPoint(x: 10.4, y: 28.5)
    var backElbow = CGPoint(x: -6.8, y: 36)
    var backHand = CGPoint(x: -10.4, y: 28.5)
    var frontKnee = CGPoint(x: 6, y: 15)
    var frontFoot = CGPoint(x: 8, y: 4)
    var backKnee = CGPoint(x: -7, y: 15)
    var backFoot = CGPoint(x: -10, y: 4)
    var face: Face = .calm
    /// Radians, clockwise-negative, applied around the neck.
    var headTilt: CGFloat = 0
    /// 0…1 while he is being sick; drives the stream and the puddle.
    var vomit: CGFloat = 0
    var onChair = false
    var chairWobble: CGFloat = 0
    var prop: Prop = .none
    /// Free-running time for whatever the prop is doing (steam, screen glow).
    var propPhase: CGFloat = 0
    var sparks: [CGPoint] = []
    var sparkSize: CGFloat = 4

    /// Moves everything above the waist, for leaning and bobbing.
    mutating func liftUpperBody(_ d: CGPoint) {
        hip += d; shoulder += d; neck += d
        frontElbow += d; frontHand += d; backElbow += d; backHand += d
        frontKnee += CGPoint(x: d.x * 0.3, y: d.y * 0.5)
        backKnee += CGPoint(x: d.x * 0.3, y: d.y * 0.5)
    }
}

enum Poses {
    private static let twoPi = CGFloat.pi * 2

    static func build(state: State, t: CGFloat, duration: CGFloat, walkPhase: CGFloat,
                      anim: CGFloat, blinking: Bool) -> Pose {
        let u = duration > 0 ? clamp(t / duration, 0, 1) : 0
        var p: Pose
        switch state {
        case .idle: p = idle(anim)
        case .walk: p = walk(walkPhase)
        case .jump: p = airborne(rising: true)
        case .fall: p = airborne(rising: false)
        case .land: p = land(u)
        case .punch: p = punch(u)
        case .kick: p = kick(u)
        case .stomp: p = stomp(u)
        case .taunt: p = taunt(u)
        case .victory: p = victory(u, anim: anim)
        case .hurt: p = hurt(u)
        case .dance: p = dance(t)
        case .stretch: p = stretch(u)
        case .sit: p = sit(anim)
        case .chair: p = chair(anim)
        case .vomit: p = vomit(u, anim: anim)
        case .yell: p = yell(u, anim: anim)
        case .pushup: p = pushup(anim)
        case .coffee: p = coffee(u, anim: anim)
        case .phone: p = phone(anim)
        case .hadouken: p = hadouken(u)
        case .sleep: p = sleep(anim)
        }
        // The stance constants above are drawn short-legged; standing poses get the hips lifted
        // so the leg-to-body ratio matches the reference sheet.
        let grounded: Set<State> = [.sit, .chair, .pushup, .phone, .sleep]
        if !grounded.contains(state) { p.liftUpperBody(CGPoint(x: 0, y: 5)) }
        if blinking, p.face == .calm { p.face = .blink }
        return p
    }

    /// Fighting stance with a slow breath.
    private static func idle(_ anim: CGFloat) -> Pose {
        var p = Pose()
        let breath = (sin(anim * 2.6) * 1.2).rounded()
        let sway = (sin(anim * 1.3) * 1.0).rounded()
        p.liftUpperBody(CGPoint(x: sway, y: breath))
        p.frontHand += CGPoint(x: sway, y: breath)
        p.backHand += CGPoint(x: sway, y: breath)
        return p
    }

    /// Eight-frame walk: the swing leg arcs forward through the air, the stance leg slides back on the ground.
    private static func walk(_ phase: CGFloat) -> Pose {
        var p = Pose()
        let step = (phase / twoPi * 8).rounded(.down) / 8 * twoPi
        let q = step.truncatingRemainder(dividingBy: twoPi)
        let front = swing(q)
        let back = swing(q + .pi)
        p.frontFoot = front
        p.backFoot = back
        p.frontKnee = knee(hip: p.hip, ankle: front, forward: 3)
        p.backKnee = knee(hip: p.hip, ankle: back, forward: 2)
        let bob = (-1.6 * abs(sin(q)) + 0.8).rounded()
        p.liftUpperBody(CGPoint(x: 0, y: bob))
        // The arms swing along the body, never across it, so they stay clear of the tee.
        p.frontHand = CGPoint(x: p.shoulder.x + 8.4 - 4 * sin(q), y: 29 + bob + 1.5 * sin(q))
        p.backHand = CGPoint(x: p.shoulder.x - 9.4 + 4 * sin(q), y: 29 + bob - 1.5 * sin(q))
        p.frontElbow = CGPoint(x: p.shoulder.x + 5.6 - 2 * sin(q), y: 36.5 + bob)
        p.backElbow = CGPoint(x: p.shoulder.x - 6.6 + 2 * sin(q), y: 36.5 + bob)
        return p
    }

    private static func swing(_ raw: CGFloat) -> CGPoint {
        var q = raw.truncatingRemainder(dividingBy: twoPi)
        if q < 0 { q += twoPi }
        if q < .pi {
            let s = q / .pi
            return CGPoint(x: -10 + 20 * s, y: 4 + 7 * sin(.pi * s))
        }
        let s = (q - .pi) / .pi
        return CGPoint(x: 10 - 20 * s, y: 4)
    }

    private static func knee(hip: CGPoint, ankle: CGPoint, forward: CGFloat) -> CGPoint {
        lerp(hip, ankle, 0.52) + CGPoint(x: forward, y: 1)
    }

    private static func airborne(rising: Bool) -> Pose {
        var p = Pose()
        p.frontFoot = CGPoint(x: rising ? 8 : 9, y: rising ? 12 : 6)
        p.backFoot = CGPoint(x: -7, y: rising ? 14 : 5)
        p.frontKnee = CGPoint(x: 7, y: rising ? 20 : 16)
        p.backKnee = CGPoint(x: -5, y: rising ? 21 : 16)
        p.frontHand = CGPoint(x: rising ? 11 : 12, y: rising ? 50 : 44)
        p.backHand = CGPoint(x: rising ? -8 : -10, y: rising ? 49 : 42)
        p.frontElbow = CGPoint(x: 9, y: 41)
        p.backElbow = CGPoint(x: -8, y: 40)
        p.face = rising ? .shout : .hurt
        return p
    }

    private static func land(_ u: CGFloat) -> Pose {
        var p = Pose()
        let squash = (1 - smoothstep(u)) * 7
        p.liftUpperBody(CGPoint(x: 0, y: -squash))
        p.frontFoot = CGPoint(x: 8, y: 4)
        p.backFoot = CGPoint(x: -8, y: 4)
        p.frontKnee = CGPoint(x: 8, y: 13 - squash * 0.4)
        p.backKnee = CGPoint(x: -8, y: 13 - squash * 0.4)
        p.frontHand = CGPoint(x: 11, y: 30 - squash)
        p.backHand = CGPoint(x: -11, y: 29 - squash)
        return p
    }

    /// -0.35 is the wind-up, 1 is full extension.
    private static func strikeCurve(_ u: CGFloat, windup: CGFloat, strike: CGFloat, hold: CGFloat) -> CGFloat {
        if u < windup { return -0.35 * smoothstep(u / windup) }
        if u < strike { return lerp(-0.35, 1, smoothstep((u - windup) / (strike - windup))) }
        if u < hold { return 1 }
        return 1 - smoothstep((u - hold) / max(1 - hold, 0.001))
    }

    private static func punch(_ u: CGFloat) -> Pose {
        var p = Pose()
        let e = strikeCurve(u, windup: 0.26, strike: 0.44, hold: 0.62)
        p.liftUpperBody(CGPoint(x: e * 2, y: -abs(e) * 1.5))
        p.frontHand = CGPoint(x: -3 + 24 * e, y: 40 - e)
        p.frontElbow = lerp(p.shoulder, p.frontHand, 0.5) + CGPoint(x: e * 2, y: -3)
        p.backHand = CGPoint(x: -10 - 2 * e, y: 42)
        p.backElbow = CGPoint(x: -11, y: 35)
        p.frontFoot = CGPoint(x: 8 + 2 * e, y: 4)
        p.backFoot = CGPoint(x: -9 - 2 * e, y: 4)
        p.frontKnee = CGPoint(x: 8, y: 14)
        p.backKnee = CGPoint(x: -7, y: 15)
        p.face = e > 0.6 ? .shout : .grin
        return p
    }

    private static func kick(_ u: CGFloat) -> Pose {
        var p = Pose()
        let e = strikeCurve(u, windup: 0.22, strike: 0.46, hold: 0.66)
        p.liftUpperBody(CGPoint(x: -4 * max(e, 0), y: -2 * abs(e)))
        p.frontFoot = CGPoint(x: 6 + 17 * e, y: 4 + 20 * max(e, 0))
        p.frontKnee = lerp(p.hip, p.frontFoot, 0.5) + CGPoint(x: 2, y: e > 0.2 ? 0 : 1)
        p.backFoot = CGPoint(x: -6, y: 4)
        p.backKnee = CGPoint(x: -6, y: 15)
        p.frontHand = CGPoint(x: 9, y: 40)
        p.frontElbow = CGPoint(x: 9, y: 33)
        p.backHand = CGPoint(x: -12 - 4 * max(e, 0), y: 36)
        p.backElbow = CGPoint(x: -11, y: 39)
        p.face = e > 0.6 ? .shout : .grin
        return p
    }

    private static func stomp(_ u: CGFloat) -> Pose {
        var p = Pose()
        let hop = sin(.pi * clamp(u / 0.55, 0, 1)) * 9
        let land = u > 0.55 ? smoothstep((u - 0.55) / 0.45) * 5 : 0
        p.liftUpperBody(CGPoint(x: 0, y: hop - land))
        p.frontFoot = CGPoint(x: 7, y: 4 + hop * 0.9)
        p.backFoot = CGPoint(x: -8, y: 4 + hop * 0.9)
        p.frontKnee = CGPoint(x: 8, y: 14 + hop * 0.5)
        p.backKnee = CGPoint(x: -8, y: 14 + hop * 0.5)
        p.frontHand = CGPoint(x: 8, y: 44 + hop - land * 2)
        p.backHand = CGPoint(x: -6, y: 45 + hop - land * 2)
        p.frontElbow = CGPoint(x: 7, y: 38)
        p.backElbow = CGPoint(x: -7, y: 38)
        p.face = .shout
        return p
    }

    /// The "come at me" beckon from the reference sheet's taunt frames.
    private static func taunt(_ u: CGFloat) -> Pose {
        var p = Pose()
        let wave = sin(u * .pi * 6)
        p.liftUpperBody(CGPoint(x: 1, y: 0))
        p.frontHand = CGPoint(x: 14 + wave * 3, y: 36 + wave)
        p.frontElbow = CGPoint(x: 9, y: 33)
        p.backHand = CGPoint(x: -9, y: 27)
        p.backElbow = CGPoint(x: -9, y: 35)
        p.frontFoot = CGPoint(x: 8, y: 4)
        p.backFoot = CGPoint(x: -9, y: 4)
        p.face = .grin
        return p
    }

    private static func victory(_ u: CGFloat, anim: CGFloat) -> Pose {
        var p = Pose()
        let raise = smoothstep(u / 0.25)
        let bounce = (sin(anim * 9) * 1.5).rounded()
        p.liftUpperBody(CGPoint(x: 0, y: bounce))
        p.backHand = CGPoint(x: -7, y: 44 + 30 * raise + bounce)
        p.backElbow = CGPoint(x: -10, y: 42 + 10 * raise)
        p.frontHand = CGPoint(x: 8, y: 44 + 32 * raise + bounce)
        p.frontElbow = CGPoint(x: 11, y: 42 + 10 * raise)
        p.frontFoot = CGPoint(x: 9, y: 4)
        p.backFoot = CGPoint(x: -9, y: 4)
        p.frontKnee = CGPoint(x: 9, y: 15)
        p.backKnee = CGPoint(x: -9, y: 15)
        p.face = .grin
        return p
    }

    private static func hurt(_ u: CGFloat) -> Pose {
        var p = Pose()
        let recoil = sin(.pi * u)
        p.liftUpperBody(CGPoint(x: -7 * recoil, y: -2 * recoil))
        p.neck += CGPoint(x: -3 * recoil, y: 0)
        p.frontHand = CGPoint(x: 8 + 4 * recoil, y: 42 + 4 * recoil)
        p.frontElbow = CGPoint(x: 6, y: 38)
        p.backHand = CGPoint(x: -12 * recoil - 2, y: 38)
        p.backElbow = CGPoint(x: -8, y: 37)
        p.frontFoot = CGPoint(x: 6, y: 4)
        p.backFoot = CGPoint(x: -10 - 4 * recoil, y: 4)
        p.backKnee = CGPoint(x: -8, y: 15)
        p.face = .hurt
        return p
    }

    private static func dance(_ t: CGFloat) -> Pose {
        var p = Pose()
        let s = sin(t * 8)
        let c = cos(t * 8)
        p.liftUpperBody(CGPoint(x: (s * 3).rounded(), y: (abs(c) * -1.5).rounded()))
        p.hip.x += (s * 2).rounded()
        p.frontHand = CGPoint(x: 11 + s * 2, y: 38 + c * 8)
        p.backHand = CGPoint(x: -10 + s * 2, y: 38 - c * 8)
        p.frontElbow = CGPoint(x: 9, y: 36)
        p.backElbow = CGPoint(x: -9, y: 36)
        p.frontFoot = CGPoint(x: 7 + s * 2, y: 4)
        p.backFoot = CGPoint(x: -7 + s * 2, y: 4)
        p.frontKnee = CGPoint(x: 7, y: 15)
        p.backKnee = CGPoint(x: -7, y: 15)
        p.face = .grin
        return p
    }

    private static func stretch(_ u: CGFloat) -> Pose {
        var p = Pose()
        let reach = sin(.pi * u)
        p.liftUpperBody(CGPoint(x: 0, y: reach * 2))
        p.frontHand = CGPoint(x: 10, y: 47 + 13 * reach)
        p.backHand = CGPoint(x: -8, y: 46 + 13 * reach)
        p.frontElbow = CGPoint(x: 9, y: 42)
        p.backElbow = CGPoint(x: -8, y: 42)
        p.frontFoot = CGPoint(x: 5, y: 4)
        p.backFoot = CGPoint(x: -6, y: 4)
        p.frontKnee = CGPoint(x: 5, y: 15)
        p.backKnee = CGPoint(x: -6, y: 15)
        p.face = reach > 0.5 ? .shout : .calm
        return p
    }

    /// Rolling about on an office chair with his legs up.
    private static func chair(_ anim: CGFloat) -> Pose {
        var p = Pose()
        p.onChair = true
        p.chairWobble = (sin(anim * 5.5) * 0.9).rounded()
        let bob = sin(anim * 5.5) * 0.7
        p.hip = CGPoint(x: -2 + p.chairWobble, y: 24 + bob)
        p.shoulder = CGPoint(x: -3 + p.chairWobble, y: 40 + bob)
        p.neck = CGPoint(x: -2 + p.chairWobble, y: 42 + bob)
        p.headTilt = -0.12
        p.frontKnee = CGPoint(x: 9, y: 22 + bob)
        p.frontFoot = CGPoint(x: 17, y: 13)
        p.backKnee = CGPoint(x: 7, y: 20 + bob)
        p.backFoot = CGPoint(x: 14, y: 10)
        p.frontHand = CGPoint(x: 15, y: 54 + bob)
        p.frontElbow = CGPoint(x: 14, y: 45 + bob)
        p.backHand = CGPoint(x: -12, y: 30 + bob)
        p.backElbow = CGPoint(x: -12, y: 36 + bob)
        p.face = .grin
        return p
    }

    /// Doubled over with his hands on his knees.
    private static func vomit(_ u: CGFloat, anim: CGFloat) -> Pose {
        var p = Pose()
        let bend = smoothstep(u / 0.2) - smoothstep((u - 0.84) / 0.16)
        let heave = sin(anim * 14) * 0.8 * bend
        p.hip = CGPoint(x: -1, y: 26 - bend)
        p.shoulder = CGPoint(x: 1 + 7 * bend, y: 43 - 8 * bend + heave)
        p.neck = CGPoint(x: 3 + 8 * bend, y: 44 - 9 * bend + heave)
        p.headTilt = -0.62 * bend
        p.frontKnee = CGPoint(x: 7, y: 15)
        p.frontFoot = CGPoint(x: 8, y: 4)
        p.backKnee = CGPoint(x: -8, y: 15)
        p.backFoot = CGPoint(x: -10, y: 4)
        p.frontHand = CGPoint(x: 9 + 3 * bend, y: 22 + 6 * (1 - bend))
        p.frontElbow = CGPoint(x: 11, y: 31 - 2 * bend)
        p.backHand = CGPoint(x: -7 + 3 * bend, y: 22 + 6 * (1 - bend))
        p.backElbow = CGPoint(x: -11, y: 31 - 2 * bend)
        p.face = bend > 0.5 ? .sick : .hurt
        p.vomit = bend > 0.4 ? clamp((u - 0.22) / 0.6, 0, 1) : 0
        return p
    }

    /// Head back, fists clenched, yelling it at the ceiling.
    private static func yell(_ u: CGFloat, anim: CGFloat) -> Pose {
        var p = Pose()
        let push = smoothstep(u / 0.18) - smoothstep((u - 0.82) / 0.18)
        let shake = sin(anim * 24) * 0.7 * push
        p.liftUpperBody(CGPoint(x: -2 * push + shake, y: -1.5 * push))
        p.neck += CGPoint(x: -1.5 * push, y: 0)
        p.headTilt = 0.30 * push
        p.face = push > 0.3 ? .shout : .calm
        p.frontHand = CGPoint(x: 12 + 2 * push, y: 26 - 2 * push)
        p.frontElbow = CGPoint(x: 11, y: 34)
        p.backHand = CGPoint(x: -12 - 2 * push, y: 26 - 2 * push)
        p.backElbow = CGPoint(x: -11, y: 34)
        p.frontFoot = CGPoint(x: 9, y: 4)
        p.backFoot = CGPoint(x: -10, y: 4)
        return p
    }

    /// Push-ups, face down along the floor.
    private static func pushup(_ anim: CGFloat) -> Pose {
        var p = Pose()
        let up = (1 - cos(anim * 5)) / 2
        let lift = 9 + 7 * up
        p.hip = CGPoint(x: -8, y: lift)
        p.shoulder = CGPoint(x: 8, y: lift + 3)
        p.neck = CGPoint(x: 11, y: lift + 3)
        p.headTilt = -1.05
        p.backFoot = CGPoint(x: -26, y: 5)
        p.backKnee = CGPoint(x: -17, y: lift - 1)
        p.frontFoot = CGPoint(x: -24, y: 5)
        p.frontKnee = CGPoint(x: -16, y: lift)
        p.frontHand = CGPoint(x: 13, y: 4)
        p.backHand = CGPoint(x: 9, y: 4)
        p.frontElbow = lerp(CGPoint(x: 17, y: lift - 2), CGPoint(x: 11, y: (lift + 7) / 2), up)
        p.backElbow = lerp(CGPoint(x: 13, y: lift - 3), CGPoint(x: 8, y: (lift + 7) / 2), up)
        p.face = up < 0.3 ? .shout : .grin
        return p
    }

    /// Coffee break: mug at the chest, one long sip in the middle.
    private static func coffee(_ u: CGFloat, anim: CGFloat) -> Pose {
        var p = Pose()
        p.prop = .mug
        p.propPhase = anim
        let sip = smoothstep((u - 0.3) / 0.15) - smoothstep((u - 0.7) / 0.12)
        p.frontElbow = CGPoint(x: 10, y: 34 + 2 * sip)
        p.frontHand = CGPoint(x: 9 - 2 * sip, y: 37 + 10 * sip)
        p.headTilt = 0.14 * sip
        p.backHand = CGPoint(x: -9, y: 28)
        p.backElbow = CGPoint(x: -9, y: 35)
        p.frontFoot = CGPoint(x: 8, y: 4)
        p.backFoot = CGPoint(x: -9, y: 4)
        p.face = sip > 0.5 ? .blink : .calm
        return p
    }

    /// Sitting on the floor scrolling his phone.
    private static func phone(_ anim: CGFloat) -> Pose {
        var p = sit(anim)
        p.prop = .phone
        p.propPhase = anim
        p.headTilt = -0.38
        p.neck.x += 1.5
        p.frontHand = CGPoint(x: 8, y: 22 + (sin(anim * 6) * 0.4).rounded())
        p.frontElbow = CGPoint(x: 9, y: 16)
        p.backHand = CGPoint(x: 5, y: 21)
        p.backElbow = CGPoint(x: -6, y: 17)
        p.face = .calm
        return p
    }

    /// Hands to the hip, then thrust forward together — the fireball leaves at the thrust.
    private static func hadouken(_ u: CGFloat) -> Pose {
        var p = Pose()
        let charge = smoothstep(u / 0.36)
        let thrust = smoothstep((u - 0.38) / 0.12) - smoothstep((u - 0.78) / 0.22)
        p.liftUpperBody(CGPoint(x: 4 * thrust - 2 * charge * (1 - thrust), y: -3 * charge))
        p.frontFoot = CGPoint(x: 11, y: 4)
        p.backFoot = CGPoint(x: -12, y: 4)
        p.frontKnee = CGPoint(x: 10, y: 14)
        p.backKnee = CGPoint(x: -10, y: 14)
        let rest = CGPoint(x: 9, y: 36), hip = CGPoint(x: -9, y: 29), out = CGPoint(x: 21, y: 38)
        let hands = lerp(lerp(rest, hip, charge), out, thrust)
        p.frontHand = hands + CGPoint(x: 0, y: 1.6)
        p.backHand = hands + CGPoint(x: -1.5, y: -1.6)
        p.frontElbow = lerp(p.shoulder + CGPoint(x: 5, y: -2), p.frontHand, 0.5) + CGPoint(x: 1, y: -3 * (1 - thrust))
        p.backElbow = lerp(p.shoulder + CGPoint(x: -6, y: -2), p.backHand, 0.5) + CGPoint(x: -2, y: -3 * (1 - thrust))
        p.face = thrust > 0.3 ? .shout : .grin
        return p
    }

    /// Asleep sitting up, head dropped back.
    private static func sleep(_ anim: CGFloat) -> Pose {
        var p = sit(anim)
        let breath = sin(anim * 1.4) * 0.6
        p.headTilt = 0.42 + breath * 0.04
        p.neck.x -= 1.5
        p.frontHand = CGPoint(x: 10, y: 8)
        p.frontElbow = CGPoint(x: 8, y: 17)
        p.face = .blink
        return p
    }

    /// Sitting on the edge with his legs out, catching his breath.
    private static func sit(_ anim: CGFloat) -> Pose {
        var p = Pose()
        let breath = (sin(anim * 1.8) * 1.0).rounded()
        p.hip = CGPoint(x: -4, y: 10)
        p.shoulder = CGPoint(x: -1, y: 26 + breath)
        p.neck = CGPoint(x: 0, y: 28 + breath)
        p.frontFoot = CGPoint(x: 17, y: 4)
        p.backFoot = CGPoint(x: 14, y: 4)
        p.frontKnee = CGPoint(x: 7, y: 10)
        p.backKnee = CGPoint(x: 5, y: 9)
        p.frontHand = CGPoint(x: 8, y: 10)
        p.frontElbow = CGPoint(x: 7, y: 19)
        p.backHand = CGPoint(x: -12, y: 6)
        p.backElbow = CGPoint(x: -9, y: 18)
        p.face = .blink
        return p
    }
}
