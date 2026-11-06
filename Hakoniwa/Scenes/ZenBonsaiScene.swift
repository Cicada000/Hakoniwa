//
//  ZenBonsaiScene.swift
//  Hakoniwa
//
//  Zen Garden & Bonsai Diorama.
//  Keyboard activity provides water & nutrients for the bonsai tree to sprout, branch, and bloom.
//

import Foundation
import CoreGraphics
import simd

public final class ZenBonsaiScene: HakoniwaScene {
    public let sceneId = "zen_bonsai"
    public let sceneName = "禅意盆景 (Zen Bonsai)"
    public let sceneIcon = "leaf.fill"
    public let originY: Float = 20.0
    public let shadowX: Float = 1.3
    public let shadowY: Float = -0.16
    
    // Dynamic Growth State (0.0 to 1.0)
    public var growth: Float = 0.35
    public var waterLevel: Float = 0.0
    public var rockerAngle: Float = 0.0
    public var rockerVelocity: Float = 0.0
    
    // Falling petals & water particles
    private struct Petal {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var life: Float
        var color: SIMD3<Float>
    }
    private var petals: [Petal] = []
    
    private struct WaterDrop {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var life: Float
    }
    private var drops: [WaterDrop] = []
    
    // Ambient time
    private var time: Float = 0.0
    private var dogWagTimer: Float = 0.0
    private var treeShakeTimer: Float = 0.0
    
    public var statusDescription: String {
        let keys = KeystrokeMonitor.shared.totalKeystrokesToday
        let wpm = Int(KeystrokeMonitor.shared.currentWPM)
        let stageName: String
        if growth < 0.25 {
            stageName = "新芽破土 (Sprouting)"
        } else if growth < 0.55 {
            stageName = "枝繁叶茂 (Growing)"
        } else if growth < 0.85 {
            stageName = "含苞待放 (Budding)"
        } else {
            stageName = "繁花满枝 (Full Bloom)"
        }
        return "今日击键: \(keys) • 速度: \(wpm) WPM • \(stageName)"
    }
    
    public init() {}
    
