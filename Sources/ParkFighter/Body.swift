import CoreGraphics

/// Near and far limbs share their shapes and differ only in tone, so the far side reads as behind.
struct Side {
    let skin: CGColor
    let skinShade: CGColor
    let tee: CGColor
    let teeShade: CGColor
    let jeans: CGColor
    let jeansShade: CGColor
    let shoe: CGColor
    let shoeShade: CGColor
    let sole: CGColor

    static let near = Side(skin: Art.skin, skinShade: Art.skinShade, tee: Art.tee, teeShade: Art.teeShade,
                           jeans: Art.jeans, jeansShade: Art.jeansShade, shoe: Art.shoe,
                           shoeShade: Art.shoeShade, sole: Art.sole)
    static let far = Side(skin: Art.skinFar, skinShade: Art.skinFarShade, tee: Art.teeFar, teeShade: Art.teeFarShade,
                          jeans: Art.jeansFar, jeansShade: Art.jeansFarShade, shoe: Art.shoeFar,
                          shoeShade: Art.shoeFarShade, sole: Art.soleShade)
}

enum Body {
    /// A five-star office chair, drawn behind him so he sits in it.
    static func chair(_ ctx: CGContext, wobble: CGFloat) {
        let hub = CGPoint(x: -1, y: 7)
        let castors = [CGPoint(x: -13, y: 3.4), CGPoint(x: -5, y: 2.4),
                       CGPoint(x: 5, y: 2.4), CGPoint(x: 11, y: 3.6)]
        for foot in castors {
            Art.shape(ctx, Art.limb([hub, foot], [3.6, 2.6]), Art.chairDark, Art.chairShade, width: 0.9)
        }
        for foot in castors {
            Art.shape(ctx, Art.ellipse(CGPoint(x: foot.x, y: foot.y - 1.2), 4.0, 4.0),
                      Art.chair, Art.chairShade, width: 0.9)
        }
        Art.shape(ctx, Art.limb([CGPoint(x: -1, y: 6), CGPoint(x: -1 + wobble * 0.5, y: 18)], [4.6, 4.6]),
                  Art.chair, Art.chairShade, width: 0.9)
        let back = Art.limb([CGPoint(x: -8 + wobble, y: 21), CGPoint(x: -11.5 + wobble, y: 35)], [10.5, 12.5])
        Art.shape(ctx, back, Art.seat, Art.seatShade, width: 1.1)
        let seat = CGPath(roundedRect: CGRect(x: -11 + wobble, y: 17.5, width: 22, height: 5.5),
                          cornerWidth: 2.4, cornerHeight: 2.4, transform: nil)
        Art.shape(ctx, seat, Art.seat, Art.seatShade, width: 1.1)
    }

    /// The stream and the puddle. Drawn as one merged shape so it keeps a single outline.
    static func sick(_ ctx: CGContext, from mouth: CGPoint, ground: CGFloat, progress u: CGFloat) {
        guard u > 0 else { return }
        let reach = clamp(u / 0.45, 0, 1)
        let fade = u > 0.82 ? 1 - (u - 0.82) / 0.18 : 1
        let path = CGMutablePath()
        var s: CGFloat = 0
        while s <= reach {
            let x = mouth.x + 15 * s
            let y = mouth.y - 3 * s - 30 * s * s
            if y > ground + 1 { path.addPath(Art.ellipse(CGPoint(x: x, y: y), 5.4 - 2.0 * s, 4.6 - 1.8 * s)) }
            s += 0.055
        }
        let spread = clamp((u - 0.2) / 0.7, 0, 1)
        if spread > 0 {
            path.addPath(Art.ellipse(CGPoint(x: mouth.x + 13, y: ground + 1.2), 10 + 16 * spread, 3.4 + 1.6 * spread))
        }
        ctx.saveGState()
        ctx.setAlpha(fade)
        Art.group(ctx, [(path, Art.bile, Art.bileShade)], width: 0.9)
        ctx.restoreGState()
    }

    /// Neck first so the collar of the tee sits over it.
    static func neck(_ ctx: CGContext, at point: CGPoint) {
        Art.shape(ctx, CGPath(roundedRect: CGRect(x: point.x - 3.3, y: point.y - 4, width: 6.8, height: 9),
                              cornerWidth: 2.0, cornerHeight: 2.0, transform: nil), Art.skin, Art.skinShade)
    }

