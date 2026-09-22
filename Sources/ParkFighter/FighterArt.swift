import CoreGraphics

/// Turns a pose into a drawn frame. Character space: origin between the feet, y up, facing +x.
enum FighterArt {
    static let canvasWidth: CGFloat = 70
    static let canvasHeight: CGFloat = 94
    static let originX: CGFloat = 31
    static let originY: CGFloat = 4
    /// The photographed head, in character units; about the size of the drawn one.
    private static let photoHeadHeight: CGFloat = 22

    static func render(_ pose: Pose, pixelScale: CGFloat, photoHead: Bool) -> CGImage? {
        let width = max(Int((canvasWidth * pixelScale).rounded()), 1)
        let height = max(Int((canvasHeight * pixelScale).rounded()), 1)
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.scaleBy(x: pixelScale, y: pixelScale)
        ctx.translateBy(x: originX, y: originY)
        draw(ctx, pose, photoHead: photoHead)
        return ctx.makeImage()
    }

    static func draw(_ ctx: CGContext, _ pose: Pose, photoHead: Bool) {
        let backShoulder = pose.shoulder + CGPoint(x: -7.4, y: -2.2)
        let frontShoulder = pose.shoulder + CGPoint(x: 6.5, y: -1.4)

        if pose.onChair { Body.chair(ctx, wobble: pose.chairWobble) }
        let torso = Body.torsoPath(hip: pose.hip, shoulder: pose.shoulder)
        Body.arm(ctx, shoulder: backShoulder, elbow: pose.backElbow, hand: pose.backHand, side: .far)
        Body.sleeve(ctx, shoulder: backShoulder, elbow: pose.backElbow, side: .far, torso: nil)
        Body.leg(ctx, hip: pose.hip + CGPoint(x: -2.5, y: 0), knee: pose.backKnee, ankle: pose.backFoot, side: .far)
        Body.leg(ctx, hip: pose.hip + CGPoint(x: 2.5, y: 0), knee: pose.frontKnee, ankle: pose.frontFoot, side: .near)
        Body.neck(ctx, at: pose.neck)
        Body.torso(ctx, path: torso, hip: pose.hip, shoulder: pose.shoulder)
        if photoHead, let photo = HeadPhoto.image {
            head(ctx, photo: photo, pose: pose, torso: torso)
        } else {
            Head.draw(ctx, at: pose.neck, face: pose.face, tilt: pose.headTilt)
        }
        Body.arm(ctx, shoulder: frontShoulder, elbow: pose.frontElbow, hand: pose.frontHand, side: .near)
        Body.sleeve(ctx, shoulder: frontShoulder, elbow: pose.frontElbow, side: .near, torso: torso)

        switch pose.prop {
        case .none: break
        case .mug: Body.mug(ctx, at: pose.frontHand, steam: pose.propPhase)
        case .phone: Body.phone(ctx, at: lerp(pose.frontHand, pose.backHand, 0.5), tilt: pose.headTilt)
        }
        if pose.vomit > 0 {
            Body.sick(ctx, from: Head.mouth(neck: pose.neck, tilt: pose.headTilt), ground: 0, progress: pose.vomit)
        }
        for s in pose.sparks { Body.spark(ctx, at: s, size: pose.sparkSize) }
    }

    /// The real head, hung on the neck and tucked behind the collar so the cut edge never shows.
    private static func head(_ ctx: CGContext, photo: CGImage, pose: Pose, torso: CGPath) {
        let height = photoHeadHeight
        let width = height * CGFloat(photo.width) / CGFloat(photo.height)
        ctx.saveGState()
        Art.clipOutside(ctx, torso)
        ctx.translateBy(x: pose.neck.x, y: pose.neck.y)
        ctx.rotate(by: pose.headTilt)
        let rect = CGRect(x: -width / 2 + 1.4, y: -1.6, width: width, height: height)
        ctx.interpolationQuality = .high
        ctx.draw(photo, in: rect)
        if pose.face == .sick {
            ctx.setBlendMode(.sourceAtop)
            ctx.setFillColor(CGColor(red: 0.45, green: 0.78, blue: 0.30, alpha: 0.40))
            ctx.fill(rect)
        }
        ctx.restoreGState()
    }
}