    // MARK: - Bake Static Environment
    public func bake(engine: PixelEngine) {
        engine.reset()
        engine.originY = originY
        engine.shadowX = shadowX
        engine.shadowY = shadowY
        
        // 1. Zen Stone Pedestal & Garden Platform (Granite grey)
        let stoneColor = SIMD3<Float>(172, 175, 178)
        let darkStone = SIMD3<Float>(115, 118, 122)
        
        // Main island platform
        engine.box(x0: -10.0, y0: -8.0, z0: -1.2,
                   x1: 10.0, y1: 8.0, z1: 0.0,
                   c: stoneColor)
        
        // Darker foundation rim
        engine.box(x0: -10.3, y0: -8.3, z0: -1.6,
                   x1: 10.3, y1: 8.3, z1: -1.2,
                   c: darkStone)
        
        // 2. Ceramic Bonsai Pot (Celadon Greenish Porcelain)
        let potColor = SIMD3<Float>(92, 126, 122)
        let potRimColor = SIMD3<Float>(122, 160, 154)
        let potHalfX: Float = 4.6
        let potHalfY: Float = 3.6
        
        // Pot body
        engine.box(x0: -potHalfX, y0: -potHalfY, z0: 0.0,
                   x1: potHalfX, y1: potHalfY, z1: 1.2,
                   c: potColor)
        // Pot rim (slightly wider)
        engine.box(x0: -potHalfX - 0.25, y0: -potHalfY - 0.25, z0: 1.2,
                   x1: potHalfX + 0.25, y1: potHalfY + 0.25, z1: 1.45,
                   c: potRimColor)
        
        // 3. Rich Cultivated Soil inside pot
        let soilColor = SIMD3<Float>(68, 52, 42)
        engine.box(x0: -potHalfX + 0.35, y0: -potHalfY + 0.35, z0: 1.2,
                   x1: potHalfX - 0.35, y1: potHalfY - 0.35, z1: 1.4,
                   c: soilColor)
        
        // Small decorative pebbles in soil
        let pebbleColor = SIMD3<Float>(185, 182, 175)
        engine.sphere(-2.5, 1.8, 1.45, 0.45, pebbleColor)
        engine.sphere(-2.0, 2.2, 1.45, 0.35, pebbleColor)
        engine.sphere(2.8, -1.5, 1.45, 0.5, pebbleColor)
        
        // 4. Stone Lantern (Tōrō) on the left side
        let lanternStone = SIMD3<Float>(140, 142, 145)
        let lanternGlow = SIMD3<Float>(255, 235, 170)
        // Base & Pillar
        engine.box(x0: -8.2, y0: -4.5, z0: 0.0, x1: -6.6, y1: -2.9, z1: 0.4, c: lanternStone)
        engine.box(x0: -7.8, y0: -4.1, z0: 0.4, x1: -7.0, y1: -3.3, z1: 1.8, c: lanternStone)
        // Firebox chamber (warm light inside)
        engine.box(x0: -8.0, y0: -4.3, z0: 1.8, x1: -6.8, y1: -3.1, z1: 2.5, c: lanternGlow)
        // Lantern Roof / Pagoda cap
        engine.box(x0: -8.5, y0: -4.8, z0: 2.5, x1: -6.3, y1: -2.6, z1: 2.85, c: lanternStone)
        engine.sphere(-7.4, -3.7, 3.0, 0.25, lanternStone)
        
        // 5. Japanese Shishi-odoshi (Bamboo water rocker) base
        let bambooColor = SIMD3<Float>(132, 168, 92)
        let waterBasin = SIMD3<Float>(110, 115, 120)
        // Bamboo vertical stands
        engine.capsule(a: SIMD3<Float>(6.2, 3.2, 0.0), b: SIMD3<Float>(6.2, 3.2, 2.2), r0: 0.22, r1: 0.22, colorOf: { _ in bambooColor })
        engine.capsule(a: SIMD3<Float>(7.2, 3.2, 0.0), b: SIMD3<Float>(7.2, 3.2, 2.2), r0: 0.22, r1: 0.22, colorOf: { _ in bambooColor })
        // Horizontal pivot bar
        engine.capsule(a: SIMD3<Float>(5.8, 3.2, 1.8), b: SIMD3<Float>(7.6, 3.2, 1.8), r0: 0.15, r1: 0.15, colorOf: { _ in bambooColor })
        // Water catch basin stone below
        engine.sphere(6.7, 1.6, 0.35, 0.85, waterBasin)
        
        // Cast static shadows
        engine.castShadow(x: -7.4, y: -3.7, z: 0.0, r: 1.6, strength: 2)
        engine.castShadow(x: 0.0, y: 0.0, z: 0.0, r: 4.8, strength: 2)
        engine.castShadow(x: 6.7, y: 2.5, z: 0.0, r: 1.8, strength: 2)
        
        engine.applyShadows()
        engine.bakeOcclusion()
        engine.shadeEdges()
        
        // Save background
        for i in 0..<PixelEngine.totalPixels {
            engine.bakedPix[i] = engine.pix[i]
            engine.bakedZ[i] = engine.zb[i]
        }
    }
    
