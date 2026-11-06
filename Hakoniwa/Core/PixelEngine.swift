//
//  PixelEngine.swift
//  Hakoniwa
//
//  Ported and adapted from `engine.js` in pixel-plays:
//  https://github.com/amirmushichge/pixel-plays
//  Copyright (c) 2026 Amir Mushich
//  Licensed under the MIT License.
//

import Foundation
import simd

public enum SphereMode {
    case normal
    case gloss
    case solid
    case rough
}

public struct CapturedPixel {
    public var ix: Int32
    public var iy: Int32
    public var d: Float
    public var color: UInt32
}

public struct LeafCluster {
    public var x: Float
    public var y: Float
    public var z: Float
    public var k: Float
    public var r: Float
    public var pixels: [CapturedPixel]
}

public struct GrassTuft {
    public var ix: Int
    public var iy: Int
    public var i: Int
    public var height: Int
    public var base: Int
    public var phase: Float
    public var bloom: UInt32
}

public struct FigurePalette {
    public var ball: SIMD3<Float>
    public var shirt: SIMD3<Float>
    public var stripe: SIMD3<Float>
    public var legs: SIMD3<Float>
    public var hair: SIMD3<Float>
    public var skin: SIMD3<Float>
    
    public init(ball: SIMD3<Float>, shirt: SIMD3<Float>, stripe: SIMD3<Float>, legs: SIMD3<Float>, hair: SIMD3<Float>, skin: SIMD3<Float>) {
        self.ball = ball
        self.shirt = shirt
        self.stripe = stripe
        self.legs = legs
        self.hair = hair
        self.skin = skin
    }
}

public struct FigurePose {
    public var yaw: Float = 0
    public var crouch: Float = 0
    public var lean: Float = 0
    public var stance: Float? = nil
    public var armR: Float? = nil
    public var armL: Float? = nil
    public var scale: Float = 1.0
    public var z: Float = 0
    
    public init(yaw: Float = 0, crouch: Float = 0, lean: Float = 0, stance: Float? = nil, armR: Float? = nil, armL: Float? = nil, scale: Float = 1.0, z: Float = 0) {
        self.yaw = yaw
        self.crouch = crouch
        self.lean = lean
        self.stance = stance
        self.armR = armR
        self.armL = armL
        self.scale = scale
        self.z = z
    }
}

public final class PixelEngine {
    public static let W = 360
    public static let H = 280
    public static let S: Float = 10.0
    public static let totalPixels = W * H
    
    public static let SIN: Float = 0.5
    public static let COS: Float = sqrt(3.0) / 2.0
    public static let R2: Float = sqrt(2.0)
    
    public static let BAYER: [Float] = [
        0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5
    ].map { (Float($0) + 0.5) / 16.0 }
    
    public static let COOL = SIMD3<Float>(46, 38, 84)
    public static let WARM = SIMD3<Float>(255, 232, 180)
    public static let SHOE = SIMD3<Float>(226, 222, 212)
    public static let BARK = SIMD3<Float>(92, 74, 60)
    public static let GRASS_COLORS: [SIMD3<Float>] = [
        SIMD3<Float>(34, 62, 50),
        SIMD3<Float>(52, 88, 52),
        SIMD3<Float>(82, 118, 54),
        SIMD3<Float>(124, 146, 62),
        SIMD3<Float>(168, 172, 76)
    ]
    
    public static let GRADIENT_Y: Float = COS / (S * SIN)
    public static let EDGE: Float = 0.28
    public static let KIND_NONE: UInt8 = 0
    public static let KIND_GRASS: UInt8 = 3
    public static let WIND_FPS: Float = 8.0
    
    // Configurable scene camera & shadow offsets
    public var originY: Float = 0 { didSet { updateOrigins() } }
    public var shadowX: Float = 1.3
    public var shadowY: Float = -0.12
    
    public private(set) var OX: Float = Float(W) / 2.0
    public private(set) var OY: Float = Float(H) / 2.0
    
