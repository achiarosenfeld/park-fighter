import CoreGraphics

/// The head, drawn facing +x with the origin at the base of the neck.
/// Laid out to the reference: hairline high on the forehead, heavy angled brows, a moustache
/// and chin patch, and a jaw that ends in a blunt chin.
enum Head {
    private static let scale: CGFloat = 1.16
    private static let mouthLocal = CGPoint(x: 5.8, y: 6.2)
    /// The features are drawn on a mask set back from the front of the skull, so both eyes read.
    private static let maskOffset: CGFloat = -1.6

    /// Where the mouth ends up in character space once the head is tilted.
    static func mouth(neck: CGPoint, tilt: CGFloat) -> CGPoint {
        let local = mouthLocal * scale
        return CGPoint(x: neck.x + local.x * cos(tilt) - local.y * sin(tilt),
                       y: neck.y + local.x * sin(tilt) + local.y * cos(tilt))
    }

    static func draw(_ ctx: CGContext, at neck: CGPoint, face: Face, tilt: CGFloat = 0) {
        ctx.saveGState()
        ctx.translateBy(x: neck.x, y: neck.y)
        ctx.rotate(by: tilt)
        // The reference head is a big cartoon head: a bit over a quarter of the whole figure.
        ctx.scaleBy(x: scale, y: scale)

        Art.shape(ctx, skull, Art.skin, Art.skinShade, width: 1.0)
        ctx.saveGState()
        // Clipped to the skull, so the beard follows the jaw instead of hanging off it.
        ctx.addPath(skull)
        ctx.clip()
        ctx.translateBy(x: maskOffset, y: 0)
        brows(ctx, face: face)
        eyes(ctx, face: face)
        nose(ctx)
        stubble(ctx)
        // Beard first: an open mouth then sits inside the van dyke instead of being swallowed by it.
        facialHair(ctx)
        mouth(ctx, face: face)
        if face == .calm || face == .grin || face == .blink { smileCrease(ctx) }
        ctx.restoreGState()
        Art.shape(ctx, hair, Art.hair, Art.hairShade, width: 1.0)
        Art.shape(ctx, Art.ellipse(CGPoint(x: -4.9, y: 9.4), 3.0, 4.0), Art.skin, Art.skinShade)
        Art.ink(ctx, arc(CGPoint(x: -4.7, y: 9.4), 1.1, from: .pi * 0.35, to: .pi * 1.45), width: 0.55)
        if face == .hurt {
            ctx.saveGState()
            ctx.translateBy(x: maskOffset, y: 0)
            bruises(ctx)
            ctx.restoreGState()
        }

        ctx.restoreGState()
    }