    // MARK: - Update Simulation
    public func update(dt: Float, engine: PixelEngine) {
        time += dt
        
        // Synchronize with KeystrokeMonitor
        let monitor = KeystrokeMonitor.shared
        if monitor.isTyping {
            dogWagTimer = 1.5
            // Slow smooth growth with typing
            growth = min(1.0, growth + dt * 0.015 * Float(min(100.0, monitor.currentWPM) / 40.0))
        }
        
        if dogWagTimer > 0 {
            dogWagTimer = max(0, dogWagTimer - dt)
        }
        if treeShakeTimer > 0 {
            treeShakeTimer = max(0, treeShakeTimer - dt)
        }
        
        // 1. Shishi-odoshi Bamboo Rocker Physics
        // Water inflow driven by typing activity (silent when idle)
        if monitor.isTyping {
            waterLevel += dt * 0.45 * Float(min(100.0, monitor.currentWPM) / 35.0)
        }
        
        let targetAngle: Float = (waterLevel >= 1.0) ? 0.65 : -(waterLevel * 0.25)
        let spring: Float = 18.0
        let damping: Float = 6.0
        let force = (targetAngle - rockerAngle) * spring
        rockerVelocity += (force - rockerVelocity * damping) * dt
        rockerAngle += rockerVelocity * dt
        
        // When tilted fully, dump water
        if waterLevel >= 1.0 && rockerAngle > 0.55 {
            waterLevel = 0.0
            rockerVelocity = -4.5 // Knock rebound!
            SoundManager.shared.play(.waterDrop)
            SoundManager.shared.play(.board(amount: 0.7))
            
            // Spawn water splash drops
            for _ in 0..<6 {
                let rx = Float.random(in: -0.5...0.5)
                let ry = Float.random(in: -0.5...0.5)
                drops.append(WaterDrop(
                    pos: SIMD3<Float>(6.7 + rx, 1.6 + ry, 0.45),
                    vel: SIMD3<Float>(rx * 3.0, ry * 3.0, Float.random(in: 2.5...5.0)),
                    life: 0.6
                ))
            }
            
            // Pouring also gives a slight growth boost
            growth = min(1.0, growth + 0.02)
        }
        
        // 2. Update Water Splash Drops
        for i in (0..<drops.count).reversed() {
            drops[i].vel.z -= 18.0 * dt // gravity
            drops[i].pos += drops[i].vel * dt
            drops[i].life -= dt
            if drops[i].life <= 0 || drops[i].pos.z < 0.1 {
                drops.remove(at: i)
            }
        }
        
        // 3. Update Falling Blossom Petals
        for i in (0..<petals.count).reversed() {
            petals[i].pos += petals[i].vel * dt
            // Gentle wind drift
            petals[i].pos.x += sin(time * 3.0 + petals[i].pos.z) * 0.8 * dt
            petals[i].pos.y += cos(time * 2.0 + petals[i].pos.z) * 0.5 * dt
            petals[i].life -= dt
            if petals[i].life <= 0 || petals[i].pos.z < 1.35 {
                petals.remove(at: i)
            }
        }
    }
    
    // MARK: - Draw Dynamic Elements
    public func draw(engine: PixelEngine) {
        engine.restoreBaked()
        
        // 1. Draw Shishi-odoshi Moving Bamboo Pipe
        drawRockerBamboo(engine: engine)
        
        // 2. Draw Growing Bonsai Tree
        drawBonsai(engine: engine)
        
        // 3. Draw Shiba Inu Resting Dog
        drawShibaDog(engine: engine)
        
        // 4. Draw Butterfly (if blooming)
        if growth > 0.6 {
            drawButterfly(engine: engine)
        }
        
        // 5. Draw Particles (water drops & petals)
        drawParticles(engine: engine)
        
        // Flush shadows & highlights
        engine.flushShadows()
    }
    
    private func drawRockerBamboo(engine: PixelEngine) {
        let bambooColor = SIMD3<Float>(145, 185, 102)
        let pivot = SIMD3<Float>(6.7, 3.2, 1.8)
        let length: Float = 2.4
        
        // Compute oriented endpoints based on rockerAngle
        let cosA = cos(rockerAngle)
        let sinA = sin(rockerAngle)
        
        // Front spout (pointing towards water basin at (6.7, 1.6))
        let pFront = pivot + SIMD3<Float>(0.0, -cosA * length * 0.65, sinA * length * 0.65)
        // Back weighted end
        let pBack = pivot + SIMD3<Float>(0.0, cosA * length * 0.35, -sinA * length * 0.35)
        
        engine.capsule(a: pBack, b: pFront, r0: 0.26, r1: 0.22, colorOf: { _ in bambooColor })
        
        // Cast shadow of moving rocker
        engine.castShadow(x: pFront.x, y: pFront.y, z: 0.4, r: 0.5, strength: 1)
    }
    
