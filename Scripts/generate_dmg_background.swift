//
//  generate_dmg_background.swift
//  Hakoniwa
//
//  Created for Hakoniwa DMG installer background generation.
//  Renders a 100% pure 3D pixel diorama scene using PixelEngine (same perspective as generate_icon.swift).
//  Zero text - pure graphic visual storytelling for dragging Hakoniwa to Applications.
//

import Foundation
import CoreGraphics
import AppKit

func renderPixelDiorama() -> CGImage? {
    let engine = PixelEngine()
    // Vertically align diorama island pedestals with Finder icons
    engine.originY = -12.0
    engine.shadowX = 1.3
    engine.shadowY = -0.16
    
    // Clear buffer to transparent
    engine.pix = [UInt32](repeating: 0x00000000, count: PixelEngine.totalPixels)
    engine.zb = [Float](repeating: -1e9, count: PixelEngine.totalPixels)
    
    // Exact 3D coordinates mathematically mapped to Finder icon centers (175, 175) and (485, 175)
    let leftCenter = SIMD2<Float>(-6.54, 6.54)
    let rightCenter = SIMD2<Float>(6.54, -6.54)
    
    let boxHalf: Float = 3.8
    let baseZ: Float = -1.5
    let soilZ: Float = 0.2
    let grassZ: Float = 0.6
    
    let woodDark = SIMD3<Float>(64, 42, 30)
    let soilDark = SIMD3<Float>(112, 78, 52)
    let grassGreen = SIMD3<Float>(94, 150, 66)
    
    // -------------------------------------------------------------------------
    // 1. LEFT ISLAND (Hakoniwa Starting Terrarium Island)
    // -------------------------------------------------------------------------
    // Solid Wooden Tray
    engine.box(x0: leftCenter.x - boxHalf - 0.45, y0: leftCenter.y - boxHalf - 0.45, z0: baseZ,
               x1: leftCenter.x + boxHalf + 0.45, y1: leftCenter.y + boxHalf + 0.45, z1: -0.2,
               c: woodDark, seed: 18)
    // Earth Soil Substratum
    engine.box(x0: leftCenter.x - boxHalf, y0: leftCenter.y - boxHalf, z0: -0.2,
               x1: leftCenter.x + boxHalf, y1: leftCenter.y + boxHalf, z1: soilZ,
               c: soilDark, seed: 32)
    // Lush Grass Lawn
    engine.box(x0: leftCenter.x - boxHalf, y0: leftCenter.y - boxHalf, z0: soilZ,
               x1: leftCenter.x + boxHalf, y1: leftCenter.y + boxHalf, z1: grassZ,
               c: grassGreen, seed: 50)
               
    // Miniature Bonsai Tree at the back corner of Left Island (peeking out behind app icon)
    let treeX = leftCenter.x - boxHalf * 0.55
    let treeY = leftCenter.y - boxHalf * 0.55
    engine.growTree(x: treeX, y: treeY, scale: 0.85, count: 260, seed: 88)
    engine.drawLeaves(t: 0)
    engine.castShadow(x: treeX, y: treeY, z: 2.2, r: 1.4, strength: 2)
    
    // Iconic Bocce Ball & Jack near the front
    let ballPos = SIMD3<Float>(leftCenter.x + 1.4, leftCenter.y + 1.2, grassZ + 0.45)
    let redBall = SIMD3<Float>(228, 46, 36)
    engine.castShadow(x: ballPos.x, y: ballPos.y, z: ballPos.z, r: 0.5, strength: 2)
    engine.sphere(ballPos.x, ballPos.y, ballPos.z, 0.45, redBall, mode: .gloss)
    
    let jackPos = SIMD3<Float>(leftCenter.x + 0.4, leftCenter.y + 1.8, grassZ + 0.22)
    let goldJack = SIMD3<Float>(252, 214, 62)
    engine.castShadow(x: jackPos.x, y: jackPos.y, z: jackPos.z, r: 0.25, strength: 1)
    engine.sphere(jackPos.x, jackPos.y, jackPos.z, 0.22, goldJack, mode: .gloss)
    
    // Scattered grass tufts
    let tuftColors = [
        SIMD3<Float>(128, 184, 82),
        SIMD3<Float>(106, 160, 74),
        SIMD3<Float>(152, 204, 96)
    ]
    for _ in 0..<35 {
        let gx = Float.random(in: (leftCenter.x - boxHalf + 0.4)...(leftCenter.x + boxHalf - 0.4))
        let gy = Float.random(in: (leftCenter.y - boxHalf + 0.4)...(leftCenter.y + boxHalf - 0.4))
        if hypot(gx - ballPos.x, gy - ballPos.y) < 0.8 { continue }
        if hypot(gx - treeX, gy - treeY) < 1.0 { continue }
        let p = engine.project(gx, gy, grassZ)
        let ix = Int(p.sx)
        let iy = Int(p.sy)
        if ix >= 2 && ix < PixelEngine.W - 2 && iy >= 5 && iy < PixelEngine.H - 2 {
            let h = Int.random(in: 2...4)
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
    
    // -------------------------------------------------------------------------
    // 2. RIGHT ISLAND (Applications Destination Dock)
    // -------------------------------------------------------------------------
    let techDark = SIMD3<Float>(42, 48, 62)
    let techSoil = SIMD3<Float>(52, 62, 82)
    let techBlue = SIMD3<Float>(58, 108, 185)
    let dockRim = SIMD3<Float>(90, 150, 240)
    let dockHollow = SIMD3<Float>(28, 48, 88)
    
    // Tech Base Tray
    engine.box(x0: rightCenter.x - boxHalf - 0.45, y0: rightCenter.y - boxHalf - 0.45, z0: baseZ,
               x1: rightCenter.x + boxHalf + 0.45, y1: rightCenter.y + boxHalf + 0.45, z1: -0.2,
               c: techDark, seed: 24)
    // Tech Sub-layer
    engine.box(x0: rightCenter.x - boxHalf, y0: rightCenter.y - boxHalf, z0: -0.2,
               x1: rightCenter.x + boxHalf, y1: rightCenter.y + boxHalf, z1: soilZ,
               c: techSoil, seed: 38)
    // Dock Surface
    engine.box(x0: rightCenter.x - boxHalf, y0: rightCenter.y - boxHalf, z0: soilZ,
               x1: rightCenter.x + boxHalf, y1: rightCenter.y + boxHalf, z1: grassZ,
               c: techBlue, seed: 62)
               
    // Raised Receptacle / Socket (Visual cue: Drop destination)
    let innerHalf = boxHalf * 0.72
    let slotHalf = boxHalf * 0.50
    engine.box(x0: rightCenter.x - innerHalf, y0: rightCenter.y - innerHalf, z0: grassZ,
               x1: rightCenter.x + innerHalf, y1: rightCenter.y + innerHalf, z1: grassZ + 0.35,
               c: dockRim, seed: 80)
    engine.box(x0: rightCenter.x - slotHalf, y0: rightCenter.y - slotHalf, z0: grassZ,
               x1: rightCenter.x + slotHalf, y1: rightCenter.y + slotHalf, z1: grassZ + 0.36,
               c: dockHollow, seed: 82)
               
    // 4 Corner Docking Brackets
    let pinColor = SIMD3<Float>(130, 205, 255)
    for (px, py) in [
        (rightCenter.x - innerHalf + 0.4, rightCenter.y - innerHalf + 0.4),
        (rightCenter.x + innerHalf - 0.4, rightCenter.y - innerHalf + 0.4),
        (rightCenter.x - innerHalf + 0.4, rightCenter.y + innerHalf - 0.4),
        (rightCenter.x + innerHalf - 0.4, rightCenter.y + innerHalf - 0.4)
    ] {
        engine.box(x0: px - 0.35, y0: py - 0.35, z0: grassZ + 0.35,
                   x1: px + 0.35, y1: py + 0.35, z1: grassZ + 0.75,
                   c: pinColor, seed: 88)
    }
    
    // -------------------------------------------------------------------------
    // 3. CONNECTING BRIDGE & 3D VOXEL INSTALLATION ARROW
    // -------------------------------------------------------------------------
    let stoneColor = SIMD3<Float>(140, 135, 128)
    for step in -3...3 {
        let uVal = Float(step) * 1.55
        let xVal = uVal / 1.4142
        let yVal = -uVal / 1.4142
        engine.box(x0: xVal - 0.75, y0: yVal - 0.75, z0: -0.4,
                   x1: xVal + 0.75, y1: yVal + 0.75, z1: 0.1,
                   c: stoneColor, seed: Float(step + 10))
    }
    
    // Prominent 3D Voxel Arrow pointing Left -> Right
    let arrowColor = SIMD3<Float>(255, 225, 95) // Bright Luminous Gold
    let arrowZ: Float = 0.45
    
    // Arrow Shaft
    for i in 0...5 {
        let uVal = -3.2 + Float(i) * 0.95
        let xVal = uVal / 1.4142
        let yVal = -uVal / 1.4142
        engine.box(x0: xVal - 0.48, y0: yVal - 0.48, z0: arrowZ,
                   x1: xVal + 0.48, y1: yVal + 0.48, z1: arrowZ + 0.55,
                   c: arrowColor, seed: Float(i + 40))
        engine.castShadow(x: xVal, y: yVal, z: arrowZ, r: 0.5, strength: 1)
    }
    
    // Arrowhead Tip
    let headU: Float = 2.6
    let headX = headU / 1.4142
    let headY = -headU / 1.4142
    
    engine.box(x0: headX - 0.65, y0: headY - 0.65, z0: arrowZ,
               x1: headX + 0.65, y1: headY + 0.65, z1: arrowZ + 0.65,
               c: arrowColor, seed: 99)
    engine.castShadow(x: headX, y: headY, z: arrowZ, r: 0.8, strength: 2)
    
    // Arrowhead Wing 1
    let wing1X = headX - 0.95
    let wing1Y = headY + 0.95
    engine.box(x0: wing1X - 0.52, y0: wing1Y - 0.52, z0: arrowZ,
               x1: wing1X + 0.52, y1: wing1Y + 0.52, z1: arrowZ + 0.55,
               c: arrowColor, seed: 98)
    engine.castShadow(x: wing1X, y: wing1Y, z: arrowZ, r: 0.5, strength: 1)
    
    // Arrowhead Wing 2
    let wing2X = headX + 0.95
    let wing2Y = headY - 0.95
    engine.box(x0: wing2X - 0.52, y0: wing2Y - 0.52, z0: arrowZ,
               x1: wing2X + 0.52, y1: wing2Y + 0.52, z1: arrowZ + 0.55,
               c: arrowColor, seed: 97)
    engine.castShadow(x: wing2X, y: wing2Y, z: arrowZ, r: 0.5, strength: 1)
    
    // Mark ground
    for iy in 0..<PixelEngine.H {
        for ix in 0..<PixelEngine.W {
            let i = iy * PixelEngine.W + ix
            if engine.zb[i] > -1e8 {
                engine.ground[i] = 1
                engine.groundZ[i] = engine.zb[i]
            }
        }
    }
    
    // Bake Lighting, Shadows, Ambient Occlusion and Edge Outlines
    engine.flushShadows()
    engine.bakeOcclusion()
    engine.applyShadows(refZ: engine.groundZ)
    engine.shadeEdges()
    
    // Create CGImage
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
    ), let cgImg = ctx.makeImage() else { return nil }
    
    return cgImg
}

func composeDMGBackground() {
    let width: CGFloat = 660
    let height: CGFloat = 440
    
    guard let diorama = renderPixelDiorama() else {
        print("❌ Failed to render diorama")
        return
    }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(width),
        height: Int(height),
        bitsPerComponent: 8,
        bytesPerRow: Int(width) * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create CGContext")
        return
    }
    
    // 1. Dark Minimalist Slate Gradient (#18191d -> #111215)
    let topColor = NSColor(red: 25/255, green: 27/255, blue: 33/255, alpha: 1.0).cgColor
    let bottomColor = NSColor(red: 16/255, green: 17/255, blue: 21/255, alpha: 1.0).cgColor
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: width / 2, y: height), end: CGPoint(x: width / 2, y: 0), options: [])
    }
    
    // 2. Soft Ambient Radial Glow
    if let radialGlow = CGGradient(
        colorsSpace: colorSpace,
        colors: [NSColor(red: 45/255, green: 65/255, blue: 95/255, alpha: 0.18).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        ctx.drawRadialGradient(
            radialGlow,
            startCenter: CGPoint(x: width / 2, y: height * 0.52),
            startRadius: 20,
            endCenter: CGPoint(x: width / 2, y: height * 0.52),
            endRadius: width * 0.46,
            options: []
        )
    }
    
    // 3. Draw 3D Diorama Island Scene directly into 660x440 CGContext
    ctx.saveGState()
    ctx.interpolationQuality = .none // 100% Crisp Retro Pixel Art!
    
    let drawW: CGFloat = 660.0
    let drawH: CGFloat = drawW * (CGFloat(PixelEngine.H) / CGFloat(PixelEngine.W))
    let drawX: CGFloat = 0.0
    let drawY: CGFloat = (height - drawH) / 2.0 // Centered
    
    ctx.draw(diorama, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
    ctx.restoreGState()
    
    // 4. Output 660x440 PNG for exact 1:1 Finder window mapping (NO text)
    guard let finalImg = ctx.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: finalImg)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    
    let projectDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
    let outPath = "\(projectDir)/Scripts/dmg_background.png"
    try? data.write(to: URL(fileURLWithPath: outPath))
    print("✅ 成功生成 3D 像素风箱庭全景 DMG 背景: \(outPath) (660x440, 无文字纯图形指引)")
}

@main
struct BackgroundGeneratorApp {
    static func main() {
        composeDMGBackground()
    }
}
