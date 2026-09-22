import CoreGraphics

/// Palette and the two drawing primitives everything else is built from:
/// a cel-shaded fill (flat colour plus one offset shadow) and a bold ink outline.
enum Art {
    static func rgb(_ hex: UInt32) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    static let outline = rgb(0x1B1A20)

    static let skin = rgb(0xF6C49A)
    static let skinShade = rgb(0xDBA372)
    static let skinFar = rgb(0xDBA372)
    static let skinFarShade = rgb(0xBF8A58)

    static let hair = rgb(0x3A2C24)
    static let hairShade = rgb(0x1F1714)

    static let tee = rgb(0xD6E5EC)
    static let teeShade = rgb(0xAAC4D0)
    static let teeFar = rgb(0xAAC4D0)
    static let teeFarShade = rgb(0x8AA7B5)

    static let jeans = rgb(0x2F5280)
    static let jeansShade = rgb(0x1F3A5E)
    static let jeansFar = rgb(0x22406A)
    static let jeansFarShade = rgb(0x172C4A)

    static let shoe = rgb(0x70737A)
    static let shoeShade = rgb(0x4B4E55)
    static let shoeFar = rgb(0x53565D)
    static let shoeFarShade = rgb(0x3A3C42)
    static let sole = rgb(0xF4F3EE)
    static let soleShade = rgb(0xCFCEC8)

    static let eyeWhite = rgb(0xFFFFFF)
    static let iris = rgb(0x4B3524)
    static let mouth = rgb(0x5E2A28)
    static let teeth = rgb(0xFFFDF6)
    static let chair = rgb(0x7C828C)
    static let chairShade = rgb(0x555B64)
    static let chairDark = rgb(0x4A4F58)
    static let seat = rgb(0x3E434C)
    static let seatShade = rgb(0x2A2E36)
    static let bile = rgb(0x9DBE4A)
    static let bileShade = rgb(0x6E8C2C)

    static let mug = rgb(0xF4F1EA)
    static let mugShade = rgb(0xC9C4B8)
    static let coffee = rgb(0x4A2E1B)
    static let phone = rgb(0x2B2D33)
    static let phoneShade = rgb(0x181A1F)
    static let screen = rgb(0xBFE3FF)
    static let fire = rgb(0xFF8A2A)
    static let fireShade = rgb(0xD9531E)
    static let fireCore = rgb(0xFFE27A)

    static let spark = rgb(0xFFD24A)
    static let sparkHot = rgb(0xFFF6D0)
    static let blood = rgb(0xC0392B)

    /// Light comes from the upper left, so the shadow is the sliver left over when the
    /// shape is filled once in shade and then again, offset towards the light, in base.
    static func cel(_ ctx: CGContext, _ path: CGPath, base: CGColor, shade: CGColor,
                    light: CGPoint = CGPoint(x: -1.0, y: 1.0)) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setFillColor(shade)
        ctx.fill(path.boundingBox.insetBy(dx: -3, dy: -3))
        ctx.translateBy(x: light.x, y: light.y)
        ctx.addPath(path)
        ctx.setFillColor(base)
        ctx.fillPath()
        ctx.restoreGState()
    }

    static func ink(_ ctx: CGContext, _ path: CGPath, width: CGFloat = 0.95) {
        ctx.addPath(path)
        ctx.setStrokeColor(outline)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    static func shape(_ ctx: CGContext, _ path: CGPath, _ base: CGColor, _ shade: CGColor,
                      width: CGFloat = 0.95, light: CGPoint = CGPoint(x: -1.0, y: 1.0)) {
        cel(ctx, path, base: base, shade: shade, light: light)
        ink(ctx, path, width: width)
    }

    /// Several shapes that should read as one object: ink them all first at double width, then
    /// fill them, so the fills bury the interior seams and only the outer silhouette stays black.
    static func group(_ ctx: CGContext, _ shapes: [(CGPath, CGColor, CGColor)], width: CGFloat = 0.95) {
        for (path, _, _) in shapes { ink(ctx, path, width: width * 2) }
        for (path, base, shade) in shapes { cel(ctx, path, base: base, shade: shade) }
    }

    /// Clips to everything outside `path`, for inking only the part of a shape that clears it.
    static func clipOutside(_ ctx: CGContext, _ path: CGPath) {
        let mask = CGMutablePath()
        mask.addRect(CGRect(x: -200, y: -200, width: 400, height: 400))
        mask.addPath(path)
        ctx.addPath(mask)
        ctx.clip(using: .evenOdd)
    }

    static func flat(_ ctx: CGContext, _ path: CGPath, _ colour: CGColor) {
        ctx.addPath(path)
        ctx.setFillColor(colour)
        ctx.fillPath()
    }

    static func ellipse(_ centre: CGPoint, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: centre.x - w / 2, y: centre.y - h / 2, width: w, height: h), transform: nil)
    }

    /// A limb as one closed, tapering outline with round caps — no seam at the elbow or knee.
    static func limb(_ joints: [CGPoint], _ widths: [CGFloat]) -> CGPath {
        guard joints.count >= 2, joints.count == widths.count else { return CGMutablePath() }
        var normals: [CGPoint] = []
        for i in joints.indices {
            var d = CGPoint.zero
            if i > 0 { d += direction(joints[i - 1], joints[i]) }
            if i < joints.count - 1 { d += direction(joints[i], joints[i + 1]) }
            let n = normalise(d)
            normals.append(CGPoint(x: -n.y, y: n.x))
        }
        let startDirection = direction(joints[0], joints[1])
        let endDirection = direction(joints[joints.count - 2], joints[joints.count - 1])
        let p = CGMutablePath()
        p.move(to: joints[0] + normals[0] * (widths[0] / 2))
        for i in 1..<joints.count { p.addLine(to: joints[i] + normals[i] * (widths[i] / 2)) }
        let endAngle = atan2(endDirection.y, endDirection.x) + .pi / 2
        p.addArc(center: joints[joints.count - 1], radius: widths[widths.count - 1] / 2,
                 startAngle: endAngle, endAngle: endAngle - .pi, clockwise: true)
        for i in stride(from: joints.count - 1, through: 0, by: -1) {
            p.addLine(to: joints[i] - normals[i] * (widths[i] / 2))
        }
        let startAngle = atan2(startDirection.y, startDirection.x) + .pi / 2
        p.addArc(center: joints[0], radius: widths[0] / 2,
                 startAngle: startAngle + .pi, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }

    private static func direction(_ a: CGPoint, _ b: CGPoint) -> CGPoint { normalise(b - a) }

    private static func normalise(_ p: CGPoint) -> CGPoint {
        let l = p.length
        return l > 0.0001 ? CGPoint(x: p.x / l, y: p.y / l) : CGPoint(x: 1, y: 0)
    }
}