    private func drawBonsai(engine: PixelEngine) {
        let bark = SIMD3<Float>(78, 54, 38)
        let branchWood = SIMD3<Float>(95, 68, 48)
        
        let shake = (treeShakeTimer > 0) ? sin(time * 28.0) * 0.15 : 0.0
        
        // Trunk Root base (classical sweeping moyogi S-curve)
        let p0 = SIMD3<Float>(0.0, 0.0, 1.35)
        let p1 = SIMD3<Float>(0.45 + shake, -0.25, 2.5)
        let p2 = SIMD3<Float>(-0.55 + shake * 1.5, 0.35, 3.9)
        let p3 = SIMD3<Float>(0.25 + shake * 2.0, 0.15, 5.2)
        
        // Gnarled root flares (nebari 根张)
        engine.capsule(a: p0 + SIMD3<Float>(-0.6, -0.5, -0.1), b: p0, r0: 0.42, r1: 0.65, colorOf: { _ in bark })
        engine.capsule(a: p0 + SIMD3<Float>(0.6, 0.4, -0.1), b: p0, r0: 0.38, r1: 0.65, colorOf: { _ in bark })
        
        // Main Trunk segments
        engine.capsule(a: p0, b: p1, r0: 0.72, r1: 0.55, colorOf: { _ in bark }, mode: .rough)
        engine.capsule(a: p1, b: p2, r0: 0.55, r1: 0.40, colorOf: { _ in bark }, mode: .rough)
        engine.capsule(a: p2, b: p3, r0: 0.40, r1: 0.28, colorOf: { _ in bark }, mode: .rough)
        
        // Stage 1+: Dynamic gnarled branches sprout
        if growth > 0.15 {
            let branchLen = min(1.0, (growth - 0.15) / 0.35)
            // Left cascading branch (悬崖大主枝)
            let bLeft1 = p2 + SIMD3<Float>(-1.4 * branchLen, 0.4 * branchLen, 0.3 * branchLen)
            let bLeftEnd = bLeft1 + SIMD3<Float>(-1.2 * branchLen, 0.3 * branchLen, -0.2 * branchLen)
            engine.capsule(a: p2, b: bLeft1, r0: 0.34, r1: 0.24, colorOf: { _ in branchWood })
            engine.capsule(a: bLeft1, b: bLeftEnd, r0: 0.24, r1: 0.16, colorOf: { _ in branchWood })
            
            // Right welcoming branch (迎客侧枝)
            let bRight1 = p1 + SIMD3<Float>(1.3 * branchLen, -0.6 * branchLen, 0.4 * branchLen)
            let bRightEnd = bRight1 + SIMD3<Float>(0.9 * branchLen, -0.4 * branchLen, 0.2 * branchLen)
            engine.capsule(a: p1, b: bRight1, r0: 0.32, r1: 0.22, colorOf: { _ in branchWood })
            engine.capsule(a: bRight1, b: bRightEnd, r0: 0.22, r1: 0.15, colorOf: { _ in branchWood })
            
            // Rear depth branch (后景出枝)
            let bBackEnd = p2 + SIMD3<Float>(0.5 * branchLen, 1.4 * branchLen, 0.6 * branchLen)
            engine.capsule(a: p2, b: bBackEnd, r0: 0.26, r1: 0.15, colorOf: { _ in branchWood })
            
            // Apex crown branches (树顶分支)
            let bTopLeft = p3 + SIMD3<Float>(-0.6 * branchLen, -0.4 * branchLen, 0.5 * branchLen)
            let bTopRight = p3 + SIMD3<Float>(0.5 * branchLen, 0.4 * branchLen, 0.6 * branchLen)
            engine.capsule(a: p3, b: bTopLeft, r0: 0.24, r1: 0.14, colorOf: { _ in branchWood })
            engine.capsule(a: p3, b: bTopRight, r0: 0.24, r1: 0.14, colorOf: { _ in branchWood })
            
            // Stage 2+: Tiered Pine Cloud Pads (松云云片，无简单大球体！)
            if growth > 0.30 {
                let padScale = min(1.0, (growth - 0.30) / 0.45)
                
                // 1. Apex Crown Cloud Pad (树顶主云片)
                drawPineCloudPad(engine: engine, center: p3 + SIMD3<Float>(0, 0, 0.5), radiusX: 1.5 * padScale, radiusY: 1.2 * padScale, scale: padScale)
                
                // 2. Left Graceful Sweeping Cloud Pad (左侧悬崖大云片)
                drawPineCloudPad(engine: engine, center: bLeftEnd + SIMD3<Float>(0, 0, 0.1), radiusX: 1.7 * padScale, radiusY: 1.3 * padScale, scale: padScale)
                
                // 3. Right Counterbalance Cloud Pad (右侧迎客云片)
                drawPineCloudPad(engine: engine, center: bRightEnd + SIMD3<Float>(0, 0, 0.15), radiusX: 1.4 * padScale, radiusY: 1.1 * padScale, scale: padScale)
                
                // 4. Rear Depth Cloud Pad (后方层次云片)
                drawPineCloudPad(engine: engine, center: bBackEnd + SIMD3<Float>(0, 0, 0.1), radiusX: 1.2 * padScale, radiusY: 1.0 * padScale, scale: padScale)
                
                // Stage 3+: Sakura Blossom Sprigs on Cloud Pads (5-瓣小樱花簇，非大圆球！)
                if growth > 0.60 {
                    let flowerAlpha = min(1.0, (growth - 0.60) / 0.40)
                    drawBlossomSprigs(engine: engine, pApex: p3, bLeft: bLeftEnd, bRight: bRightEnd, bBack: bBackEnd, alpha: flowerAlpha)
                }
            }
        }
        
        // Tree dynamic shadow onto soil
        engine.castShadow(x: p0.x + 0.8, y: p0.y + 0.4, z: 1.35, r: 2.5, strength: 2)
    }
    
