//
//  MonumentBuilderScene.swift
//  Hakoniwa
//
//  Monument & Cottage Builder Diorama.
//  Keystrokes stack bricks, erect timber beams, lay roof tiles, and light up the chimney.
//

import Foundation
import CoreGraphics
import simd

public final class MonumentBuilderScene: HakoniwaScene {
    public let sceneId = "monument_builder"
    public let sceneName = "微缩建造 (Builder)"
    public let sceneIcon = "hammer.fill"
    public let originY: Float = 22.0
    public let shadowX: Float = 1.3
    public let shadowY: Float = -0.16
    
    // Construction Progress (0 to 500 bricks per building cycle)
    public var bricksPlaced: Int = 45
    private let maxBricks: Int = 300
    
    // Smoke particles from chimney
    private struct SmokePuff {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var radius: Float
        var life: Float
    }
    private var smoke: [SmokePuff] = []
    
    // Dust particles from hammering
    private struct DustParticle {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var life: Float
    }
    private var dust: [DustParticle] = []
    
    // Worker animation timers
    private var time: Float = 0.0
    private var hammerSwing: Float = 0.0
    private var workerJumpTimer: Float = 0.0
    
    public var statusDescription: String {
        let cycle = (bricksPlaced / maxBricks) + 1
        let currentInCycle = bricksPlaced % maxBricks
        let pct = Int((Float(currentInCycle) / Float(maxBricks)) * 100)
        let stageName: String
        if pct < 20 {
            stageName = "铺设石基地 (Foundation)"
        } else if pct < 45 {
            stageName = "立木梁柱 (Timber Framing)"
        } else if pct < 70 {
            stageName = "垒砌砖墙 (Bricklaying)"
        } else if pct < 90 {
            stageName = "盖斜顶瓦 (Roof Tiling)"
        } else {
            stageName = "烟囱炊烟 (Cozy Chimney)"
        }
        return "第\(cycle)座工坊 • 筑砖: \(bricksPlaced) (\(pct)%) • \(stageName)"
    }
    
    public init() {}
    
    // MARK: - Bake Floating Isle Platform
    public func bake(engine: PixelEngine) {
        engine.reset()
        engine.originY = originY
        engine.shadowX = shadowX
        engine.shadowY = shadowY
        
        // 1. Floating Earthy Isle Base (Warm stone and rich soil)
        let grassGreen = SIMD3<Float>(98, 148, 62)
        let rockBrown = SIMD3<Float>(105, 82, 62)
        let darkRock = SIMD3<Float>(72, 54, 42)
        
        // Lower bedrock stratum
        engine.box(x0: -9.5, y0: -7.5, z0: -2.0, x1: 9.5, y1: 7.5, z1: -0.8, c: darkRock)
        engine.box(x0: -10.0, y0: -8.0, z0: -0.8, x1: 10.0, y1: 8.0, z1: 0.0, c: rockBrown)
        // Upper grassy turf
        engine.box(x0: -9.8, y0: -7.8, z0: 0.0, x1: 9.8, y1: 7.8, z1: 0.25, c: grassGreen)
        
        // Decorative paving stones around construction site
        let flagstone = SIMD3<Float>(155, 152, 142)
        engine.box(x0: -7.5, y0: -4.5, z0: 0.25, x1: -5.5, y1: -2.5, z1: 0.30, c: flagstone)
        engine.box(x0: -5.2, y0: -4.0, z0: 0.25, x1: -3.5, y1: -2.8, z1: 0.30, c: flagstone)
        engine.box(x0: 5.5, y0: -2.5, z0: 0.25, x1: 7.5, y1: -0.5, z1: 0.30, c: flagstone)
        
        // Timber stockpile pile
        let logWood = SIMD3<Float>(132, 92, 58)
        engine.capsule(a: SIMD3<Float>(5.8, -5.2, 0.4), b: SIMD3<Float>(8.4, -5.2, 0.4), r0: 0.35, r1: 0.35, colorOf: { _ in logWood })
        engine.capsule(a: SIMD3<Float>(5.8, -4.4, 0.4), b: SIMD3<Float>(8.4, -4.4, 0.4), r0: 0.35, r1: 0.35, colorOf: { _ in logWood })
        engine.capsule(a: SIMD3<Float>(6.2, -4.8, 0.95), b: SIMD3<Float>(8.0, -4.8, 0.95), r0: 0.35, r1: 0.35, colorOf: { _ in logWood })
        
        // Static tree on the left corner
        engine.growTree(x: -7.2, y: 5.0, scale: 0.85, count: 280, seed: 12)
        
        // Bake shadows
        engine.castShadow(x: 0.0, y: 0.0, z: 0.25, r: 4.8, strength: 2)
        engine.castShadow(x: 7.0, y: -4.8, z: 0.25, r: 1.5, strength: 1)
        engine.castShadow(x: -7.2, y: 5.0, z: 0.25, r: 2.2, strength: 2)
        
        engine.applyShadows()
        engine.bakeOcclusion()
        engine.shadeEdges()
        
        for i in 0..<PixelEngine.totalPixels {
            engine.bakedPix[i] = engine.pix[i]
            engine.bakedZ[i] = engine.zb[i]
        }
    }
    