    // Pixel Buffers
    public var pix: [UInt32] = [UInt32](repeating: 0x00000000, count: totalPixels)
    public var zb: [Float] = [Float](repeating: -1e9, count: totalPixels)
    public var bakedPix: [UInt32] = [UInt32](repeating: 0x00000000, count: totalPixels)
    public var bakedZ: [Float] = [Float](repeating: -1e9, count: totalPixels)
    public var ground: [UInt8] = [UInt8](repeating: 0, count: totalPixels)
    public var shadowMask: [UInt8] = [UInt8](repeating: 0, count: totalPixels)
    public var groundZ: [Float] = [Float](repeating: -1e9, count: totalPixels)
    public var kinds: [UInt8] = [UInt8](repeating: 0, count: totalPixels)
    public var staticShadow: [UInt8] = [UInt8](repeating: 0, count: totalPixels)
    
    // Foliage & Wind
    public var tufts: [GrassTuft] = []
    public var leaves: [LeafCluster] = []
    public var pendingShadows: [(a: SIMD3<Float>, r0: Float, b: SIMD3<Float>, r1: Float)] = []
    
    private var captureBuffer: [CapturedPixel]? = nil
    private var rampCache: [Int: [UInt32]] = [:]
    
    public init() {
        updateOrigins()
    }
    
    private func updateOrigins() {
        OX = Float(Self.W) / 2.0
        OY = Float(Self.H) / 2.0 + originY
    }
    
    public func restoreBaked() {
        _ = bakedPix.withUnsafeBufferPointer { bPix in
            pix.withUnsafeMutableBufferPointer { pPix in
                memcpy(pPix.baseAddress!, bPix.baseAddress!, Self.totalPixels * MemoryLayout<UInt32>.size)
            }
        }
        _ = bakedZ.withUnsafeBufferPointer { bZ in
            zb.withUnsafeMutableBufferPointer { pZ in
                memcpy(pZ.baseAddress!, bZ.baseAddress!, Self.totalPixels * MemoryLayout<Float>.size)
            }
        }
    }
    
    @inline(__always)
    public static func rgb(_ r: Float, _ g: Float, _ b: Float) -> UInt32 {
        let ur = UInt32(max(0, min(255, Int32(r + 0.5))))
        let ug = UInt32(max(0, min(255, Int32(g + 0.5))))
        let ub = UInt32(max(0, min(255, Int32(b + 0.5))))
        return 0xFF000000 | (ub << 16) | (ug << 8) | ur
    }
    
    @inline(__always)
    public static func tintPixel(_ p: UInt32, r: Float, g: Float, b: Float) -> UInt32 {
        let cr = Float(p & 0xFF) * r
        let cg = Float((p >> 8) & 0xFF) * g
        let cb = Float((p >> 16) & 0xFF) * b
        return rgb(cr, cg, cb)
    }
    
    @inline(__always)
    public static func bayerAt(_ ix: Int, _ iy: Int) -> Float {
        switch (iy & 3) * 4 + (ix & 3) {
        case 0: return 0.5 / 16.0
        case 1: return 8.5 / 16.0
        case 2: return 2.5 / 16.0
        case 3: return 10.5 / 16.0
        case 4: return 12.5 / 16.0
        case 5: return 4.5 / 16.0
        case 6: return 14.5 / 16.0
        case 7: return 6.5 / 16.0
        case 8: return 3.5 / 16.0
        case 9: return 11.5 / 16.0
        case 10: return 1.5 / 16.0
        case 11: return 9.5 / 16.0
        case 12: return 15.5 / 16.0
        case 13: return 7.5 / 16.0
        case 14: return 13.5 / 16.0
        default: return 5.5 / 16.0
        }
    }
    
    public func rampOf(_ c: SIMD3<Float>) -> [UInt32] {
        let key = (Int(c.x) & 0xFF) | ((Int(c.y) & 0xFF) << 8) | ((Int(c.z) & 0xFF) << 16)
        if let cached = rampCache[key] {
            return cached
        }
        func mixColor(_ m: Float, _ tint: SIMD3<Float>, _ k: Float) -> UInt32 {
            let r = lerp(c.x * m, tint.x, k)
            let g = lerp(c.y * m, tint.y, k)
            let b = lerp(c.z * m, tint.z, k)
            return Self.rgb(r, g, b)
        }
        let ramp = [
            mixColor(0.40, Self.COOL, 0.34),
            mixColor(0.62, Self.COOL, 0.18),
            mixColor(0.84, Self.COOL, 0.05),
            mixColor(1.00, Self.WARM, 0.00),
            mixColor(1.10, Self.WARM, 0.22)
        ]
        rampCache[key] = ramp
        return ramp
    }
    
    @inline(__always)
    public func tint(index: Int, r: Float, g: Float, b: Float) {
        pix[index] = Self.tintPixel(pix[index], r: r, g: g, b: b)
    }
    