    private func drawPineCloudPad(engine: PixelEngine, center: SIMD3<Float>, radiusX: Float, radiusY: Float, scale: Float) {
        guard scale > 0.05 else { return }
        
        let pineDark = SIMD3<Float>(34, 68, 42)      // Deep shade needle underlayer
        let pineMid = SIMD3<Float>(52, 112, 62)      // Rich emerald pine green
        let pineSunlit = SIMD3<Float>(88, 165, 82)   // Top sunlit spring growth
        let pineTip = SIMD3<Float>(122, 195, 102)    // Glowing needle tips
        
        // 1. Under-structure sub-twigs
        let twigColor = SIMD3<Float>(82, 58, 40)
        engine.capsule(a: center - SIMD3<Float>(radiusX * 0.4, 0, 0.12),
                       b: center + SIMD3<Float>(radiusX * 0.4, 0, -0.05),
                       r0: 0.10, r1: 0.08, colorOf: { _ in twigColor })
        
        // 2. Layered horizontal needle steps (dense, flattened fan-pad)
        let steps = 5
        for s in 0..<steps {
            let angle = Float(s) * (Float.pi / Float(steps - 1)) - Float.pi * 0.5
            let dx = cos(angle) * (radiusX * 0.75)
            let dy = sin(angle) * (radiusY * 0.75)
            
            // Base layer: dark deep needles
            engine.capsule(a: center + SIMD3<Float>(dx * 0.3, dy * 0.3, -0.08),
                           b: center + SIMD3<Float>(dx, dy, -0.04),
                           r0: 0.26 * scale, r1: 0.18 * scale,
                           colorOf: { _ in pineDark }, mode: .rough)
        }
        
        // Mid-tier dense foliage cloud
        for s in 0...6 {
            let a = Float(s) * (Float.pi * 2.0 / 7.0)
            let rx = cos(a) * (radiusX * 0.55)
            let ry = sin(a) * (radiusY * 0.55)
            engine.capsule(a: center + SIMD3<Float>(0, 0, 0.02),
                           b: center + SIMD3<Float>(rx, ry, 0.06),
                           r0: 0.28 * scale, r1: 0.20 * scale,
                           colorOf: { _ in pineMid }, mode: .rough)
        }
        
        // Top sunlit needle fringes (feathery flat fan tips)
        for s in 0...8 {
            let a = Float(s) * (Float.pi * 2.0 / 9.0) + 0.2
            let rx = cos(a) * (radiusX * 0.85)
            let ry = sin(a) * (radiusY * 0.85)
            let tip = center + SIMD3<Float>(rx, ry, 0.10)
            engine.capsule(a: center + SIMD3<Float>(rx * 0.4, ry * 0.4, 0.08),
                           b: tip,
                           r0: 0.18 * scale, r1: 0.12 * scale,
                           colorOf: { _ in pineSunlit })
            // Needle tip sparkle
            engine.sphere(tip.x, tip.y, tip.z + 0.02, 0.12 * scale, pineTip)
        }
    }
    