    // MARK: - Update Simulation
    public func update(dt: Float, engine: PixelEngine) {
        time += dt
        
        // Hammer swing damping
        if hammerSwing > 0 {
            hammerSwing = max(0, hammerSwing - dt * 6.0)
        }
        if workerJumpTimer > 0 {
            workerJumpTimer = max(0, workerJumpTimer - dt)
        }
        
        let currentInCycle = bricksPlaced % maxBricks
        let progress = Float(currentInCycle) / Float(maxBricks)
        
        // Chimney smoke when completed or near finish (>85%)
        if progress > 0.85 && Float.random(in: 0...1) < dt * 8.0 {
            let cx: Float = 2.4
            let cy: Float = 2.0
            let cz: Float = 6.8
            smoke.append(SmokePuff(
                pos: SIMD3<Float>(cx + Float.random(in: -0.15...0.15),
                                  cy + Float.random(in: -0.15...0.15),
                                  cz),
                vel: SIMD3<Float>(Float.random(in: -0.15...0.25) + 0.3,
                                  Float.random(in: -0.15...0.15) - 0.1,
                                  Float.random(in: 1.2...2.2)),
                radius: 0.3,
                life: 1.8
            ))
        }
        
        // Update Smoke
        for i in (0..<smoke.count).reversed() {
            smoke[i].pos += smoke[i].vel * dt
            smoke[i].radius += dt * 0.35 // expand puff
            smoke[i].life -= dt
            if smoke[i].life <= 0 {
                smoke.remove(at: i)
            }
        }
        
        // Update Dust Particles
        for i in (0..<dust.count).reversed() {
            dust[i].vel.z -= 12.0 * dt
            dust[i].pos += dust[i].vel * dt
            dust[i].life -= dt
            if dust[i].life <= 0 || dust[i].pos.z < 0.3 {
                dust.remove(at: i)
            }
        }
    }
    
    // MARK: - Draw Dynamic Elements
    public func draw(engine: PixelEngine) {
        engine.restoreBaked()
        
        let currentInCycle = bricksPlaced % maxBricks
        let progress = Float(currentInCycle) / Float(maxBricks)
        
        // 1. Draw The Cottage in its current stage
        drawBuilding(engine: engine, progress: progress)
        
        // 2. Draw Construction Workers
        drawWorkers(engine: engine)
        
        // 3. Draw Particles (Smoke & Dust)
        drawParticles(engine: engine)
        
        engine.flushShadows()
    }
    
