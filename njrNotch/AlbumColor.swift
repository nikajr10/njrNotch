//
//  AlbumColor.swift
//  njrNotch
//

import AppKit

/// The Spotify tab's automatic accent: the album art's dominant vivid colour, made light enough to read on black.
nonisolated enum AlbumColor {
    /// "#RRGGBB", or nil when the art is greyscale or near-black (the app accent is used then).
    static func vividHex(in imageData: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return drawn ? vivid(rgba: pixels).map(hex) : nil
    }

    /// Pixels are grouped into 12 hue buckets, weighted by saturation × brightness, so a large vivid area wins
    /// over a large grey one. The winning bucket's average colour is lifted until it reads on black.
    static func vivid(rgba pixels: [UInt8]) -> (r: Double, g: Double, b: Double)? {
        var weights = [Double](repeating: 0, count: 12)
        var sums = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: 12)
        var vividCount = 0
        for i in stride(from: 0, to: pixels.count - 3, by: 4) {
            let color = NSColor(srgbRed: Double(pixels[i]) / 255, green: Double(pixels[i + 1]) / 255,
                                blue: Double(pixels[i + 2]) / 255, alpha: 1)
            let saturation = color.saturationComponent, brightness = color.brightnessComponent
            guard saturation > 0.3, brightness > 0.25 else { continue } // greys, near-black
            vividCount += 1
            let bucket = min(Int(color.hueComponent * 12), 11)
            let weight = saturation * brightness
            weights[bucket] += weight
            sums[bucket].r += color.redComponent * weight
            sums[bucket].g += color.greenComponent * weight
            sums[bucket].b += color.blueComponent * weight
        }
        // Under 3% vivid pixels: the art is effectively greyscale.
        guard vividCount * 100 >= pixels.count / 4 * 3,
              let best = weights.indices.max(by: { weights[$0] < weights[$1] }), weights[best] > 0 else { return nil }
        let w = weights[best]
        return readable((sums[best].r / w, sums[best].g / w, sums[best].b / w))
    }

    /// Bright enough for the black notch: brightness at least 0.85, then mixed with white until the
    /// perceived brightness reaches 0.5 (deep blues need this).
    static func readable(_ rgb: (r: Double, g: Double, b: Double)) -> (r: Double, g: Double, b: Double) {
        let color = NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        var lifted = NSColor(hue: color.hueComponent, saturation: min(color.saturationComponent, 0.9),
                             brightness: max(color.brightnessComponent, 0.85), alpha: 1)
        var result = (r: Double(lifted.redComponent), g: Double(lifted.greenComponent), b: Double(lifted.blueComponent))
        while luminance(result) < 0.5 {
            lifted = lifted.blended(withFraction: 0.1, of: .white) ?? .white
            result = (Double(lifted.redComponent), Double(lifted.greenComponent), Double(lifted.blueComponent))
        }
        return result
    }

    static func luminance(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b
    }

    private static func hex(_ rgb: (r: Double, g: Double, b: Double)) -> String {
        let byte = { (x: Double) in Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.r), byte(rgb.g), byte(rgb.b))
    }

    #if DEBUG
    /// Runnable check for the colour picking; called once at launch in debug builds.
    static func selfCheck() {
        let grey = [UInt8](repeating: 128, count: 64 * 4)
        assert(vivid(rgba: grey) == nil, "greyscale art has no accent")
        // Mostly dark grey with a red patch: red wins, and stays red.
        let red = (0..<64).flatMap { $0 < 16 ? [200, 30, 30, 255] : [40, 40, 40, 255] as [UInt8] }
        let picked = vivid(rgba: red)
        assert(picked.map { $0.r > 0.8 && $0.g < 0.5 && $0.b < 0.5 } == true, "red patch gives red")
        // Deep navy is lifted until it reads on black.
        assert(luminance(readable((0.05, 0.05, 0.35))) >= 0.5)
    }
    #endif
}