    private func drawBlossomSprigs(engine: PixelEngine, pApex: SIMD3<Float>, bLeft: SIMD3<Float>, bRight: SIMD3<Float>, bBack: SIMD3<Float>, alpha: Float) {
        guard alpha > 0.05 else { return }
        
        let locations = [
            pApex + SIMD3<Float>(-0.35, 0.4, 0.65),
            pApex + SIMD3<Float>(0.45, -0.3, 0.62),
            bLeft + SIMD3<Float>(-0.5, 0.35, 0.25),
            bLeft + SIMD3<Float>(0.3, -0.4, 0.28),
            bRight + SIMD3<Float>(0.4, -0.3, 0.30),
            bBack + SIMD3<Float>(0.2, 0.5, 0.25)
        ]
        
        for loc in locations {
            drawSingleBlossom(engine: engine, at: loc, scale: alpha)
        }
    }
    
    private func drawSingleBlossom(engine: PixelEngine, at: SIMD3<Float>, scale: Float) {
        let petalPink = SIMD3<Float>(255, 195, 215)
        let petalWhite = SIMD3<Float>(255, 245, 250)
        let stamenGold = SIMD3<Float>(255, 225, 75)
        let r: Float = 0.09 * scale
        let petalDist: Float = 0.16 * scale
        
        // Central Golden Stamen Core
        engine.sphere(at.x, at.y, at.z + 0.02, r * 1.1, stamenGold)
        
        // 5 Star-shaped Delicate Petals
        for i in 0..<5 {
            let theta = Float(i) * (2.0 * Float.pi / 5.0)
            let px = at.x + cos(theta) * petalDist
            let py = at.y + sin(theta) * petalDist
            let pz = at.z + sin(Float(i)) * 0.02
            engine.sphere(px, py, pz, r * 1.05, i % 2 == 0 ? petalPink : petalWhite)
        }
    }
    
    private func drawShibaDog(engine: PixelEngine) {
        let shibaGold = SIMD3<Float>(212, 142, 78)
        let shibaWhite = SIMD3<Float>(242, 238, 230)
        let shibaNose = SIMD3<Float>(42, 38, 38)
        
        // Dog resting position on stone beside pot
        let base = SIMD3<Float>(-5.8, 1.8, 0.0)
        let breathe = sin(time * 2.2) * 0.04
        
        // Sleeping Body
        engine.capsule(a: base + SIMD3<Float>(-0.8, -0.4, 0.45 + breathe),
                       b: base + SIMD3<Float>(0.8, 0.4, 0.45 + breathe),
                       r0: 0.65, r1: 0.58, colorOf: { t in
            return t < 0.3 ? shibaWhite : shibaGold
        })
        
        // Head
        let headCenter = base + SIMD3<Float>(1.1, 0.6, 0.85 + breathe * 0.5)
        engine.sphere(headCenter.x, headCenter.y, headCenter.z, 0.48, shibaGold)
        // White muzzle & nose
        engine.sphere(headCenter.x + 0.35, headCenter.y + 0.25, headCenter.z - 0.1, 0.26, shibaWhite)
        engine.sphere(headCenter.x + 0.46, headCenter.y + 0.32, headCenter.z - 0.06, 0.1, shibaNose)
        
        // Pointy Ears
        engine.sphere(headCenter.x - 0.15, headCenter.y + 0.15, headCenter.z + 0.42, 0.16, shibaGold)
        engine.sphere(headCenter.x + 0.15, headCenter.y - 0.15, headCenter.z + 0.42, 0.16, shibaGold)
        
        // Wagging tail
        let tailWag = (dogWagTimer > 0) ? sin(time * 18.0) * 0.4 : sin(time * 1.5) * 0.1
        let tailBase = base + SIMD3<Float>(-1.2, -0.6, 0.55)
        let tailTip = tailBase + SIMD3<Float>(-0.5 + tailWag, -0.3, 0.4)
        engine.capsule(a: tailBase, b: tailTip, r0: 0.22, r1: 0.12, colorOf: { _ in shibaWhite })
        
        // Dog shadow
        engine.castShadow(x: base.x, y: base.y, z: 0.0, r: 1.2, strength: 1)
    }
    