    /// Three-quarter view: a round cranium, a nearly vertical face front, and a jaw that
    /// tapers to a chin sitting under the mouth rather than behind it.
    private static let skull: CGPath = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 5.2, y: 2.0))
        p.addQuadCurve(to: CGPoint(x: 8.0, y: 4.8), control: CGPoint(x: 7.4, y: 2.4))
        p.addQuadCurve(to: CGPoint(x: 8.8, y: 13.4), control: CGPoint(x: 9.2, y: 9.0))
        p.addQuadCurve(to: CGPoint(x: 0.6, y: 20.2), control: CGPoint(x: 8.4, y: 19.4))
        p.addQuadCurve(to: CGPoint(x: -6.0, y: 12.4), control: CGPoint(x: -6.0, y: 18.8))
        p.addQuadCurve(to: CGPoint(x: -1.6, y: 4.2), control: CGPoint(x: -6.2, y: 6.6))
        p.addQuadCurve(to: CGPoint(x: 5.2, y: 2.0), control: CGPoint(x: 1.2, y: 2.2))
        p.closeSubpath()
        return p
    }()

    /// Short back and sides, brushed up into a small quiff at the front, with mild recession at
    /// the temples so the forehead reads.
    private static let hair: CGPath = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 7.9, y: 16.6))
        p.addQuadCurve(to: CGPoint(x: 4.2, y: 21.6), control: CGPoint(x: 8.4, y: 20.6))
        p.addQuadCurve(to: CGPoint(x: -3.0, y: 20.4), control: CGPoint(x: 0.6, y: 22.0))
        p.addQuadCurve(to: CGPoint(x: -6.4, y: 13.0), control: CGPoint(x: -6.6, y: 18.6))
        p.addQuadCurve(to: CGPoint(x: -4.8, y: 7.6), control: CGPoint(x: -6.6, y: 9.6))
        p.addQuadCurve(to: CGPoint(x: -4.0, y: 11.4), control: CGPoint(x: -3.8, y: 9.2))
        p.addQuadCurve(to: CGPoint(x: -1.0, y: 15.8), control: CGPoint(x: -3.4, y: 15.0))
        p.addQuadCurve(to: CGPoint(x: 2.8, y: 15.6), control: CGPoint(x: 0.8, y: 16.6))
        p.addQuadCurve(to: CGPoint(x: 5.8, y: 16.4), control: CGPoint(x: 4.4, y: 15.4))
        p.addQuadCurve(to: CGPoint(x: 7.9, y: 16.6), control: CGPoint(x: 7.0, y: 17.0))
        p.closeSubpath()
        return p
    }()

    /// A faint shadow of stubble from the sideburn down the jaw to the beard.
    private static func stubble(_ ctx: CGContext) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -2.4, y: 10.4))
        p.addQuadCurve(to: CGPoint(x: 3.4, y: 3.8), control: CGPoint(x: -1.4, y: 5.0))
        p.addQuadCurve(to: CGPoint(x: 9.4, y: 6.4), control: CGPoint(x: 7.6, y: 2.6))
        p.addQuadCurve(to: CGPoint(x: 6.6, y: 5.0), control: CGPoint(x: 8.6, y: 6.4))
        p.addQuadCurve(to: CGPoint(x: 1.2, y: 7.4), control: CGPoint(x: 3.0, y: 5.4))
        p.addQuadCurve(to: CGPoint(x: -2.4, y: 10.4), control: CGPoint(x: -1.4, y: 8.6))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(Art.hairShade.copy(alpha: 0.14) ?? Art.hairShade)
        ctx.fillPath()
    }

    private static func smileCrease(_ ctx: CGContext) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 8.6, y: 9.4))
        p.addQuadCurve(to: CGPoint(x: 8.4, y: 6.8), control: CGPoint(x: 9.3, y: 8.0))
        Art.ink(ctx, p, width: 0.45)
    }

    /// The van dyke: moustache, a strip down each side of the mouth, and a pointed chin patch.
    private static func facialHair(_ ctx: CGContext) {
        let tache = CGMutablePath()
        tache.move(to: CGPoint(x: 3.4, y: 8.4))
        tache.addQuadCurve(to: CGPoint(x: 8.0, y: 8.8), control: CGPoint(x: 5.7, y: 9.8))
        tache.addQuadCurve(to: CGPoint(x: 5.6, y: 8.0), control: CGPoint(x: 7.3, y: 7.9))
        tache.addQuadCurve(to: CGPoint(x: 3.4, y: 8.4), control: CGPoint(x: 4.2, y: 8.1))
        tache.closeSubpath()
        Art.cel(ctx, tache, base: Art.hair, shade: Art.hairShade)

        let frame = CGMutablePath()
        frame.addPath(Art.limb([CGPoint(x: 3.6, y: 8.2), CGPoint(x: 4.0, y: 6.2)], [0.7, 0.6]))
        frame.addPath(Art.limb([CGPoint(x: 7.9, y: 8.4), CGPoint(x: 7.6, y: 6.4)], [0.7, 0.6]))
        let chin = CGMutablePath()
        chin.move(to: CGPoint(x: 3.5, y: 5.6))
        chin.addQuadCurve(to: CGPoint(x: 8.0, y: 5.5), control: CGPoint(x: 5.8, y: 6.2))
        chin.addQuadCurve(to: CGPoint(x: 5.6, y: 2.2), control: CGPoint(x: 7.8, y: 2.8))
        chin.addQuadCurve(to: CGPoint(x: 3.5, y: 5.6), control: CGPoint(x: 3.4, y: 3.0))
        chin.closeSubpath()
        frame.addPath(chin)
        Art.cel(ctx, frame, base: Art.hair, shade: Art.hairShade)
    }

    private static func brows(_ ctx: CGContext, face: Face) {
        let lift: CGFloat = face == .shout || face == .hurt || face == .sick ? 0.6 : 0
        let anger: CGFloat = face == .calm || face == .blink ? 0.1 : 1.0
        let near = Art.limb([CGPoint(x: 5.0, y: 12.6 + lift), CGPoint(x: 7.0, y: 12.9 + lift - anger * 0.4),
                             CGPoint(x: 8.8, y: 12.4 + lift - anger)], [1.6, 1.8, 1.1])
        let far = Art.limb([CGPoint(x: 0.6, y: 12.9 + lift), CGPoint(x: 2.2, y: 13.1 + lift),
                            CGPoint(x: 3.8, y: 12.7 + lift - anger * 0.6)], [1.3, 1.5, 1.0])
        Art.cel(ctx, far, base: Art.hairShade, shade: Art.hairShade)
        Art.cel(ctx, near, base: Art.hair, shade: Art.hairShade)
        Art.ink(ctx, near, width: 0.45)
    }

    private static func eyes(_ ctx: CGContext, face: Face) {
        let nearCentre = CGPoint(x: 6.6, y: 10.9)
        let farCentre = CGPoint(x: 2.6, y: 11.2)
        if face == .blink || face == .hurt || face == .sick {
            Art.ink(ctx, arc(nearCentre, 1.5, from: .pi * 1.12, to: .pi * 1.88), width: 0.7)
            Art.ink(ctx, arc(farCentre, 1.2, from: .pi * 1.12, to: .pi * 1.88), width: 0.6)
            return
        }
        let wide: CGFloat = face == .shout ? 1.35 : 0.72
        for (centre, w, h, irisSize) in [(farCentre, CGFloat(2.3), CGFloat(1.9), CGFloat(1.3)),
                                         (nearCentre, 2.9, 2.2, 1.55)] {
            let white = Art.ellipse(centre, w, h * wide)
            Art.flat(ctx, white, Art.eyeWhite)
            ctx.saveGState()
            ctx.addPath(white)
            ctx.clip()
            Art.flat(ctx, Art.ellipse(CGPoint(x: centre.x + 0.4, y: centre.y - 0.05), irisSize, irisSize * 1.15),
                     Art.iris)
            Art.flat(ctx, Art.ellipse(CGPoint(x: centre.x + 0.75, y: centre.y + 0.4), irisSize * 0.34,
                                      irisSize * 0.34), Art.eyeWhite)
            ctx.restoreGState()
            Art.ink(ctx, white, width: 0.45)
            Art.ink(ctx, arc(centre, w / 2, from: .pi * 0.08, to: .pi * 0.92), width: 0.7)
        }
    }

    private static func nose(_ ctx: CGContext) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 7.9, y: 10.6))
        p.addQuadCurve(to: CGPoint(x: 8.6, y: 9.0), control: CGPoint(x: 8.9, y: 10.0))
        p.addQuadCurve(to: CGPoint(x: 7.2, y: 8.7), control: CGPoint(x: 8.0, y: 8.4))
        Art.ink(ctx, p, width: 0.7)
    }

    private static func mouth(_ ctx: CGContext, face: Face) {
        switch face {
        case .calm, .blink:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 4.0, y: 7.5))
            p.addQuadCurve(to: CGPoint(x: 7.7, y: 7.4), control: CGPoint(x: 5.9, y: 5.6))
            p.addQuadCurve(to: CGPoint(x: 4.0, y: 7.5), control: CGPoint(x: 5.9, y: 7.1))
            p.closeSubpath()
            Art.flat(ctx, p, Art.teeth)
            Art.ink(ctx, p, width: 0.6)
        case .grin:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 3.8, y: 7.4))
            p.addQuadCurve(to: CGPoint(x: 7.9, y: 7.0), control: CGPoint(x: 5.9, y: 5.0))
            p.addQuadCurve(to: CGPoint(x: 3.8, y: 7.4), control: CGPoint(x: 5.9, y: 6.9))
            p.closeSubpath()
            Art.flat(ctx, p, Art.teeth)
            Art.ink(ctx, p, width: 0.6)
        case .shout, .hurt, .sick:
            let p = Art.ellipse(CGPoint(x: 5.9, y: 6.8), face == .sick ? 3.8 : 3.1, face == .sick ? 3.0 : 2.5)
            Art.flat(ctx, p, Art.mouth)
            ctx.saveGState()
            ctx.addPath(p)
            ctx.clip()
            Art.flat(ctx, CGPath(rect: CGRect(x: 4.0, y: 7.3, width: 4.0, height: 0.9), transform: nil), Art.teeth)
            ctx.restoreGState()
            Art.ink(ctx, p, width: 0.7)
        }
    }

    private static func bruises(_ ctx: CGContext) {
        for (a, b) in [(CGPoint(x: 5.6, y: 14.4), CGPoint(x: 7.8, y: 13.4)),
                       (CGPoint(x: 8.2, y: 9.6), CGPoint(x: 8.8, y: 8.0))] {
            let p = CGMutablePath()
            p.move(to: a)
            p.addLine(to: b)
            ctx.addPath(p)
            ctx.setStrokeColor(Art.blood)
            ctx.setLineWidth(0.8)
            ctx.setLineCap(.round)
            ctx.strokePath()
        }
    }

    private static func arc(_ centre: CGPoint, _ r: CGFloat, from: CGFloat, to: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addArc(center: centre, radius: r, startAngle: from, endAngle: to, clockwise: false)
        return p
    }
}
