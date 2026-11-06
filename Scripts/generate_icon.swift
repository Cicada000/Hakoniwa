//
//  generate_icon.swift
//  Hakoniwa
//

import Foundation
import CoreGraphics
import AppKit

func renderTerrariumDiorama() -> CGImage? {
    let engine = PixelEngine()
    // Position camera to give maximum vertical room for the large terrarium
    engine.originY = 22.0
    engine.shadowX = 1.3
    engine.shadowY = -0.16
    
    // Clear buffer to transparent
    engine.pix = [UInt32](repeating: 0x00000000, count: PixelEngine.totalPixels)
    engine.zb = [Float](repeating: -1e9, count: PixelEngine.totalPixels)
    
    // Terrarium dimensions (Large, filling ~80% of canvas)
    let boxHalf: Float = 4.8
    let soilZ: Float = 0.2
    let grassZ: Float = 0.5
    let glassTopZ: Float = 9.2
    
    // 1. Dark Walnut Beveled Base Tray (solid, rich wood)
    let woodDark = SIMD3<Float>(74, 48, 34)
    engine.box(x0: -boxHalf - 0.55, y0: -boxHalf - 0.55, z0: -1.3,
               x1: boxHalf + 0.55, y1: boxHalf + 0.55, z1: -0.2,
               c: woodDark, seed: 18)
    
    // 2. Earth / Soil Substratum
    let soilDark = SIMD3<Float>(116, 80, 52)
    engine.box(x0: -boxHalf, y0: -boxHalf, z0: -0.2,
               x1: boxHalf, y1: boxHalf, z1: soilZ,
               c: soilDark, seed: 32)
    
    // 3. Lush Turf / Grass Ground
    let grassGreen = SIMD3<Float>(96, 152, 66)
    engine.box(x0: -boxHalf, y0: -boxHalf, z0: soilZ,
               x1: boxHalf, y1: boxHalf, z1: grassZ,
               c: grassGreen, seed: 50)
    
    // Mark ground for shadows
    for iy in 0..<PixelEngine.H {
        for ix in 0..<PixelEngine.W {
            let i = iy * PixelEngine.W + ix
            if engine.zb[i] > -1e8 {
                engine.ground[i] = 1
                engine.groundZ[i] = engine.zb[i]
            }
        }
    }
    
    // 4. Lush Bonsai Tree (Substantial, beautiful foliage)
    engine.growTree(x: -0.9, y: -0.8, scale: 1.38, count: 620, seed: 112)
    engine.drawLeaves(t: 0)
    
    // Cast realistic tree shadows onto grass
    engine.castShadow(x: -0.9, y: -0.8, z: 2.8, r: 2.1, strength: 2)
    engine.castShadow(x: 0.3, y: -0.3, z: 3.6, r: 1.5, strength: 2)
    
    // 5. Iconic Bocce Ball (Glossy Red Orb) - Large, jewel-like
    let redBall = SIMD3<Float>(228, 46, 36)
    let ballPos = SIMD3<Float>(1.8, 1.4, grassZ + 0.65)
    engine.castShadow(x: ballPos.x, y: ballPos.y, z: ballPos.z, r: 0.7, strength: 2)
    engine.sphere(ballPos.x, ballPos.y, ballPos.z, 0.65, redBall, mode: .gloss)
    
    // Tiny golden jack (pallino) near the red ball
    let goldJack = SIMD3<Float>(252, 214, 62)
    let jackPos = SIMD3<Float>(0.5, 2.3, grassZ + 0.30)
    engine.castShadow(x: jackPos.x, y: jackPos.y, z: jackPos.z, r: 0.35, strength: 1)
    engine.sphere(jackPos.x, jackPos.y, jackPos.z, 0.30, goldJack, mode: .gloss)
    
    // 6. Grass tufts scattered on the turf
    let tuftColors = [
        SIMD3<Float>(128, 184, 82),
        SIMD3<Float>(106, 160, 74),
        SIMD3<Float>(152, 204, 96)
    ]
    for _ in 0..<55 {
        let gx = Float.random(in: (-boxHalf + 0.5)...(boxHalf - 0.5))
        let gy = Float.random(in: (-boxHalf + 0.5)...(boxHalf - 0.5))
        if hypot(gx - ballPos.x, gy - ballPos.y) < 1.0 { continue }
        let p = engine.project(gx, gy, grassZ)
        let ix = Int(p.sx)
        let iy = Int(p.sy)
        if ix >= 2 && ix < PixelEngine.W - 2 && iy >= 5 && iy < PixelEngine.H - 2 {
            let h = Int.random(in: 3...5)
            let col = tuftColors.randomElement()!
            for dh in 0..<h {
                let py = iy - dh
                let pi = py * PixelEngine.W + ix
                if p.d >= engine.zb[pi] {
                    engine.zb[pi] = p.d
                    engine.pix[pi] = PixelEngine.rgb(col.x, col.y, col.z)
                }
            }
        }
    }
    
    // Bake Shadows & Ambient Occlusion
    engine.flushShadows()
    engine.bakeOcclusion()
    engine.applyShadows(refZ: engine.groundZ)
    engine.shadeEdges()
    
    // Create CGImage from engine.pix
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    
    var buffer = engine.pix
    guard let ctx = CGContext(
        data: &buffer,
        width: PixelEngine.W,
        height: PixelEngine.H,
        bitsPerComponent: 8,
        bytesPerRow: PixelEngine.W * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ), let fullImage = ctx.makeImage() else { return nil }
    
    // Find exact bounding box of the non-transparent terrarium pixels
    var minX = PixelEngine.W
    var maxX = 0
    var minY = PixelEngine.H
    var maxY = 0
    
    for iy in 0..<PixelEngine.H {
        for ix in 0..<PixelEngine.W {
            let i = iy * PixelEngine.W + ix
            if (engine.pix[i] >> 24) > 10 {
                if ix < minX { minX = ix }
                if ix > maxX { maxX = ix }
                if iy < minY { minY = iy }
                if iy > maxY { maxY = iy }
            }
        }
    }
    
    guard maxX > minX && maxY > minY else { return fullImage }
    
    // In CGImage bitmap coordinate space, row 0 is at top
    let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    return fullImage.cropping(to: cropRect)
}