    private func drawButterfly(engine: PixelEngine) {
        let wingSpanFlap = sin(time * 26.0) // Rapid wing flutter (-1 to +1)
        
        // Butterfly 3D flight trajectory: smooth figure-8 loop hovering around the bonsai
        let t = time * 0.9
        let bx = cos(t) * 2.8 + sin(t * 2.0) * 0.6
        let by = sin(t * 1.4) * 2.2
        let bz: Float = 5.6 + sin(time * 3.5) * 0.5 + cos(t * 2.2) * 0.3
        let bPos = SIMD3<Float>(bx, by, bz)
        
        // Velocity tangent vector (heading)
        let dtApprox: Float = 0.05
        let nextT = t + dtApprox * 0.9
        let nextPos = SIMD3<Float>(
            cos(nextT) * 2.8 + sin(nextT * 2.0) * 0.6,
            sin(nextT * 1.4) * 2.2,
            5.6 + sin((time + dtApprox) * 3.5) * 0.5 + cos(nextT * 2.2) * 0.3
        )
        let delta = nextPos - bPos
        let len = length(delta)
        let dir = len > 0.001 ? (delta / len) : SIMD3<Float>(1, 0, 0)
        let worldUp = SIMD3<Float>(0, 0, 1)
        var side = cross(dir, worldUp)
        let sideLen = length(side)
        side = sideLen > 0.001 ? (side / sideLen) : SIMD3<Float>(0, 1, 0)
        let up = cross(side, dir)
        
        // 1. Butterfly Slender Segmented Body
        let bodyDark = SIMD3<Float>(28, 25, 28)
        let thoraxGold = SIMD3<Float>(65, 48, 35)
        
        // Thorax & Head
        let headPos = bPos + dir * 0.22
        let abdomenEnd = bPos - dir * 0.38
        engine.capsule(a: bPos, b: headPos, r0: 0.10, r1: 0.08, colorOf: { _ in thoraxGold })
        engine.capsule(a: abdomenEnd, b: bPos, r0: 0.05, r1: 0.10, colorOf: { _ in bodyDark })
        
        // Forward Antennae (两根微微前曲的触角)
        var antL = headPos
        antL += dir * 0.18
        antL += side * 0.12
        antL += up * 0.08
        
        var antR = headPos
        antR += dir * 0.18
        antR -= side * 0.12
        antR += up * 0.08
        
        engine.capsule(a: headPos, b: antL, r0: 0.03, r1: 0.02, colorOf: { _ in bodyDark })
        engine.capsule(a: headPos, b: antR, r0: 0.03, r1: 0.02, colorOf: { _ in bodyDark })
        
        // 2. Articulated Wings (Two Forewings, Two Hindwings)
        // Flapping kinematics: wings flap upwards and downwards relative to body side axis
        let flapAngle = wingSpanFlap * 0.82 // Up to ~47 degrees
        let cosFlap = cos(flapAngle)
        let sinFlap = sin(flapAngle)
        
        // Left Wing vectors: sweeps along side and rotates up/down
        var leftNormal = side * cosFlap
        leftNormal += up * sinFlap
        
        // Right Wing vectors
        var rightNormal = side * (-cosFlap)
        rightNormal += up * sinFlap
        
        let wingGold = SIMD3<Float>(255, 208, 48)     // Swallowtail rich gold
        let wingAmber = SIMD3<Float>(245, 145, 32)    // Warm amber vein
        let wingBlack = SIMD3<Float>(22, 20, 24)      // Velvet black wing edge
        let eyeBlue = SIMD3<Float>(65, 185, 255)      // Iridescent eye spot
        let eyeRed = SIMD3<Float>(235, 45, 55)
        
        // Draw Left Wing (Forewing & Hindwing)
        drawWingPair(engine: engine, root: bPos + side * 0.06, dir: dir, wingDir: leftNormal,
                     gold: wingGold, amber: wingAmber, black: wingBlack, eyeBlue: eyeBlue, eyeRed: eyeRed)
        
        // Draw Right Wing (Forewing & Hindwing)
        drawWingPair(engine: engine, root: bPos - side * 0.06, dir: dir, wingDir: rightNormal,
                     gold: wingGold, amber: wingAmber, black: wingBlack, eyeBlue: eyeBlue, eyeRed: eyeRed)
    }
    