    static func torsoPath(hip: CGPoint, shoulder: CGPoint) -> CGPath {
        let d = unit(shoulder - hip)
        let n = CGPoint(x: -d.y, y: d.x)
        let hem = hip - d * 0.6
        let hipHalf: CGFloat = 7.0, shoulderHalf: CGFloat = 9.0
        let p = CGMutablePath()
        p.move(to: hem + n * hipHalf)
        p.addQuadCurve(to: shoulder + n * shoulderHalf, control: hip + n * (hipHalf + 0.6))
        p.addQuadCurve(to: shoulder - n * shoulderHalf, control: shoulder + d * 1.3)
        p.addQuadCurve(to: hem - n * hipHalf, control: hip - n * (hipHalf + 0.6))
        p.addQuadCurve(to: hem + n * hipHalf, control: hem - d * 1.8)
        p.closeSubpath()
        return p
    }

    static func torso(_ ctx: CGContext, path p: CGPath, hip: CGPoint, shoulder: CGPoint) {
        let d = unit(shoulder - hip)
        let n = CGPoint(x: -d.y, y: d.x)
        let hem = hip - d * 0.6
        Art.shape(ctx, p, Art.tee, Art.teeShade, width: 1.1)

        // Two folds so the tee is not a flat slab.
        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        let fold = CGMutablePath()
        fold.move(to: hip + n * 4.2 + d * 1.0)
        fold.addQuadCurve(to: hip + n * 1.4 + d * 5.0, control: hip + n * 3.8 + d * 3.4)
        fold.move(to: hem - n * 3.0 + d * 1.4)
        fold.addQuadCurve(to: hem - n * 4.6 + d * 4.6, control: hem - n * 4.4 + d * 2.6)
        ctx.addPath(fold)
        ctx.setStrokeColor(Art.teeShade)
        ctx.setLineWidth(0.8)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()

        // V-neck, as he wears it.
        let top = shoulder + d * 1.4
        let v = CGMutablePath()
        v.move(to: top + n * 3.8)
        v.addQuadCurve(to: top - n * 3.4, control: top + d * 1.6)
        v.addQuadCurve(to: top - d * 6.4 - n * 0.2, control: top - d * 2.6 - n * 2.4)
        v.addQuadCurve(to: top + n * 3.8, control: top - d * 2.4 + n * 2.8)
        v.closeSubpath()
        Art.shape(ctx, v, Art.skin, Art.skinShade, width: 0.95)
    }