    @inline(__always)
    public func project(_ x: Float, _ y: Float, _ z: Float) -> (sx: Float, sy: Float, d: Float) {
        let u = (x - y) / Self.R2
        let v = (x + y) / Self.R2
        let sx = OX + u * Self.S
        let sy = OY + (v * Self.SIN - z * Self.COS) * Self.S
        let d = v * Self.COS + z * Self.SIN
        return (sx, sy, d)
    }
    
    @inline(__always)
    public func unproject(_ sx: Float, _ sy: Float) -> (x: Float, y: Float) {
        let u = (sx - OX) / Self.S
        let v = (sy - OY) / (Self.S * Self.SIN)
        let x = (u + v) / Self.R2
        let y = (v - u) / Self.R2
        return (x, y)
    }
    
    // MARK: - Geometry Primitives
    
    public func sphere(_ x: Float, _ y: Float, _ z: Float, _ r: Float, _ c: SIMD3<Float>, mode: SphereMode = .normal) {
        let ramp = rampOf(c)
        let p = project(x, y, z)
        let rp = max(r * Self.S, 0.75)
        let y0 = max(0, Int(floor(p.sy - rp)))
        let y1 = min(Self.H - 1, Int(ceil(p.sy + rp)))
        let x0 = max(0, Int(floor(p.sx - rp)))
        let x1 = min(Self.W - 1, Int(ceil(p.sx + rp)))
        
        zb.withUnsafeMutableBufferPointer { zbBuf in
            pix.withUnsafeMutableBufferPointer { pixBuf in
                guard let zbPtr = zbBuf.baseAddress, let pixPtr = pixBuf.baseAddress else { return }
                
                var iy = y0
                while iy <= y1 {
                    let rowOffset = iy * Self.W
                    var ix = x0
                    while ix <= x1 {
                        let dx = (Float(ix) + 0.5 - p.sx) / rp
                        let dy = (Float(iy) + 0.5 - p.sy) / rp
                        let nn = dx * dx + dy * dy
                        if nn <= 1.0 {
                            let nz = sqrt(1.0 - nn)
                            let d = p.d + r * nz
                            let i = rowOffset + ix
                            if d > zbPtr[i] {
                                var l = clamp(-0.55 * dx - 0.6 * dy + 0.58 * nz, 0.0, 1.0)
                                if mode == .rough {
                                    l += (hash2D(Float(ix), Float(iy)) - 0.5) * 0.55
                                }
                                if dy > 0.35 {
                                    l = max(l, 0.12 + dy * 0.24) // warm ground bounce
                                }
                                
                                if captureBuffer != nil {
                                    let dither = (Self.bayerAt(ix, iy) - 0.5) * 0.7
                                    let rampIdx = clamp(Int(floor(l * 4.4 + 0.2 + dither)), 0, 4)
                                    captureBuffer?.append(CapturedPixel(ix: Int32(ix), iy: Int32(iy), d: d, color: ramp[rampIdx]))
                                } else {
                                    zbPtr[i] = d
                                    if mode == .gloss && l > 0.9 {
                                        pixPtr[i] = Self.rgb(255, 250, 232)
                                    } else if mode == .solid {
                                        let rampIdx = clamp(Int(floor(l * 4.4 + 0.2)), 1, 4)
                                        pixPtr[i] = ramp[rampIdx]
                                    } else {
                                        let dither = (Self.bayerAt(ix, iy) - 0.5) * 0.7
                                        let rampIdx = clamp(Int(floor(l * 4.4 + 0.2 + dither)), 0, 4)
                                        pixPtr[i] = ramp[rampIdx]
                                    }
                                }
                            }
                        }
                        ix += 1
                    }
                    iy += 1
                }
            }
        }
    }
    
    public func capsule(a: SIMD3<Float>, b: SIMD3<Float>, r0: Float, r1: Float, colorOf: (Float) -> SIMD3<Float>, mode: SphereMode = .normal) {
        let len = distance(a, b)
        let minR = min(r0, r1)
        let n = max(1, Int(ceil(len / (minR * 0.45))))
        for k in 0...n {
            let t = Float(k) / Float(n)
            let z = lerp(a.z, b.z, t)
            let p = mix(a, b, t: t)
            sphere(p.x, p.y, z, lerp(r0, r1, t), colorOf(z), mode: mode)
        }
    }
    