    private func drawWingPair(engine: PixelEngine, root: SIMD3<Float>, dir: SIMD3<Float>, wingDir: SIMD3<Float>,
                              gold: SIMD3<Float>, amber: SIMD3<Float>, black: SIMD3<Float>, eyeBlue: SIMD3<Float>, eyeRed: SIMD3<Float>) {
        // --- Forewing (Large triangular fanned wing, spans outward & forward) ---
        var fwTip = root
        fwTip += wingDir * 0.72
        fwTip += dir * 0.28
        
        var fwOuter = root
        fwOuter += wingDir * 0.65
        fwOuter -= dir * 0.12
        
        var fwMid = root
        fwMid += wingDir * 0.38
        fwMid += dir * 0.10
        
        // Inner golden wing field
        engine.capsule(a: root, b: fwMid, r0: 0.12, r1: 0.16, colorOf: { _ in gold })
        engine.capsule(a: fwMid, b: fwTip, r0: 0.16, r1: 0.08, colorOf: { _ in amber })
        engine.capsule(a: fwMid, b: fwOuter, r0: 0.15, r1: 0.09, colorOf: { _ in gold })
        
        // Black velvet outer wing margin & edge dots
        engine.capsule(a: fwOuter, b: fwTip, r0: 0.08, r1: 0.06, colorOf: { _ in black })
        engine.sphere(fwTip.x, fwTip.y, fwTip.z, 0.07, black)
        engine.sphere(fwTip.x - wingDir.x * 0.15, fwTip.y - wingDir.y * 0.15, fwTip.z - wingDir.z * 0.15, 0.05, SIMD3<Float>(255, 255, 255))
        
        // --- Hindwing (Scalloped trailing wing with swallowtail tail streamer) ---
        var hwMid = root
        hwMid += wingDir * 0.42
        hwMid -= dir * 0.30
        
        var hwTail = root
        hwTail += wingDir * 0.32
        hwTail -= dir * 0.58 // Extended swallowtail tail
        
        engine.capsule(a: root, b: hwMid, r0: 0.11, r1: 0.14, colorOf: { _ in gold })
        engine.capsule(a: hwMid, b: hwTail, r0: 0.12, r1: 0.05, colorOf: { _ in black })
        
        // Jewel eye-spots (蓝红同心斑纹)
        engine.sphere(hwMid.x, hwMid.y, hwMid.z, 0.07, eyeRed)
        engine.sphere(hwMid.x + wingDir.x * 0.05, hwMid.y + wingDir.y * 0.05, hwMid.z, 0.05, eyeBlue)
    }
    
    private func drawParticles(engine: PixelEngine) {
        // Water drops
        let waterColor = SIMD3<Float>(160, 218, 255)
        for drop in drops {
            engine.sphere(drop.pos.x, drop.pos.y, drop.pos.z, 0.15, waterColor)
        }
        
        // Flower petals
        for petal in petals {
            engine.sphere(petal.pos.x, petal.pos.y, petal.pos.z, 0.14, petal.color)
        }
    }
    
    // MARK: - Interactions
    public func handleKeystroke() {
        waterLevel = min(1.0, waterLevel + 0.12)
        growth = min(1.0, growth + 0.005)
        dogWagTimer = 2.0
    }
    
    public func handlePointerDown(screenPoint: CGPoint) {
        // Clicking tree shakes petals, clicking dog wags tail
        treeShakeTimer = 0.6
        dogWagTimer = 3.0
        SoundManager.shared.play(.whoosh)
        
        // Spawn falling petals if in bloom
        if growth > 0.5 {
            let flowerColor = SIMD3<Float>(255, 185, 205)
            for _ in 0..<4 {
                petals.append(Petal(
                    pos: SIMD3<Float>(Float.random(in: -1.5...1.5), Float.random(in: -1.5...1.5), 5.2),
                    vel: SIMD3<Float>(Float.random(in: -0.8...0.8), Float.random(in: -0.8...0.8), -Float.random(in: 1.0...2.0)),
                    life: 2.5,
                    color: flowerColor
                ))
            }
        }
    }
    
    public func handlePointerMove(screenPoint: CGPoint) {}
    public func handlePointerUp() {}
    
    public func handleActionKey() {
        // Space / Enter manually pours water
        handleKeystroke()
        waterLevel = 1.0 // Instant pour
    }
}