    private func drawBuilding(engine: PixelEngine, progress: Float) {
        let stoneFoundation = SIMD3<Float>(135, 138, 142)
        let brickRed = SIMD3<Float>(188, 88, 62)
        let woodTimber = SIMD3<Float>(112, 75, 48)
        let roofTile = SIMD3<Float>(65, 95, 125) // Slate blue roof
        let windowGlass = SIMD3<Float>(255, 235, 140) // Cozy glowing window
        let chimneyStone = SIMD3<Float>(110, 108, 104)
        
        let bx: Float = 0.0
        let by: Float = 0.5
        let halfW: Float = 3.6
        let halfD: Float = 2.8
        
        // Stage 0 (>0%): Solid Stone Base Foundation
        engine.box(x0: bx - halfW, y0: by - halfD, z0: 0.25,
                   x1: bx + halfW, y1: by + halfD, z1: 0.85,
                   c: stoneFoundation)
        
        // Stage 1 (>18%): Timber Corner Posts & Crossbeams
        if progress >= 0.18 {
            let colH: Float = 3.6
            // 4 Corner Wooden Pillars
            let r: Float = 0.28
            engine.capsule(a: SIMD3<Float>(bx - halfW + 0.3, by - halfD + 0.3, 0.85),
                           b: SIMD3<Float>(bx - halfW + 0.3, by - halfD + 0.3, colH), r0: r, r1: r, colorOf: { _ in woodTimber })
            engine.capsule(a: SIMD3<Float>(bx + halfW - 0.3, by - halfD + 0.3, 0.85),
                           b: SIMD3<Float>(bx + halfW - 0.3, by - halfD + 0.3, colH), r0: r, r1: r, colorOf: { _ in woodTimber })
            engine.capsule(a: SIMD3<Float>(bx - halfW + 0.3, by + halfD - 0.3, 0.85),
                           b: SIMD3<Float>(bx - halfW + 0.3, by + halfD - 0.3, colH), r0: r, r1: r, colorOf: { _ in woodTimber })
            engine.capsule(a: SIMD3<Float>(bx + halfW - 0.3, by + halfD - 0.3, 0.85),
                           b: SIMD3<Float>(bx + halfW - 0.3, by + halfD - 0.3, colH), r0: r, r1: r, colorOf: { _ in woodTimber })
            
            // Top crossbeam frame
            engine.capsule(a: SIMD3<Float>(bx - halfW + 0.3, by - halfD + 0.3, colH),
                           b: SIMD3<Float>(bx + halfW - 0.3, by - halfD + 0.3, colH), r0: r, r1: r, colorOf: { _ in woodTimber })
            engine.capsule(a: SIMD3<Float>(bx - halfW + 0.3, by + halfD - 0.3, colH),
                           b: SIMD3<Float>(bx + halfW - 0.3, by + halfD - 0.3, colH), r0: r, r1: r, colorOf: { _ in woodTimber })
        }
        
        // Stage 2 (>38%): Red Brick Walls & Front Door / Window
        if progress >= 0.38 {
            let wallZ1: Float = 0.85 + min(2.75, (progress - 0.38) / 0.28 * 2.75)
            // Left Wall
            engine.box(x0: bx - halfW + 0.2, y0: by - halfD + 0.2, z0: 0.85,
                       x1: bx - halfW + 0.6, y1: by + halfD - 0.2, z1: wallZ1,
                       c: brickRed)
            // Back Wall
            engine.box(x0: bx - halfW + 0.2, y0: by + halfD - 0.6, z0: 0.85,
                       x1: bx + halfW - 0.2, y1: by + halfD - 0.2, z1: wallZ1,
                       c: brickRed)
            // Right Wall
            engine.box(x0: bx + halfW - 0.6, y0: by - halfD + 0.2, z0: 0.85,
                       x1: bx + halfW - 0.2, y1: by + halfD - 0.2, z1: wallZ1,
                       c: brickRed)
            // Front Wall with Doorway
            engine.box(x0: bx - halfW + 0.2, y0: by - halfD + 0.2, z0: 0.85,
                       x1: bx - 0.7, y1: by - halfD + 0.6, z1: wallZ1,
                       c: brickRed)
            engine.box(x0: bx + 0.7, y0: by - halfD + 0.2, z0: 0.85,
                       x1: bx + halfW - 0.2, y1: by - halfD + 0.6, z1: wallZ1,
                       c: brickRed)
            
            // Lit Window Glass on the side
            if progress > 0.55 {
                engine.box(x0: bx + halfW - 0.55, y0: by - 0.6, z0: 1.8,
                           x1: bx + halfW - 0.15, y1: by + 0.6, z1: 2.8,
                           c: windowGlass)
            }
        }
        
        // Stage 3 (>65%): Pitched Roof Trusses & Blue Tile Shingles
        if progress >= 0.65 {
            let roofScale = min(1.0, (progress - 0.65) / 0.22)
            let apexZ: Float = 3.6 + 1.8 * roofScale
            // Pitched roof canopy
            engine.box(x0: bx - halfW - 0.4, y0: by - halfD - 0.3, z0: 3.5,
                       x1: bx + halfW + 0.4, y1: by + halfD + 0.3, z1: 3.8,
                       c: woodTimber)
            // Roof Slope
            engine.box(x0: bx - halfW - 0.3, y0: by - halfD - 0.2, z0: 3.8,
                       x1: bx + halfW + 0.3, y1: by + halfD + 0.2, z1: apexZ,
                       c: roofTile)
        }
        
        // Stage 4 (>85%): Stone Chimney & Spire Banner
        if progress >= 0.85 {
            let cx: Float = bx + 2.4
            let cy: Float = by + 1.5
            // Chimney stack
            engine.box(x0: cx - 0.5, y0: cy - 0.5, z0: 3.6,
                       x1: cx + 0.5, y1: cy + 0.5, z1: 6.6,
                       c: chimneyStone)
            // Chimney cap rim
            engine.box(x0: cx - 0.65, y0: cy - 0.65, z0: 6.6,
                       x1: cx + 0.65, y1: cy + 0.65, z1: 6.85,
                       c: stoneFoundation)
            
            // Rooftop Pennant Banner (fluttering in wind)
            let flagFlutter = sin(time * 8.0) * 0.18
            let flagPoleX: Float = bx - 2.8
            let flagPoleY: Float = by - 0.5
            engine.capsule(a: SIMD3<Float>(flagPoleX, flagPoleY, 5.0),
                           b: SIMD3<Float>(flagPoleX, flagPoleY, 6.8),
                           r0: 0.1, r1: 0.08, colorOf: { _ in woodTimber })
            let goldColor = SIMD3<Float>(255, 205, 55)
            engine.sphere(flagPoleX + 0.4 + flagFlutter, flagPoleY, 6.5, 0.28, goldColor)
        }
        
        // Shadow of the building onto the isle
        engine.castShadow(x: bx + 1.2, y: by + 0.8, z: 0.25, r: 4.2, strength: 2)
    }
    
