import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import Vision

/// His actual head, cut out of a photograph, for when the drawn one is not him enough.
/// Produced once with `--cut-head photo.jpg Resources/head.png`, then shipped inside the bundle.
enum HeadPhoto {
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ text: String) { description = text }
    }

    /// Loaded once at launch; nil means the drawn head is used.
    static let image: CGImage? = load()

    private static func load() -> CGImage? {
        var candidates: [URL] = []
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--head"), i + 1 < args.count {
            candidates.append(URL(fileURLWithPath: args[i + 1]))
        }
        if let bundled = Bundle.main.url(forResource: "head", withExtension: "png") { candidates.append(bundled) }
        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: args[0])
        candidates.append(executable.deletingLastPathComponent()
            .appendingPathComponent("../../Resources/head.png").standardizedFileURL)
        for url in candidates {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
            return cg
        }
        return nil
    }

    private static func personMaskCovers(_ buffer: CVPixelBuffer, _ head: CGRect, imageHeight: CGFloat) -> Bool {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return false }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let sx = CGFloat(w) / (head.width / head.width * CGFloat(w)) // unit scale placeholder
        _ = sx
        var lit = 0, total = 0
        let x0 = Int(head.minX / (imageHeight / CGFloat(h)) ), x1 = Int(head.maxX / (imageHeight / CGFloat(h)))
        let yTop = Int((imageHeight - head.maxY) / (imageHeight / CGFloat(h)))
        let yBottom = Int((imageHeight - head.minY) / (imageHeight / CGFloat(h)))
        for y in max(yTop, 0)..<min(yBottom, h) {
            for x in max(x0, 0)..<min(x1, w) {
                total += 1
                if bytes[y * stride + x] > 128 { lit += 1 }
            }
        }
        return total > 0 && CGFloat(lit) / CGFloat(total) > 0.15
    }

    /// Flood fill from the border over backdrop-coloured pixels (grey, not dark); everything the
    /// flood cannot reach is the figure. Returns a white-on-black mask in image coordinates.
    private static func keyedMask(_ cg: CGImage, within head: CGRect) throws -> CIImage {
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { throw Failure("no pixel access") }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.assumingMemoryBound(to: UInt8.self)
        func isBackdrop(_ i: Int) -> Bool {
            let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2])
            let hi = max(r, g, b), lo = min(r, g, b)
            return hi > 95 && hi - lo < 34
        }
        var flooded = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        for x in 0..<w { stack.append(x); stack.append((h - 1) * w + x) }
        for y in 0..<h { stack.append(y * w); stack.append(y * w + w - 1) }
        while let i = stack.popLast() {
            guard !flooded[i], isBackdrop(i) else { continue }
            flooded[i] = true
            let x = i % w, y = i / w
            if x > 0 { stack.append(i - 1) }
            if x < w - 1 { stack.append(i + 1) }
            if y > 0 { stack.append(i - w) }
            if y < h - 1 { stack.append(i + w) }
        }
        var maskBytes = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) where !flooded[i] { maskBytes[i] = 255 }
        let provider = CGDataProvider(data: Data(maskBytes) as CFData)!
        guard let maskImage = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                                      provider: provider, decode: nil, shouldInterpolate: false,
                                      intent: .defaultIntent) else { throw Failure("no mask image") }
        return CIImage(cgImage: maskImage)
    }

    /// Finds the face, masks the person out of the background, crops to the head with room for
    /// hair, and wraps it in the same black ink the rest of him is drawn with.
    static func cutOut(photo: URL, to output: URL, faceIndex: Int? = nil) throws {
        guard let source = CGImageSourceCreateWithURL(photo as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw Failure("cannot read \(photo.path)") }

        let faces = VNDetectFaceRectanglesRequest()
        let person = VNGeneratePersonSegmentationRequest()
        person.qualityLevel = .accurate
        person.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([faces, person])
        let found = faces.results ?? []
        // Reading order: top row first, then left to right — so index 0 is the top-left frame of a sheet.
        let ordered = found.sorted {
            let rowA = (1 - $0.boundingBox.midY * 4).rounded(), rowB = (1 - $1.boundingBox.midY * 4).rounded()
            return rowA != rowB ? rowA < rowB : $0.boundingBox.minX < $1.boundingBox.minX
        }
        let picked: VNFaceObservation?
        if let index = faceIndex { picked = index < ordered.count ? ordered[index] : nil }
        else { picked = found.max { $0.boundingBox.width < $1.boundingBox.width } }
        guard let face = picked else { throw Failure("no face \(faceIndex.map(String.init) ?? "") in \(photo.lastPathComponent)") }

        let width = CGFloat(cg.width), height = CGFloat(cg.height)
        let f = VNImageRectForNormalizedRect(face.boundingBox, Int(width), Int(height))
        let head = CGRect(x: f.minX - f.width * 0.45, y: f.minY - f.height * 0.10,
                          width: f.width * 1.9, height: f.height * 1.82)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))

        let image = CIImage(cgImage: cg)
        let mask: CIImage
        if let maskBuffer = person.results?.first?.pixelBuffer, personMaskCovers(maskBuffer, head, imageHeight: height) {
            let rawMask = CIImage(cvPixelBuffer: maskBuffer)
            mask = rawMask.transformed(by: CGAffineTransform(scaleX: width / rawMask.extent.width,
                                                             y: height / rawMask.extent.height))
        } else {
            // An illustration on a checkerboard: the segmenter sees nobody, so key the backdrop
            // out by flooding from the edges — the black ink around the figure stops the flood.
            mask = try keyedMask(cg, within: head)
        }
        let blend = CIFilter.blendWithMask()
        blend.inputImage = image
        blend.backgroundImage = CIImage(color: .clear).cropped(to: image.extent)
        blend.maskImage = mask
        guard let cut = blend.outputImage?.cropped(to: head) else { throw Failure("masking failed") }

        let targetHeight: CGFloat = 480
        let scale = targetHeight / head.height
        let scaled = cut.transformed(by: CGAffineTransform(translationX: -head.minX, y: -head.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = scaled.extent.integral
        let ink = Art.outline.components ?? [0, 0, 0, 1]
        let silhouette = scaled.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: ink[0], y: ink[1], z: ink[2], w: 0),
        ])
        let context = CIContext()
        guard let headImage = context.createCGImage(scaled, from: extent),
              let inkImage = context.createCGImage(silhouette, from: extent) else { throw Failure("rendering failed") }

        let pad: CGFloat = targetHeight * 0.03
        let size = CGSize(width: extent.width + pad * 2, height: extent.height + pad * 2)
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure("no context") }
        ctx.interpolationQuality = .high
        let rect = CGRect(x: pad, y: pad, width: extent.width, height: extent.height)
        for i in 0..<20 {
            let angle = CGFloat(i) / 20 * .pi * 2
            ctx.draw(inkImage, in: rect.offsetBy(dx: cos(angle) * pad, dy: sin(angle) * pad))
        }
        ctx.draw(headImage, in: rect)
        guard let result = ctx.makeImage(),
              let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw Failure("cannot write \(output.path)") }
        CGImageDestinationAddImage(destination, result, nil)
        CGImageDestinationFinalize(destination)
    }
}