    static func arm(_ ctx: CGContext, shoulder: CGPoint, elbow: CGPoint, hand: CGPoint, side: Side) {
        let limb = Art.limb([shoulder, elbow, hand], [5.4, 4.0, 2.9])
        let away = unit(hand - elbow)
        let fist = fistPath(at: hand + away * 1.1, along: away)
        Art.group(ctx, [(limb, side.skin, side.skinShade), (fist, side.skin, side.skinShade)])

        ctx.saveGState()
        ctx.addPath(limb)
        ctx.addPath(fist)
        ctx.clip()
        let n = CGPoint(x: -away.y, y: away.x)
        let creases = CGMutablePath()
        // Bicep.
        let mid = lerp(shoulder, elbow, 0.55)
        creases.move(to: lerp(shoulder, elbow, 0.22))
        creases.addQuadCurve(to: mid, control: lerp(shoulder, elbow, 0.38) + CGPoint(x: 1.6, y: 0.4))
        // Wrist, then the knuckle line across the fist.
        creases.move(to: hand + n * 1.5)
        creases.addLine(to: hand - n * 1.5)
        creases.move(to: hand + away * 1.9 + n * 1.5)
        creases.addLine(to: hand + away * 1.9 - n * 1.5)
        ctx.addPath(creases)
        ctx.setStrokeColor(side.skinShade)
        ctx.setLineWidth(0.8)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// A blunt mitt lying along the forearm, not a ball stuck on the end of it.
    private static func fistPath(at centre: CGPoint, along away: CGPoint) -> CGPath {
        var transform = CGAffineTransform(translationX: centre.x, y: centre.y)
            .rotated(by: atan2(away.y, away.x))
        return CGPath(roundedRect: CGRect(x: -2.3, y: -1.95, width: 4.6, height: 3.9),
                      cornerWidth: 1.5, cornerHeight: 1.5, transform: &transform)
    }

    /// The sleeve is part of the shirt: it follows the upper arm and ends in a hem. The far one
    /// goes behind the torso; the near one is inked only where it clears it, so there is no seam
    /// across the chest.
    static func sleeve(_ ctx: CGContext, shoulder: CGPoint, elbow: CGPoint, side: Side, torso: CGPath?) {
        let d = unit(elbow - shoulder)
        let n = CGPoint(x: -d.y, y: d.x)
        let cap = shoulder - d * 1.4
        let hem = lerp(shoulder, elbow, 0.46)
        let path = CGMutablePath()
        path.move(to: cap + n * 3.5)
        path.addQuadCurve(to: cap - n * 3.5, control: cap - d * 3.4)
        path.addLine(to: hem - n * 3.2)
        path.addQuadCurve(to: hem + n * 3.2, control: hem + d * 0.9)
        path.closeSubpath()

        guard let torso else {
            Art.shape(ctx, path, side.tee, side.teeShade, width: 1.0)
            return
        }
        Art.cel(ctx, path, base: side.tee, shade: side.teeShade)
        ctx.saveGState()
        Art.clipOutside(ctx, torso)
        Art.ink(ctx, path, width: 1.0)
        ctx.restoreGState()
    }

    static func leg(_ ctx: CGContext, hip: CGPoint, knee: CGPoint, ankle: CGPoint, side: Side) {
        let path = Art.limb([hip, knee, ankle], [8.2, 6.0, 4.8])
        Art.shape(ctx, path, side.jeans, side.jeansShade, width: 1.1)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let creases = CGMutablePath()
        creases.move(to: lerp(knee, hip, 0.18) + CGPoint(x: -2.4, y: 0))
        creases.addQuadCurve(to: lerp(knee, hip, 0.3) + CGPoint(x: 1.6, y: 0.4),
                             control: lerp(knee, hip, 0.1) + CGPoint(x: 0, y: -0.8))
        creases.move(to: lerp(knee, ankle, 0.25) + CGPoint(x: -2.2, y: 0))
        creases.addQuadCurve(to: lerp(knee, ankle, 0.34) + CGPoint(x: 1.4, y: 0.4),
                             control: lerp(knee, ankle, 0.18) + CGPoint(x: 0, y: -0.6))
        ctx.addPath(creases)
        ctx.setStrokeColor(side.jeansShade)
        ctx.setLineWidth(0.85)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
        shoe(ctx, ankle: ankle, side: side)
    }

    /// A low-top trainer: grey upper, white sole, pointing the way he faces.
    private static func shoe(_ ctx: CGContext, ankle: CGPoint, side: Side) {
        ctx.saveGState()
        ctx.translateBy(x: ankle.x, y: ankle.y)
        let upper = CGMutablePath()
        upper.move(to: CGPoint(x: -3.4, y: 2.6))
        upper.addQuadCurve(to: CGPoint(x: 3.0, y: -1.2), control: CGPoint(x: 2.6, y: 2.0))
        upper.addQuadCurve(to: CGPoint(x: 6.0, y: -2.2), control: CGPoint(x: 5.4, y: -1.6))
        upper.addLine(to: CGPoint(x: -3.6, y: -2.2))
        upper.addQuadCurve(to: CGPoint(x: -3.4, y: 2.6), control: CGPoint(x: -4.6, y: 0.4))
        upper.closeSubpath()
        Art.shape(ctx, upper, side.shoe, side.shoeShade, width: 1.0)
        let sole = CGPath(roundedRect: CGRect(x: -4.0, y: -4.0, width: 10.6, height: 2.2),
                          cornerWidth: 1.0, cornerHeight: 1.0, transform: nil)
        Art.shape(ctx, sole, side.sole, side.sole == Art.sole ? Art.soleShade : Art.shoeShade, width: 1.0)
        ctx.restoreGState()
    }

    private static func fistCreases(_ ctx: CGContext, at centre: CGPoint, along away: CGPoint, side: Side) {
        ctx.saveGState()
        ctx.addPath(Art.ellipse(centre, 4.8, 4.6))
        ctx.clip()
        let n = CGPoint(x: -away.y, y: away.x)
        let knuckles = CGMutablePath()
        knuckles.move(to: centre + away * 0.6 + n * 2.2)
        knuckles.addLine(to: centre + away * 0.6 - n * 2.2)
        knuckles.move(to: centre + away * 2.0 + n * 1.8)
        knuckles.addLine(to: centre + away * 2.0 - n * 1.8)
        ctx.addPath(knuckles)
        ctx.setStrokeColor(side.skinShade)
        ctx.setLineWidth(0.7)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    static func mug(_ ctx: CGContext, at hand: CGPoint, steam: CGFloat) {
        let body = CGPath(roundedRect: CGRect(x: hand.x - 2.3, y: hand.y - 1.2, width: 4.6, height: 4.8),
                          cornerWidth: 0.8, cornerHeight: 0.8, transform: nil)
        let handle = CGMutablePath()
        handle.addArc(center: CGPoint(x: hand.x - 2.4, y: hand.y + 1.2), radius: 1.4,
                      startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: false)
        Art.ink(ctx, handle, width: 2.2)
        ctx.addPath(handle)
        ctx.setStrokeColor(Art.mug)
        ctx.setLineWidth(0.9)
        ctx.strokePath()
        Art.shape(ctx, body, Art.mug, Art.mugShade, width: 0.9)
        Art.flat(ctx, Art.ellipse(CGPoint(x: hand.x, y: hand.y + 3.4), 3.6, 1.1), Art.coffee)
        for (i, dx) in [-1.0, 0.9].enumerated() {
            let wisp = CGMutablePath()
            let sway = sin(steam * 3 + CGFloat(i) * 2) * 0.6
            wisp.move(to: CGPoint(x: hand.x + dx, y: hand.y + 4.4))
            wisp.addCurve(to: CGPoint(x: hand.x + dx + sway, y: hand.y + 8.2),
                          control1: CGPoint(x: hand.x + dx - 1.2, y: hand.y + 5.6),
                          control2: CGPoint(x: hand.x + dx + 1.2 + sway, y: hand.y + 7.0))
            ctx.addPath(wisp)
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.65))
            ctx.setLineWidth(0.7)
            ctx.setLineCap(.round)
            ctx.strokePath()
        }
    }