    private func drawWorkers(engine: PixelEngine) {
        let hardHat = SIMD3<Float>(245, 195, 45) // Safety yellow hat
        let workerSkin = SIMD3<Float>(235, 185, 155)
        let shirtRed = SIMD3<Float>(215, 65, 55)
        let overallsBlue = SIMD3<Float>(45, 95, 175)
        let bootBrown = SIMD3<Float>(65, 45, 35)
        let toolSilver = SIMD3<Float>(200, 205, 215)
        
        let jumpY = (workerJumpTimer > 0) ? abs(sin(workerJumpTimer * 14.0)) * 0.6 : 0.0
        
        // Worker A (Mason with Hammer near the front-left)
        let wA = SIMD3<Float>(-4.2, -1.8, 0.25 + jumpY)
        // Legs
        engine.capsule(a: wA + SIMD3<Float>(-0.2, 0, 0), b: wA + SIMD3<Float>(-0.2, 0, 0.8), r0: 0.2, r1: 0.2, colorOf: { _ in overallsBlue })
        engine.capsule(a: wA + SIMD3<Float>(0.2, 0, 0), b: wA + SIMD3<Float>(0.2, 0, 0.8), r0: 0.2, r1: 0.2, colorOf: { _ in overallsBlue })
        // Torso
        engine.box(x0: wA.x - 0.35, y0: wA.y - 0.25, z0: wA.z + 0.8,
                   x1: wA.x + 0.35, y1: wA.y + 0.25, z1: wA.z + 1.6,
                   c: shirtRed)
        // Head & Hardhat
        engine.sphere(wA.x, wA.y, wA.z + 1.95, 0.32, workerSkin)
        engine.sphere(wA.x, wA.y, wA.z + 2.15, 0.38, hardHat)
        
        // Right Arm wielding Hammer
        let hammerAngle = hammerSwing * 1.5
        let handPos = wA + SIMD3<Float>(0.5, -0.2, 1.4 - hammerAngle * 0.4)
        engine.capsule(a: wA + SIMD3<Float>(0.35, 0, 1.4), b: handPos, r0: 0.14, r1: 0.14, colorOf: { _ in shirtRed })
        // Hammer handle and metal head
        let hammerHead = handPos + SIMD3<Float>(0.3, -0.4, 0.2 - hammerAngle * 0.5)
        engine.capsule(a: handPos, b: hammerHead, r0: 0.08, r1: 0.08, colorOf: { _ in bootBrown })
        engine.box(x0: hammerHead.x - 0.2, y0: hammerHead.y - 0.15, z0: hammerHead.z - 0.15,
                   x1: hammerHead.x + 0.2, y1: hammerHead.y + 0.15, z1: hammerHead.z + 0.15,
                   c: toolSilver)
        
        // Worker B (Pushing Wheelbarrow on the right path)
        let wB = SIMD3<Float>(4.8, 1.5, 0.25 + jumpY)
        engine.capsule(a: wB + SIMD3<Float>(-0.2, 0, 0), b: wB + SIMD3<Float>(-0.2, 0, 0.8), r0: 0.2, r1: 0.2, colorOf: { _ in overallsBlue })
        engine.capsule(a: wB + SIMD3<Float>(0.2, 0, 0), b: wB + SIMD3<Float>(0.2, 0, 0.8), r0: 0.2, r1: 0.2, colorOf: { _ in overallsBlue })
        engine.box(x0: wB.x - 0.35, y0: wB.y - 0.25, z0: wB.z + 0.8,
                   x1: wB.x + 0.35, y1: wB.y + 0.25, z1: wB.z + 1.6,
                   c: SIMD3<Float>(65, 165, 75)) // Green shirt
        engine.sphere(wB.x, wB.y, wB.z + 1.95, 0.32, workerSkin)
        engine.sphere(wB.x, wB.y, wB.z + 2.15, 0.38, hardHat)
        
        // Wheelbarrow in front of Worker B
        let barrowColor = SIMD3<Float>(175, 75, 45)
        engine.box(x0: wB.x - 0.5, y0: wB.y - 1.6, z0: 0.5,
                   x1: wB.x + 0.5, y1: wB.y - 0.6, z1: 1.1,
                   c: barrowColor)
        // Wheel
        engine.sphere(wB.x, wB.y - 1.8, 0.45, 0.35, SIMD3<Float>(45, 45, 45))
        
        // Cast worker shadows
        engine.castShadow(x: wA.x, y: wA.y, z: 0.25, r: 0.8, strength: 1)
        engine.castShadow(x: wB.x, y: wB.y, z: 0.25, r: 0.8, strength: 1)
    }
    