    public func box(x0: Float, y0: Float, z0: Float, x1: Float, y1: Float, z1: Float, c: SIMD3<Float>, seed: Float = 0) {
        let ramp = rampOf(c)
        let paint = { [weak self] (x: Float, y: Float, z: Float, base: Float, grain: Float) in
            guard let self = self else { return }
            let p = self.project(x, y, z)
            let ix = Int(floor(p.sx))
            let iy = Int(floor(p.sy))
            if ix < 0 || iy < 0 || ix >= Self.W || iy >= Self.H { return }
            let i = iy * Self.W + ix
            if p.d <= self.zb[i] { return }
            self.zb[i] = p.d
            let dither = (Self.bayerAt(ix, iy) - 0.5) * 0.5
            let rampIdx = clamp(Int(floor(base + (grain - 0.5) * 1.3 + dither)), 0, 4)
            self.pix[i] = ramp[rampIdx]
        }
        
        let step: Float = 0.045
        let longX = (x1 - x0) >= (y1 - y0)
        
        var a = x0
        while a <= x1 {
            var b = y0
            while b <= y1 {
                let grain = longX ? noise2D(a * 0.8 + seed, b * 9.0) : noise2D(a * 9.0, b * 0.8 + seed)
                paint(a, b, z1, 3.4, grain)
                b += step
            }
            a += step
        }
        
        a = x0
        while a <= x1 {
            var b = z0
            while b <= z1 {
                paint(a, y1, b, 2.3, noise2D(a * 0.8 + seed, b * 9.0))
                b += step
            }
            a += step
        }
        
        a = y0
        while a <= y1 {
            var b = z0
            while b <= z1 {
                paint(x1, a, b, 1.2, noise2D(a * 0.8 + seed, b * 9.0))
                b += step
            }
            a += step
        }
    }
    
    // MARK: - Shadows & Edge Shading
    
    public func castShadow(x: Float, y: Float, z: Float, r: Float, strength: UInt8 = 1, dither: Float = 0.4) {
        let p = project(x + shadowX * z, y + shadowY * z, 0)
        let rx = r * Self.S * 1.05
        let ry = rx * Self.SIN + 1.0
        let y0 = max(0, Int(floor(p.sy - ry)))
        let y1 = min(Self.H - 1, Int(ceil(p.sy + ry)))
        let x0 = max(0, Int(floor(p.sx - rx)))
        let x1 = min(Self.W - 1, Int(ceil(p.sx + rx)))
        
        shadowMask.withUnsafeMutableBufferPointer { smBuf in
            guard let smPtr = smBuf.baseAddress else { return }
            var iy = y0
            while iy <= y1 {
                let rowOffset = iy * Self.W
                var ix = x0
                while ix <= x1 {
                    let dx = (Float(ix) + 0.5 - p.sx) / rx
                    let dy = (Float(iy) + 0.5 - p.sy) / ry
                    if dx * dx + dy * dy + (Self.bayerAt(ix, iy) - 0.5) * dither <= 1.0 {
                        let i = rowOffset + ix
                        if smPtr[i] < strength {
                            smPtr[i] = strength
                        }
                    }
                    ix += 1
                }
                iy += 1
            }
        }
    }
    