    static func phone(_ ctx: CGContext, at centre: CGPoint, tilt: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: centre.x, y: centre.y)
        ctx.rotate(by: -0.35 + tilt * 0.3)
        let body = CGPath(roundedRect: CGRect(x: -1.9, y: -3.2, width: 3.8, height: 6.4),
                          cornerWidth: 0.7, cornerHeight: 0.7, transform: nil)
        Art.shape(ctx, body, Art.phone, Art.phoneShade, width: 0.9)
        Art.flat(ctx, CGPath(roundedRect: CGRect(x: -1.4, y: -2.6, width: 2.8, height: 5.2),
                             cornerWidth: 0.4, cornerHeight: 0.4, transform: nil), Art.screen)
        ctx.restoreGState()
    }

    /// The fireball, drawn into its own small canvas: flame trailing to -x, ball at the front.
    static let fireballWidth: CGFloat = 36
    static let fireballHeight: CGFloat = 24

    static func renderFireball(pixelScale: CGFloat, phase: CGFloat, burst: CGFloat) -> CGImage? {
        let width = max(Int(fireballWidth * pixelScale), 1), height = max(Int(fireballHeight * pixelScale), 1)
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: pixelScale, y: pixelScale)
        let c = CGPoint(x: 25, y: 12)
        if burst > 0 {
            ctx.setAlpha(1 - burst)
            spark(ctx, at: c, size: 6 + 9 * burst)
            return ctx.makeImage()
        }
        let wobble = sin(phase * 26) * 1.3
        let flame = CGMutablePath()
        flame.move(to: CGPoint(x: c.x, y: c.y + 6))
        flame.addQuadCurve(to: CGPoint(x: 3, y: c.y + wobble), control: CGPoint(x: 12, y: c.y + 8.5 + wobble))
        flame.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 6), control: CGPoint(x: 12, y: c.y - 8.5 - wobble))
        flame.addArc(center: c, radius: 6, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        flame.closeSubpath()
        Art.shape(ctx, flame, Art.fire, Art.fireShade, width: 1.0)
        Art.flat(ctx, Art.ellipse(CGPoint(x: c.x + 1.2, y: c.y), 6.4, 6.4), Art.fireCore)
        Art.flat(ctx, Art.ellipse(CGPoint(x: c.x + 2.2, y: c.y + 0.6), 2.6, 2.6), Art.sparkHot)
        return ctx.makeImage()
    }

    static func spark(_ ctx: CGContext, at point: CGPoint, size: CGFloat) {
        let p = CGMutablePath()
        let spikes = 8
        for i in 0..<(spikes * 2) {
            let angle = CGFloat(i) / CGFloat(spikes * 2) * .pi * 2
            let r = i % 2 == 0 ? size : size * 0.42
            let v = CGPoint(x: point.x + cos(angle) * r, y: point.y + sin(angle) * r)
            if i == 0 { p.move(to: v) } else { p.addLine(to: v) }
        }
        p.closeSubpath()
        Art.shape(ctx, p, Art.spark, Art.spark, width: 0.9)
        Art.flat(ctx, Art.ellipse(point, size * 0.6, size * 0.6), Art.sparkHot)
    }

    private static func unit(_ p: CGPoint) -> CGPoint {
        let l = p.length
        return l > 0.0001 ? CGPoint(x: p.x / l, y: p.y / l) : CGPoint(x: 1, y: 0)
    }
}