    private func drawParticles(engine: PixelEngine) {
        // Chimney Smoke Puffs (Soft translucent grey/white)
        let smokeColor = SIMD3<Float>(235, 238, 242)
        for p in smoke {
            engine.sphere(p.pos.x, p.pos.y, p.pos.z, p.radius, smokeColor)
        }
        
        // Dust Particles
        let dustColor = SIMD3<Float>(215, 195, 165)
        for d in dust {
            engine.sphere(d.pos.x, d.pos.y, d.pos.z, 0.12, dustColor)
        }
    }
    
    // MARK: - Interactions
    public func handleKeystroke() {
        bricksPlaced += 1
        hammerSwing = 1.0
        
        // Play occasional hammer strike sound
        if bricksPlaced % 3 == 0 {
            SoundManager.shared.play(.hammer)
        }
        
        // Spawn dust puff near construction
        dust.append(DustParticle(
            pos: SIMD3<Float>(-3.8, -1.2, 0.8),
            vel: SIMD3<Float>(Float.random(in: -0.4...0.4), Float.random(in: -0.4...0.4), Float.random(in: 1.0...2.5)),
            life: 0.45
        ))
        
        // Chime when reaching 100% completion!
        if bricksPlaced % maxBricks == 0 {
            SoundManager.shared.play(.bell)
            workerJumpTimer = 1.2
        }
    }
    
    public func handlePointerDown(screenPoint: CGPoint) {
        // Click to add multiple bricks with a hammer strike
        bricksPlaced += 4
        hammerSwing = 1.0
        workerJumpTimer = 0.8
        SoundManager.shared.play(.hammer)
        
        for _ in 0..<3 {
            dust.append(DustParticle(
                pos: SIMD3<Float>(-3.8, -1.2, 0.8),
                vel: SIMD3<Float>(Float.random(in: -0.8...0.8), Float.random(in: -0.8...0.8), Float.random(in: 1.5...3.2)),
                life: 0.55
            ))
        }
    }
    
    public func handlePointerMove(screenPoint: CGPoint) {}
    public func handlePointerUp() {}
    
    public func handleActionKey() {
        // Space / Enter places a power hammer
        handlePointerDown(screenPoint: .zero)
    }
}