// -------------------------------------------------------------
// Pixelated Bayer-Dither Shadow Generator (Under Base)
// -------------------------------------------------------------
func renderPixelatedShadow(size: Int, isDark: Bool) -> CGImage? {
    // Generate a dedicated pixelated shadow buffer at 256x256, scaled with nearest-neighbor
    let w = 256
    let h = 256
    var pixels = [UInt32](repeating: 0x00000000, count: w * h)
    
    let cx = Float(w) / 2.0
    let cy = Float(h) / 2.0
    let rx: Float = Float(w) * 0.44
    let ry: Float = rx * 0.52 // isometric angle
    
    // Shadow color in BGRA
    let shadowAlphaMax: Float = isDark ? 0.72 : 0.38
    
    for iy in 0..<h {
        for ix in 0..<w {
            let dx = (Float(ix) + 0.5 - cx) / rx
            let dy = (Float(iy) + 0.5 - cy) / ry
            let distSq = dx * dx + dy * dy
            if distSq >= 1.0 { continue }
            
            let dist = sqrt(distSq)
            // Smooth falloff from center outwards
            let intensity = (1.0 - dist) * shadowAlphaMax
            let bayer = PixelEngine.bayerAt(ix, iy)
            
            if intensity > bayer * 0.95 {
                // Halftone shadow dot
                let a = UInt32(clamp(intensity * 1.3, 0, 1) * 255)
                // Black with dithered alpha
                pixels[iy * w + ix] = (a << 24)
            }
        }
    }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    guard let ctx = CGContext(
        data: &pixels,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else { return nil }
    
    return ctx.makeImage()
}

// -------------------------------------------------------------
// Compose into macOS HIG Squircle Icon (1024x1024)
// -------------------------------------------------------------
func composeMacAppIcon(dioramaImage: CGImage, isDark: Bool, size: CGFloat = 1024) -> NSImage {
    let iconSize = NSSize(width: size, height: size)
    let image = NSImage(size: iconSize)
    
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    ctx.clear(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
    
    // Apple HIG Standard macOS Squircle parameters (for 1024x1024 canvas):
    // Standard icon base tile is 824x824, centered, corner radius ~185
    let margin: CGFloat = 100.0 * (size / 1024.0)
    let tileSide = size - margin * 2.0
    let tileRect = CGRect(x: margin, y: margin, width: tileSide, height: tileSide)
    let cornerRadius = 185.0 * (size / 1024.0)
    
    let squirclePath = CGPath(roundedRect: tileRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // 1. Deep Drop Shadow beneath the tile
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -28.0 * (size / 1024.0)),
        blur: 38.0 * (size / 1024.0),
        color: NSColor.black.withAlphaComponent(isDark ? 0.45 : 0.22).cgColor
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // 2. Secondary soft contact shadow beneath the tile
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -8.0 * (size / 1024.0)),
        blur: 16.0 * (size / 1024.0),
        color: NSColor.black.withAlphaComponent(isDark ? 0.30 : 0.15).cgColor
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // 3. Draw Squircle Tile Base
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if isDark {
        // Dark Obsidian / Slate Tile (#2C2E34 down to #16171A)
        let topColor = NSColor(red: 44/255, green: 46/255, blue: 52/255, alpha: 1.0).cgColor
        let bottomColor = NSColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0).cgColor
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: tileRect.midX, y: tileRect.maxY),
                end: CGPoint(x: tileRect.midX, y: tileRect.minY),
                options: []
            )
        }
        
        // Soft spotlight
        if let radialGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [NSColor.white.withAlphaComponent(0.08).cgColor, NSColor.clear.cgColor] as CFArray,
            locations: [0.0, 1.0]
        ) {
            ctx.drawRadialGradient(
                radialGradient,
                startCenter: CGPoint(x: tileRect.midX, y: tileRect.midY + tileSide * 0.12),
                startRadius: 10,
                endCenter: CGPoint(x: tileRect.midX, y: tileRect.midY + tileSide * 0.12),
                endRadius: tileSide * 0.65,
                options: []
            )
        }
        
        // 1px Rim Highlight
        ctx.addPath(squirclePath)
        ctx.setLineWidth(1.5 * (size / 1024.0))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        ctx.strokePath()
    } else {
        // Light Porcelain / Studio Gray Tile (#FFFFFF down to #E2E4E9)
        let topColor = NSColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0).cgColor
        let bottomColor = NSColor(red: 226/255, green: 228/255, blue: 233/255, alpha: 1.0).cgColor
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: tileRect.midX, y: tileRect.maxY),
                end: CGPoint(x: tileRect.midX, y: tileRect.minY),
                options: []
            )
        }
        
        // Soft ambient rim stroke
        ctx.addPath(squirclePath)
        ctx.setLineWidth(1.5 * (size / 1024.0))
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
        ctx.strokePath()
    }
    
    ctx.restoreGState()
    
    // 4. Calculate Terrarium Geometry: exactly 85% of squircle width, vertically centered
    let targetWidth = tileSide * 0.85
    let scale = targetWidth / CGFloat(dioramaImage.width)
    let drawW = targetWidth
    let drawH = CGFloat(dioramaImage.height) * scale
    
    // Exactly vertically centered on the squircle tile (independent of shadow!)
    let drawX = tileRect.midX - drawW / 2.0
    let drawY = tileRect.midY - drawH / 2.0
    let terrariumRect = CGRect(x: drawX, y: drawY, width: drawW, height: drawH)
    
    // 5. Pixelated Dither Shadow (Positioned low under the base, spilling past the bottom edge)
    if let pixelShadow = renderPixelatedShadow(size: Int(size), isDark: isDark) {
        ctx.saveGState()
        let shadowW = drawW * 0.96
        let shadowH = shadowW * 0.44
        let shadowCenterX = tileRect.midX + (8.0 * (size / 1024.0))
        let shadowCenterY = drawY + (12.0 * (size / 1024.0)) // low, beneath the wooden tray
        let shadowRect = CGRect(x: shadowCenterX - shadowW / 2.0, y: shadowCenterY - shadowH / 2.0, width: shadowW, height: shadowH)
        
        ctx.interpolationQuality = .none // Pixelated halftone!
        ctx.draw(pixelShadow, in: shadowRect)
        ctx.restoreGState()
    }
    
    // 6. Render Terrarium Diorama (Centered and 85% width)
    ctx.saveGState()
    ctx.interpolationQuality = .none // 100% Crisp nearest neighbor
    ctx.draw(dioramaImage, in: terrariumRect)
    ctx.restoreGState()
    
    image.unlockFocus()
    return image
}