    public func applyShadows(refZ: [Float]? = nil) {
        let actualRef = refZ ?? bakedZ
        actualRef.withUnsafeBufferPointer { bzBuf in
            shadowMask.withUnsafeMutableBufferPointer { smBuf in
                ground.withUnsafeBufferPointer { gBuf in
                    zb.withUnsafeBufferPointer { zbBuf in
                        pix.withUnsafeMutableBufferPointer { pixBuf in
                            guard let smPtr = smBuf.baseAddress,
                                  let gPtr = gBuf.baseAddress,
                                  let zbPtr = zbBuf.baseAddress,
                                  let bzPtr = bzBuf.baseAddress,
                                  let pixPtr = pixBuf.baseAddress else { return }
                            
                            var i = 0
                            let total = Self.totalPixels
                            while i < total {
                                let s = smPtr[i]
                                if s != 0 {
                                    smPtr[i] = 0
                                    if gPtr[i] != 0 && zbPtr[i] == bzPtr[i] {
                                        let cur = pixPtr[i]
                                        if s == 1 {
                                            pixPtr[i] = Self.tintPixel(cur, r: 0.54, g: 0.52, b: 0.72)
                                        } else {
                                            pixPtr[i] = Self.tintPixel(cur, r: 0.36, g: 0.34, b: 0.56)
                                        }
                                    }
                                }
                                i += 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func bakeOcclusion() {
        var offsets: [(Int, Int)] = []
        for r in [2, 4] {
            for k in 0..<8 {
                let angle = Float(k) * Float.pi / 4.0
                offsets.append((
                    Int(round(cos(angle) * Float(r))),
                    Int(round(sin(angle) * Float(r) * 0.7))
                ))
            }
        }
        for iy in 4..<(Self.H - 4) {
            let rowOffset = iy * Self.W
            for ix in 4..<(Self.W - 4) {
                let i = rowOffset + ix
                if ground[i] == 0 || zb[i] != groundZ[i] { continue }
                var hits = 0
                for (ox, oy) in offsets {
                    let j = (iy + oy) * Self.W + ix + ox
                    if zb[j] != groundZ[j] { hits += 1 }
                }
                if hits == 0 { continue }
                if hits >= 8 {
                    tint(index: i, r: 0.56, g: 0.54, b: 0.72)
                } else if Float(hits) / 8.0 > Self.bayerAt(ix, iy) {
                    tint(index: i, r: 0.74, g: 0.72, b: 0.84)
                }
            }
        }
    }
    
    public func shadeEdges() {
        zb.withUnsafeBufferPointer { zbBuf in
            groundZ.withUnsafeBufferPointer { gzBuf in
                pix.withUnsafeMutableBufferPointer { pixBuf in
                    guard let zbPtr = zbBuf.baseAddress,
                          let gzPtr = gzBuf.baseAddress,
                          let pixPtr = pixBuf.baseAddress else { return }
                    
                    let w = Self.W
                    let h = Self.H
                    let warmX = Self.WARM.x
                    let warmY = Self.WARM.y
                    let warmZ = Self.WARM.z
                    let gradY = Self.GRADIENT_Y
                    let edge = Self.EDGE
                    
                    var iy = 1
                    var rowOffset = w
                    while iy < h - 1 {
                        var ix = 1
                        while ix < w - 1 {
                            let i = rowOffset + ix
                            let d = zbPtr[i]
                            let gz = gzPtr[i]
                            if d >= -1e8 && d != gz {
                                let a = i - w
                                let b = i + w
                                let c = i - 1
                                let e = i + 1
                                
                                if zbPtr[a] == gzPtr[a] || zbPtr[b] == gzPtr[b] || zbPtr[c] == gzPtr[c] || zbPtr[e] == gzPtr[e] {
                                    pixPtr[i] = Self.tintPixel(pixPtr[i], r: 0.68, g: 0.66, b: 0.76)
                                } else if (d - zbPtr[a] - gradY > edge) || (d - zbPtr[c] > edge) {
                                    let p = pixPtr[i]
                                    let pr = Float(p & 0xFF) * 0.7 + warmX * 0.3
                                    let pg = Float((p >> 8) & 0xFF) * 0.7 + warmY * 0.3
                                    let pb = Float((p >> 16) & 0xFF) * 0.78 + warmZ * 0.22
                                    pixPtr[i] = Self.rgb(pr, pg, pb)
                                } else if (zbPtr[e] - d > edge) || (zbPtr[b] - gradY - d > edge) {
                                    pixPtr[i] = Self.tintPixel(pixPtr[i], r: 0.74, g: 0.72, b: 0.82)
                                }
                            }
                            ix += 1
                        }
                        rowOffset += w
                        iy += 1
                    }
                }
            }
        }
    }
    
    // MARK: - Foliage & Procedural Puppet
    
    public func growGrass() {
        tufts.removeAll()
        for iy in 3..<Self.H {
            let rowOffset = iy * Self.W
            for ix in 0..<Self.W {
                let i = rowOffset + ix
                if kinds[i] != Self.KIND_GRASS || hash2D(Float(ix * 3), Float(iy * 5)) > 0.17 { continue }
                let height = 1 + Int(hash2D(Float(ix), Float(iy * 2)) * 3.0)
                let bloomColor: UInt32 = hash2D(Float(ix * 7), Float(iy)) < 0.022 ?
                    Self.rgb(hash2D(Float(ix), Float(iy)) > 0.5 ? 250 : 240, hash2D(Float(ix), Float(iy)) > 0.5 ? 246 : 200, hash2D(Float(ix), Float(iy)) > 0.5 ? 226 : 84) : 0
                tufts.append(GrassTuft(
                    ix: ix, iy: iy, i: i, height: height,
                    base: Int(round(noise2D(Float(ix) * 0.09, Float(iy) * 0.18) * 2.2)),
                    phase: Float(ix) * 0.11 + Float(iy) * 0.19 + hash2D(Float(ix), Float(iy)) * 0.9,
                    bloom: bloomColor
                ))
            }
        }
    }
    
    public static let tuftLit: [UInt32] = GRASS_COLORS.map { PixelEngine.rgb($0.x, $0.y, $0.z) }
    public static let tuftDark: [UInt32] = GRASS_COLORS.map { PixelEngine.rgb($0.x * 0.54, $0.y * 0.52, $0.z * 0.72) }
    
    public func drawTufts(t: Float) {
        pix.withUnsafeMutableBufferPointer { pixBuf in
            kinds.withUnsafeBufferPointer { kindsBuf in
                zb.withUnsafeBufferPointer { zbBuf in
                    groundZ.withUnsafeBufferPointer { gzBuf in
                        staticShadow.withUnsafeBufferPointer { ssBuf in
                            Self.tuftLit.withUnsafeBufferPointer { litBuf in
                                Self.tuftDark.withUnsafeBufferPointer { darkBuf in
                                    guard let pixPtr = pixBuf.baseAddress,
                                          let kindsPtr = kindsBuf.baseAddress,
                                          let zbPtr = zbBuf.baseAddress,
                                          let gzPtr = gzBuf.baseAddress,
                                          let ssPtr = ssBuf.baseAddress,
                                          let litPtr = litBuf.baseAddress,
                                          let darkPtr = darkBuf.baseAddress else { return }
                                    
                                    for tuft in tufts {
                                        let gust = sin(t * 0.8 + tuft.phase) + 0.5 * sin(t * 2.1 + tuft.phase * 2.3)
                                        let colors = ssPtr[tuft.i] != 0 ? darkPtr : litPtr
                                        var k = 1
                                        let h = tuft.height
                                        while k <= h {
                                            let jx = tuft.ix + Int(round(gust * 0.95 * Float(k) / 3.0))
                                            let jy = tuft.iy - k
                                            if jx >= 0 && jx < Self.W {
                                                let j = jy * Self.W + jx
                                                if (kindsPtr[j] == Self.KIND_GRASS || kindsPtr[j] == Self.KIND_NONE) && zbPtr[j] == gzPtr[j] {
                                                    if tuft.bloom != 0 && k == h {
                                                        pixPtr[j] = tuft.bloom
                                                    } else {
                                                        let idx = clamp(tuft.base + k + (gust > 1.0 ? 1 : 0), 1, 4)
                                                        pixPtr[j] = colors[idx]
                                                    }
                                                }
                                            }
                                            k += 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func growTree(x: Float, y: Float, scale: Float = 1.0, count: Int = 420, seed: Float = 0) {
        let bark = { (_: Float) -> SIMD3<Float> in Self.BARK }
        capsule(a: SIMD3<Float>(x, y, 0), b: SIMD3<Float>(x + 0.3 * scale, y + 0.1 * scale, 2.2 * scale), r0: 0.36 * scale, r1: 0.22 * scale, colorOf: bark, mode: .rough)
        capsule(a: SIMD3<Float>(x + 0.3 * scale, y + 0.1 * scale, 2.2 * scale), b: SIMD3<Float>(x - 0.8 * scale, y - 0.4 * scale, 3.3 * scale), r0: 0.2 * scale, r1: 0.13 * scale, colorOf: bark, mode: .rough)
        capsule(a: SIMD3<Float>(x + 0.3 * scale, y + 0.1 * scale, 2.2 * scale), b: SIMD3<Float>(x + 1.2 * scale, y + 0.4 * scale, 3.4 * scale), r0: 0.2 * scale, r1: 0.13 * scale, colorOf: bark, mode: .rough)
        
        let crowns: [SIMD4<Float>] = [
            SIMD4<Float>(0.1, 0, 3.7, 1.6),
            SIMD4<Float>(-1.4, -0.7, 3.3, 1.2),
            SIMD4<Float>(1.6, 0.7, 3.4, 1.25),
            SIMD4<Float>(-0.6, 1.1, 3.9, 1.1),
            SIMD4<Float>(0.9, -1.1, 4.0, 1.1),
            SIMD4<Float>(0.2, 0.1, 4.9, 1.05)
        ]
        let leafDeep = SIMD3<Float>(58, 84, 62)
        let leafMid = SIMD3<Float>(100, 126, 78)
        let leafSilver = SIMD3<Float>(146, 162, 112)
        
        for n in 0..<count {
            let k = Float(n) + seed
            let c = crowns[n % crowns.count]
            let a = hash2D(k, 7) * 6.2831853
            let tilt = hash2D(k, 8) * 2.0 - 1.0
            let d = cbrt(hash2D(k, 9)) * c.w
            let flat = sqrt(max(0, 1.0 - tilt * tilt))
            let rx = c.x + cos(a) * flat * d
            let ry = c.y + sin(a) * flat * d
            let rz = c.z + tilt * d * 0.8
            let tone = hash2D(k, 10) + (rz - 4.2) * 0.22 + (d / c.w - 0.5) * 0.3
            let leaf = tone > 0.72 ? leafSilver : (tone > 0.3 ? leafMid : leafDeep)
            
            captureBuffer = []
            sphere(x + rx * scale, y + ry * scale, rz * scale, (0.2 + hash2D(k, 11) * 0.22) * scale, leaf, mode: .rough)
            if let recorded = captureBuffer {
                leaves.append(LeafCluster(
                    x: x + rx * scale, y: y + ry * scale, z: rz * scale,
                    k: k, r: 0.42 * scale, pixels: recorded
                ))
            }
            captureBuffer = nil
        }
    }
    
    public func drawLeaves(t: Float) {
        zb.withUnsafeMutableBufferPointer { zbBuf in
            pix.withUnsafeMutableBufferPointer { pixBuf in
                guard let zbPtr = zbBuf.baseAddress, let pixPtr = pixBuf.baseAddress else { return }
                for leaf in leaves {
                    let reach = clamp((leaf.z - 2.5) / 3.0, 0.3, 1.0)
                    let swayX = (sin(t * 0.9 + leaf.x * 0.5 + leaf.z * 0.7) + 0.55 * sin(t * 2.3 + leaf.k * 1.7)) * reach
                    let dx = Int(round(swayX * 0.9))
                    let dy = Int(round(sin(t * 1.3 + leaf.y + leaf.k) * reach * 0.45))
                    
                    for pxItem in leaf.pixels {
                        let ix = Int(pxItem.ix) + dx
                        let iy = Int(pxItem.iy) + dy
                        if ix < 0 || iy < 0 || ix >= Self.W || iy >= Self.H { continue }
                        let i = iy * Self.W + ix
                        if pxItem.d <= zbPtr[i] { continue }
                        zbPtr[i] = pxItem.d
                        pixPtr[i] = pxItem.color
                    }
                    if Int(leaf.k) % 2 == 0 {
                        castShadow(x: leaf.x + swayX * 0.12, y: leaf.y, z: leaf.z, r: leaf.r)
                    }
                }
            }
        }
    }
    
    // MARK: - Procedural Figure
    
    @discardableResult
    public func figure(px: Float, py: Float, yaw: Float, pose: FigurePose, palette: FigurePalette, addBone: (SIMD3<Float>, SIMD3<Float>, Float, Float, @escaping (Float) -> SIMD3<Float>) -> Void) -> SIMD3<Float> {
        let fx = cos(yaw)
        let fy = sin(yaw)
        let sx = -fy
        let sy = fx
        let base = pose.z
        let k = pose.scale
        
        let P = { (a: Float, b: Float, c: Float) -> SIMD3<Float> in
            SIMD3<Float>(
                px + (fx * a + sx * b) * k,
                py + (fy * a + sy * b) * k,
                c * k + base
            )
        }
        func add(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ r0: Float, _ r1: Float, _ f: @escaping (Float) -> SIMD3<Float>) {
            addBone(a, b, r0 * k, r1 * k, f)
        }
        
        let shirt = { (z: Float) -> SIMD3<Float> in
            (Int(floor(z * 3.2)) % 2 != 0) ? palette.shirt : palette.stripe
        }
        let legs = { (_: Float) -> SIMD3<Float> in palette.legs }
        let skin = { (_: Float) -> SIMD3<Float> in palette.skin }
        
        let crouch = pose.crouch
        let lean = pose.lean
        let hipZ: Float = 1.28 - crouch * 0.4
        let hipA: Float = -crouch * 0.15
        let shA: Float = hipA + sin(lean) * 0.95
        let shZ: Float = hipZ + cos(lean) * 0.95
        let neck = P(shA, 0, shZ + 0.08)
        let head = P(shA + sin(lean) * 0.32, 0, shZ + 0.36)
        let stance = pose.stance ?? 0.2
        let footB = P(-stance * 1.2, 0.2, 0.12)
        let footF = P(stance * 2.0, -0.2, 0.12)
        let kneeB = P(-stance * 0.4 + crouch * 0.12, 0.22, 0.68 - crouch * 0.1)
        let kneeF = P(stance * 1.2 + crouch * 0.34, -0.22, 0.72 - crouch * 0.08)
        let hipB = P(hipA, 0.15, hipZ)
        let hipF = P(hipA, -0.15, hipZ)
        
        add(hipB, kneeB, 0.17, 0.13, legs)
        add(kneeB, footB, 0.13, 0.10, legs)
        add(hipF, kneeF, 0.17, 0.13, legs)
        add(kneeF, footF, 0.13, 0.10, legs)
        
        add(footB, P(-stance * 1.2 + 0.16, 0.2, 0.08), 0.10, 0.09) { _ in Self.SHOE }
        add(footF, P(stance * 2.0 + 0.16, -0.2, 0.08), 0.10, 0.09) { _ in Self.SHOE }
        
        add(P(hipA, 0, hipZ), neck, 0.30, 0.32, shirt)
        add(neck, head, 0.11, 0.12, skin)
        
        add(head, head, 0.24, 0.24) { _ in palette.skin }
        add(SIMD3<Float>(head.x - fx * 0.06, head.y - fy * 0.06, head.z + 0.08),
            SIMD3<Float>(head.x - fx * 0.06, head.y - fy * 0.06, head.z + 0.08), 0.205, 0.205) { _ in palette.hair }
        
        let shR = P(shA, 0.36, shZ - 0.03)
        let shL = P(shA, -0.36, shZ - 0.03)
        let armR = pose.armR ?? 0.0
        let armL = pose.armL ?? 0.08
        let elbowR = P(shA + sin(armR) * 0.46, 0.40, shZ - 0.03 - cos(armR) * 0.46)
        let handR = P(shA + sin(armR + 0.18) * 0.95, 0.42, shZ - 0.03 - cos(armR + 0.18) * 0.95)
        let elbowL = P(shA + sin(armL) * 0.46, -0.42, shZ - 0.03 - cos(armL) * 0.46)
        let handL = P(shA + sin(armL + 0.2) * 0.90, -0.43, shZ - 0.03 - cos(armL + 0.2) * 0.90)
        
        add(shR, elbowR, 0.12, 0.10, shirt)
        add(elbowR, handR, 0.09, 0.08, skin)
        add(shL, elbowL, 0.12, 0.10, shirt)
        add(elbowL, handL, 0.09, 0.08, skin)
        
        return handR
    }
    
    public func dynamicAddBone(a: SIMD3<Float>, b: SIMD3<Float>, r0: Float, r1: Float, colorOf: @escaping (Float) -> SIMD3<Float>) {
        capsule(a: a, b: b, r0: r0, r1: r1, colorOf: colorOf, mode: .solid)
        pendingShadows.append((a: a, r0: r0, b: b, r1: r1))
    }
    
    public func flushShadows() {
        for s in pendingShadows {
            let dist = distance(s.a, s.b)
            let n = max(1, Int(ceil(dist / 0.25)))
            for k in 0...n {
                let t = Float(k) / Float(n)
                let p = mix(s.a, s.b, t: t)
                castShadow(x: p.x, y: p.y, z: p.z, r: s.r0 * 0.9, strength: 1, dither: 0)
            }
            if s.a.z < 0.25 {
                castShadow(x: s.a.x, y: s.a.y, z: 0, r: 0.2, strength: 2, dither: 0)
            }
        }
        pendingShadows.removeAll(keepingCapacity: true)
    }
    
    public func drawDots(_ points: [(Float, Float)], color: UInt32) {
        for (sx, sy) in points {
            let ix = Int(floor(sx))
            let iy = Int(floor(sy))
            if ix >= 0 && iy >= 0 && ix < Self.W && iy < Self.H {
                pix[iy * Self.W + ix] = color
            }
        }
    }
}