// -------------------------------------------------------------
// Main execution
// -------------------------------------------------------------
@main
struct IconGenerator {
    static func main() {
        print("🌿 1. Rendering Large Terrarium Diorama in PixelEngine...")
        guard let diorama = renderTerrariumDiorama() else {
            print("❌ Failed to render diorama")
            exit(1)
        }

        print("🎨 2. Composing Dark Mode App Icon...")
        let darkIcon = composeMacAppIcon(dioramaImage: diorama, isDark: true, size: 1024)

        print("☀️ 3. Composing Light Mode App Icon...")
        let lightIcon = composeMacAppIcon(dioramaImage: diorama, isDark: false, size: 1024)

        func savePNG(image: NSImage, path: String) {
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                print("❌ Failed to encode PNG for \(path)")
                return
            }
            try? png.write(to: URL(fileURLWithPath: path))
            print("✅ Saved: \(path)")
        }

        let scratchDir = "/Users/cicada000/.gemini/antigravity-cli/brain/c9f67942-d476-4781-b19b-d1d8b731897e"
        savePNG(image: darkIcon, path: "\(scratchDir)/icon_preview_dark.png")
        savePNG(image: lightIcon, path: "\(scratchDir)/icon_preview_light.png")

        // 4. Also generate standard icon files for Xcode Assets catalog!
        let appIconDir = "/Users/cicada000/Projects/WebPages/pixel-plays/Hakoniwa/Hakoniwa/Hakoniwa/Assets.xcassets/AppIcon.appiconset"
        
        let sizes: [(String, CGFloat)] = [
            ("app_icon_16.png", 16),
            ("app_icon_16@2x.png", 32),
            ("app_icon_32.png", 32),
            ("app_icon_32@2x.png", 64),
            ("app_icon_128.png", 128),
            ("app_icon_128@2x.png", 256),
            ("app_icon_256.png", 256),
            ("app_icon_256@2x.png", 512),
            ("app_icon_512.png", 512),
            ("app_icon_512@2x.png", 1024)
        ]

        print("📦 4. Exporting AppIcon.appiconset standard sizes...")
        for (filename, sz) in sizes {
            let rendered = composeMacAppIcon(dioramaImage: diorama, isDark: true, size: sz)
            savePNG(image: rendered, path: "\(appIconDir)/\(filename)")
        }
        
        // Also save light version of 1024 and 512 for dynamic Dock switching
        savePNG(image: lightIcon, path: "\(appIconDir)/app_icon_light_1024.png")
        savePNG(image: darkIcon, path: "\(appIconDir)/app_icon_dark_1024.png")
        
        print("🎉 All icons generated successfully!")
    }
}
