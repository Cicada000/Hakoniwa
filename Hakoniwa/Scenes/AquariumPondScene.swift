//
//  AquariumPondScene.swift
//  Hakoniwa
//
//  Zen Aquarium & Koi Pond Diorama.
//  Clear hollow pond basin, floating lily pads, and lively, graceful koi fish.
//  Keystrokes sprinkle fish food flakes; clicking feeds and causes gentle ripples.
//

import Foundation
import CoreGraphics
import simd
import QuartzCore

public final class AquariumPondScene: HakoniwaScene {
    public let sceneId = "aquarium_pond"
    public let sceneName = "浮岛鱼塘 (Aquarium)"
    public let sceneIcon = "drop.fill"
    public let originY: Float = 22.0
    public let shadowX: Float = 1.3
    public let shadowY: Float = -0.16
    
    // Koi Fish Structure
    private struct KoiFish {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var heading: Float
        var bodyColor: SIMD3<Float>
        var spotColor: SIMD3<Float>
        var length: Float
        var tailPhase: Float
        var speed: Float
    }
    private var fishList: [KoiFish] = []
    
    // Food Pellet
    private struct Pellet {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var life: Float
        var color: SIMD3<Float>
    }
    private var pellets: [Pellet] = []
    
    // Water Ripple
    private struct Ripple {
        var x: Float
        var y: Float
        var radius: Float
        var maxRadius: Float
        var alpha: Float
    }
    private var ripples: [Ripple] = []
    
    // Rising Air Bubbles
    private struct Bubble {
        var pos: SIMD3<Float>
        var velZ: Float
        var life: Float
    }
    private var bubbles: [Bubble] = []
    
    private var time: Float = 0.0
    private let pondHalfX: Float = 5.2
    private let pondHalfY: Float = 4.0
    private let waterZ: Float = 0.82
    private let bedZ: Float = 0.20
    private var bubbleSpawnTimer: Float = 0.0
    
    public var statusDescription: String {
        return "水质清澈 • 锦鲤: \(fishList.count) 尾 • 点击水面喂食 • 打字自动撒粮"
    }
    
    public init() {
        setupKoiFish()
    }
    
    private func setupKoiFish() {
        fishList = [
            // Kohaku (White & Scarlet Red)
            KoiFish(pos: SIMD3<Float>(-1.8, 0.6, 0.52), vel: SIMD3<Float>(0.8, 0.3, 0), heading: 0.35,
                    bodyColor: SIMD3<Float>(248, 246, 242), spotColor: SIMD3<Float>(225, 45, 35),
                    length: 1.8, tailPhase: 0, speed: 1.25),
            // Yamabuki Ogon (Golden Yellow)
            KoiFish(pos: SIMD3<Float>(1.2, -0.8, 0.56), vel: SIMD3<Float>(-0.6, 0.6, 0), heading: 2.3,
                    bodyColor: SIMD3<Float>(245, 205, 55), spotColor: SIMD3<Float>(255, 235, 125),
                    length: 1.7, tailPhase: 1.5, speed: 1.15),
            // Taisho Sanke (White, Red, Ink Black)
            KoiFish(pos: SIMD3<Float>(1.8, 1.4, 0.48), vel: SIMD3<Float>(-0.5, -0.6, 0), heading: -2.1,
                    bodyColor: SIMD3<Float>(248, 246, 242), spotColor: SIMD3<Float>(35, 35, 38),
                    length: 1.9, tailPhase: 3.0, speed: 1.3),
            // Showa (Black & Fire Red)
            KoiFish(pos: SIMD3<Float>(-1.0, -1.5, 0.50), vel: SIMD3<Float>(0.7, -0.3, 0), heading: -0.4,
                    bodyColor: SIMD3<Float>(42, 40, 42), spotColor: SIMD3<Float>(225, 55, 45),
                    length: 1.8, tailPhase: 4.5, speed: 1.2),
            // Platinum Ogon (Glistening Silver White)
            KoiFish(pos: SIMD3<Float>(0.0, 0.0, 0.54), vel: SIMD3<Float>(0.4, 0.7, 0), heading: 1.0,
                    bodyColor: SIMD3<Float>(252, 255, 255), spotColor: SIMD3<Float>(200, 225, 245),
                    length: 1.6, tailPhase: 2.2, speed: 1.15)
        ]
    }
    
    // MARK: - Bake Hollow Stone Basin & Sandy Bed
    public func bake(engine: PixelEngine) {
        engine.reset()
        engine.originY = originY
        engine.shadowX = shadowX
        engine.shadowY = shadowY
        
        let stonePond = SIMD3<Float>(132, 138, 145)  // Granite stone rim
        let stoneDark = SIMD3<Float>(105, 110, 116)
        let darkSoil = SIMD3<Float>(88, 68, 52)      // Earthy foundation below
        let sandBed = SIMD3<Float>(225, 215, 192)    // Pale river sand bottom
        let pebbleColor = SIMD3<Float>(155, 148, 138)
        let mossGreen = SIMD3<Float>(72, 118, 58)
        let woodDeck = SIMD3<Float>(96, 68, 48)
        let bambooColor = SIMD3<Float>(115, 145, 68)
        
        let rim: Float = 1.0
        
        // 1. Earthy Substrate Base underneath
        engine.box(x0: -pondHalfX - rim - 0.4, y0: -pondHalfY - rim - 0.4, z0: -1.2,
                   x1: pondHalfX + rim + 0.4, y1: pondHalfY + rim + 0.4, z1: 0.0,
                   c: darkSoil)
        
        // 2. Hollow Sand Bed at the bottom of the basin
        engine.box(x0: -pondHalfX, y0: -pondHalfY, z0: 0.0,
                   x1: pondHalfX, y1: pondHalfY, z1: bedZ,
                   c: sandBed)
        
        // River pebbles and smooth rocks on the sand bed
        engine.sphere(-2.4, -1.4, bedZ + 0.22, 0.42, pebbleColor)
        engine.sphere(-1.9, -1.8, bedZ + 0.18, 0.32, pebbleColor)
        engine.sphere(2.5, 1.4, bedZ + 0.25, 0.48, pebbleColor)
        engine.sphere(2.0, 1.8, bedZ + 0.20, 0.35, mossGreen)
        engine.sphere(0.8, -1.6, bedZ + 0.16, 0.30, pebbleColor)
        engine.sphere(-1.5, 1.6, bedZ + 0.22, 0.38, mossGreen)
        
        // 3. Four Perimeter Rim Walls
        // In isometric projection:
        // Background (top of screen) = -x and -y
        // Foreground (bottom of screen) = +x and +y
        
        // Back Wall (Background, y = -pondHalfY - rim .. -pondHalfY, taller: z1 = 1.35)
        engine.box(x0: -pondHalfX - rim, y0: -pondHalfY - rim, z0: 0.0,
                   x1: pondHalfX + rim, y1: -pondHalfY, z1: 1.35,
                   c: stonePond)
        
        // Left Back Wall (x = -pondHalfX - rim .. -pondHalfX, taller in back: z1 = 1.25)
        engine.box(x0: -pondHalfX - rim, y0: -pondHalfY, z0: 0.0,
                   x1: -pondHalfX, y1: 0.0, z1: 1.25,
                   c: stonePond)
        // Left Front Wall (slopes down toward foreground: z1 = 0.50)
        engine.box(x0: -pondHalfX - rim, y0: 0.0, z0: 0.0,
                   x1: -pondHalfX, y1: pondHalfY + rim, z1: 0.50,
                   c: stonePond)
        
        // Right Back Wall (x = pondHalfX .. pondHalfX + rim, taller in back: z1 = 1.25)
        engine.box(x0: pondHalfX, y0: -pondHalfY, z0: 0.0,
                   x1: pondHalfX + rim, y1: 0.0, z1: 1.25,
                   c: stonePond)
        // Right Front Wall (slopes down toward foreground: z1 = 0.50)
        engine.box(x0: pondHalfX, y0: 0.0, z0: 0.0,
                   x1: pondHalfX + rim, y1: pondHalfY + rim, z1: 0.50,
                   c: stonePond)
        
        // Front Wall (Foreground closest to camera: LOW LIP z1 = 0.45 for 100% clear view into pond!)
        engine.box(x0: -pondHalfX - rim, y0: pondHalfY, z0: 0.0,
                   x1: pondHalfX + rim, y1: pondHalfY + rim, z1: 0.45,
                   c: stoneDark)
        
        // 4. Wooden Viewing Pier & Bamboo Fountain in the back corner (away from camera)
        engine.box(x0: -pondHalfX - rim, y0: -pondHalfY - rim, z0: 1.35,
                   x1: -pondHalfX + 1.6, y1: -pondHalfY + 1.2, z1: 1.55,
                   c: woodDeck)
        
        // Bamboo water spout pouring into the pond from back wall
        engine.capsule(a: SIMD3<Float>(0.0, -pondHalfY - 0.6, 1.45),
                       b: SIMD3<Float>(0.0, -pondHalfY + 0.8, 1.15),
                       r0: 0.16, r1: 0.14,
                       colorOf: { _ in bambooColor })
        
        // 5. Stone Lantern in back-right corner
        let lanternStone = SIMD3<Float>(150, 154, 158)
        let lanternGlow = SIMD3<Float>(255, 235, 145)
        engine.box(x0: pondHalfX - 1.2, y0: -pondHalfY - rim + 0.1, z0: 1.35,
                   x1: pondHalfX + rim - 0.1, y1: -pondHalfY, z1: 1.65,
                   c: lanternStone)
        engine.box(x0: pondHalfX - 0.9, y0: -pondHalfY - rim + 0.3, z0: 1.65,
                   x1: pondHalfX + rim - 0.3, y1: -pondHalfY - 0.2, z1: 2.15,
                   c: lanternGlow)
        engine.box(x0: pondHalfX - 1.3, y0: -pondHalfY - rim, z0: 2.15,
                   x1: pondHalfX + rim, y1: -pondHalfY + 0.1, z1: 2.35,
                   c: lanternStone)
        
        // Bake shadows and edges
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
        
        // 1. Update Food Pellets
        for i in (0..<pellets.count).reversed() {
            pellets[i].pos += pellets[i].vel * dt
            pellets[i].life -= dt
            
            if pellets[i].pos.z > waterZ {
                pellets[i].vel.z = -2.2 // fall through air
            } else {
                pellets[i].vel.z = -0.18 // slowly sink in water
                pellets[i].vel.x *= 0.96
                pellets[i].vel.y *= 0.96
            }
            
            if pellets[i].life <= 0 || pellets[i].pos.z < bedZ + 0.05 {
                pellets.remove(at: i)
            }
        }
        
        // 2. Update Water Ripples
        for i in (0..<ripples.count).reversed() {
            ripples[i].radius += dt * 2.8
            ripples[i].alpha -= dt * 0.75
            if ripples[i].alpha <= 0 || ripples[i].radius >= ripples[i].maxRadius {
                ripples.remove(at: i)
            }
        }
        
        // 3. Periodic Rising Air Bubbles & Water Trickle
        bubbleSpawnTimer += dt
        if bubbleSpawnTimer > 0.45 {
            bubbleSpawnTimer = 0.0
            // Trickle ripple from bamboo spout
            ripples.append(Ripple(x: 0.0, y: -pondHalfY + 0.8, radius: 0.15, maxRadius: 1.6, alpha: 0.85))
            
            // Random rising bubble from pebbles
            let bx = Float.random(in: -pondHalfX + 1.2 ... pondHalfX - 1.2)
            let by = Float.random(in: -pondHalfY + 1.2 ... pondHalfY - 1.2)
            bubbles.append(Bubble(pos: SIMD3<Float>(bx, by, bedZ + 0.05), velZ: Float.random(in: 0.6...1.1), life: 2.5))
        }
        
        for i in (0..<bubbles.count).reversed() {
            bubbles[i].pos.z += bubbles[i].velZ * dt
            bubbles[i].pos.x += sin(time * 3.0 + bubbles[i].pos.z * 5.0) * 0.15 * dt
            bubbles[i].life -= dt
            
            if bubbles[i].pos.z >= waterZ {
                // Pop on water surface
                ripples.append(Ripple(x: bubbles[i].pos.x, y: bubbles[i].pos.y, radius: 0.08, maxRadius: 0.45, alpha: 0.6))
                bubbles.remove(at: i)
            } else if bubbles[i].life <= 0 {
                bubbles.remove(at: i)
            }
        }
        
        // 4. Update Koi Fish AI & Swishing Motion
        let margin: Float = 1.0
        for idx in 0..<fishList.count {
            var fish = fishList[idx]
            fish.tailPhase += dt * (fish.speed * 4.5)
            
            // Check for nearest food pellet
            var targetPos: SIMD3<Float>? = nil
            var nearestDist: Float = 4.5
            for p in pellets {
                let d = hypot(p.pos.x - fish.pos.x, p.pos.y - fish.pos.y)
                if d < nearestDist {
                    nearestDist = d
                    targetPos = p.pos
                }
            }
            
            var desiredHeading = fish.heading
            if let target = targetPos {
                let dx = target.x - fish.pos.x
                let dy = target.y - fish.pos.y
                desiredHeading = atan2(dy, dx)
                fish.speed = min(2.2, fish.speed + dt * 1.5)
                
                // Eat pellet when close
                if nearestDist < 0.45 {
                    if let pIdx = pellets.firstIndex(where: { hypot($0.pos.x - target.x, $0.pos.y - target.y) < 0.2 }) {
                        pellets.remove(at: pIdx)
                        ripples.append(Ripple(x: fish.pos.x, y: fish.pos.y, radius: 0.2, maxRadius: 1.2, alpha: 0.9))
                        SoundManager.shared.play(.bubble)
                    }
                }
            } else {
                // Gentle wandering
                var h = fish.heading
                if fish.pos.x < -pondHalfX + margin { h = 0 }
                else if fish.pos.x > pondHalfX - margin { h = Float.pi }
                if fish.pos.y < -pondHalfY + margin { h = Float.pi * 0.5 }
                else if fish.pos.y > pondHalfY - margin { h = -Float.pi * 0.5 }
                
                h += sin(time * 0.8 + Float(idx) * 2.2) * 0.04
                desiredHeading = h
                fish.speed = max(1.0, fish.speed - dt * 0.5)
            }
            
            let diff = wrapAngle(desiredHeading - fish.heading)
            fish.heading += diff * min(1.0, dt * 3.5)
            
            fish.vel = SIMD3<Float>(cos(fish.heading) * fish.speed, sin(fish.heading) * fish.speed, 0)
            fish.pos += fish.vel * dt
            
            fish.pos.x = max(-pondHalfX + 0.6, min(pondHalfX - 0.6, fish.pos.x))
            fish.pos.y = max(-pondHalfY + 0.6, min(pondHalfY - 0.6, fish.pos.y))
            fish.pos.z = max(bedZ + 0.25, min(waterZ - 0.18, fish.pos.z))
            
            fishList[idx] = fish
        }
    }
    
    private func wrapAngle(_ a: Float) -> Float {
        var angle = a
        while angle > Float.pi { angle -= 2.0 * Float.pi }
        while angle < -Float.pi { angle += 2.0 * Float.pi }
        return angle
    }
    
    // MARK: - Draw Dynamic Elements
    public func draw(engine: PixelEngine) {
        engine.restoreBaked()
        
        // 1. Draw Active Koi Fishes (swimming beneath the water surface)
        for fish in fishList {
            drawFish(engine: engine, fish: fish)
        }
        
        // 2. Draw Food Pellets (sinking)
        for p in pellets {
            engine.sphere(p.pos.x, p.pos.y, p.pos.z, 0.14, p.color)
        }
        
        // 3. Draw Rising Air Bubbles
        let bubbleColor = SIMD3<Float>(215, 245, 255)
        for b in bubbles {
            engine.sphere(b.pos.x, b.pos.y, b.pos.z, 0.10, bubbleColor, mode: .gloss)
        }
        
        // 4. Draw Floating Lily Pads on water surface
        drawLilyPads(engine: engine)
        
        // 5. Draw Water Surface Shimmer & Caustics
        drawWaterShimmer(engine: engine)
        
        // 6. Draw Water Ripples
        drawWaterRipples(engine: engine)
        
        engine.flushShadows()
    }
    
    private func drawFish(engine: PixelEngine, fish: KoiFish) {
        let cosH = cos(fish.heading)
        let sinH = sin(fish.heading)
        let dir = SIMD3<Float>(cosH, sinH, 0)
        let side = SIMD3<Float>(-sinH, cosH, 0)
        
        // Dynamic S-curve spine nodes (5 anatomical vertebrae from head to tail)
        let spineOffsets: [Float] = [
            0.65,   // 0: Snout & Head
            0.20,   // 1: Gill & Shoulder (broadest)
            -0.25,  // 2: Dorsal Midsection
            -0.68,  // 3: Tapered Waist
            -1.05   // 4: Caudal Peduncle & Tail Base
        ]
        
        var spine: [SIMD3<Float>] = []
        for (i, forwardDist) in spineOffsets.enumerated() {
            // Sinusoidal lateral wave along the body
            let waveAmt = (Float(i) / 4.0) * 0.34
            let lateral = sin(fish.tailPhase - Float(i) * 0.85) * waveAmt
            let pt = fish.pos + dir * forwardDist + side * lateral
            spine.append(pt)
        }
        
        // Fish dynamic shadow onto sandy bed below
        engine.castShadow(x: fish.pos.x + 0.25, y: fish.pos.y - 0.15, z: bedZ + 0.05, r: 0.72, strength: 1)
        
        let whiteBase = fish.bodyColor
        let hiSpot = fish.spotColor
        let finColor = SIMD3<Float>(248, 245, 240) // Translucent ivory fin
        let eyeDark = SIMD3<Float>(25, 25, 28)
        
        // 1. Snout & Whisker Barbels (锦鲤标志性触须与口吻)
        let snout = spine[0]
        let snoutTip = snout + dir * 0.22
        engine.capsule(a: snout, b: snoutTip, r0: 0.22, r1: 0.14, colorOf: { _ in whiteBase }, mode: .gloss)
        
        // Barbels (触须)
        var barbelL = snoutTip
        barbelL += dir * 0.08
        barbelL += side * 0.12
        barbelL.z -= 0.04
        
        var barbelR = snoutTip
        barbelR += dir * 0.08
        barbelR -= side * 0.12
        barbelR.z -= 0.04
        
        engine.capsule(a: snoutTip, b: barbelL, r0: 0.04, r1: 0.02, colorOf: { _ in whiteBase })
        engine.capsule(a: snoutTip, b: barbelR, r0: 0.04, r1: 0.02, colorOf: { _ in whiteBase })
        
        // Black Beady Eyes on left and right sides of forehead
        var eyeL = snout
        eyeL += dir * 0.05
        eyeL += side * 0.19
        eyeL.z += 0.06
        
        var eyeR = snout
        eyeR += dir * 0.05
        eyeR -= side * 0.19
        eyeR.z += 0.06
        
        engine.sphere(eyeL.x, eyeL.y, eyeL.z, 0.06, eyeDark, mode: .gloss)
        engine.sphere(eyeR.x, eyeR.y, eyeR.z, 0.06, eyeDark, mode: .gloss)
        
        // 2. Head to Broad Shoulder (宽阔肩部与前胸)
        engine.capsule(a: spine[0], b: spine[1], r0: 0.26, r1: 0.36, colorOf: { _ in hiSpot }, mode: .gloss)
        
        // 3. Shoulder to Dorsal Midsection (背脊中部，主斑纹)
        engine.capsule(a: spine[1], b: spine[2], r0: 0.36, r1: 0.32, colorOf: { _ in whiteBase }, mode: .gloss)
        // Raised Hi / Pattern overlay patch on the back
        let backPatch = (spine[1] + spine[2]) * 0.5 + SIMD3<Float>(0, 0, 0.05)
        engine.sphere(backPatch.x, backPatch.y, backPatch.z, 0.28, hiSpot, mode: .gloss)
        
        // 4. Midsection to Tapered Waist (细长腰身)
        engine.capsule(a: spine[2], b: spine[3], r0: 0.32, r1: 0.22, colorOf: { _ in hiSpot }, mode: .gloss)
        
        // 5. Waist to Caudal Peduncle (尾柄)
        engine.capsule(a: spine[3], b: spine[4], r0: 0.22, r1: 0.12, colorOf: { _ in whiteBase })
        
        // 6. Dorsal Fin (背脊鳍 - 沿背脊隆起的半透明背鳍)
        let dfStart = spine[1] + SIMD3<Float>(0, 0, 0.18)
        let dfEnd = spine[3] + SIMD3<Float>(0, 0, 0.12)
        engine.capsule(a: dfStart, b: dfEnd, r0: 0.06, r1: 0.04, colorOf: { _ in finColor })
        
        // 7. Pectoral Fins (大扇形胸鳍 - 左右随游动节奏划水)
        let finPaddle = sin(fish.tailPhase * 1.1) * 0.12
        var leftFinRoot = spine[1]
        leftFinRoot += side * 0.28
        leftFinRoot -= dir * 0.08
        
        var leftFinTip = leftFinRoot
        leftFinTip += side * 0.45
        leftFinTip -= dir * 0.25
        leftFinTip.z += finPaddle
        
        var leftFinMid = leftFinRoot
        leftFinMid += side * 0.35
        leftFinMid -= dir * 0.08
        
        engine.capsule(a: leftFinRoot, b: leftFinTip, r0: 0.08, r1: 0.04, colorOf: { _ in finColor })
        engine.capsule(a: leftFinRoot, b: leftFinMid, r0: 0.08, r1: 0.05, colorOf: { _ in finColor })
        
        var rightFinRoot = spine[1]
        rightFinRoot -= side * 0.28
        rightFinRoot -= dir * 0.08
        
        var rightFinTip = rightFinRoot
        rightFinTip -= side * 0.45
        rightFinTip -= dir * 0.25
        rightFinTip.z -= finPaddle
        
        var rightFinMid = rightFinRoot
        rightFinMid -= side * 0.35
        rightFinMid -= dir * 0.08
        
        engine.capsule(a: rightFinRoot, b: rightFinTip, r0: 0.08, r1: 0.04, colorOf: { _ in finColor })
        engine.capsule(a: rightFinRoot, b: rightFinMid, r0: 0.08, r1: 0.05, colorOf: { _ in finColor })
        
        // 8. Bifurcated Caudal Tail Fin (双叶羽状大尾鳍，非大圆球！)
        let tailBase = spine[4]
        let tailWave = sin(fish.tailPhase - 4.2) * 0.42
        let tailDir = normalize(spine[4] - spine[3])
        let tailSide = SIMD3<Float>(-tailDir.y, tailDir.x, 0)
        
        // Upper Lobe (上叶大尾鳍)
        var upperLobe = tailBase
        upperLobe += tailDir * 0.58
        upperLobe += tailSide * 0.25
        upperLobe.z += 0.14
        engine.capsule(a: tailBase, b: upperLobe, r0: 0.10, r1: 0.04, colorOf: { _ in finColor })
        
        // Lower Lobe (下叶大尾鳍)
        var lowerLobe = tailBase
        lowerLobe += tailDir * 0.58
        lowerLobe -= tailSide * 0.25
        lowerLobe.z -= 0.10
        engine.capsule(a: tailBase, b: lowerLobe, r0: 0.10, r1: 0.04, colorOf: { _ in finColor })
        
        // Central tail web (尾鳍中央半透明羽状展开)
        var centerLobe = tailBase
        centerLobe += tailDir * 0.48
        centerLobe += tailSide * (tailWave * 0.2)
        engine.capsule(a: tailBase, b: centerLobe, r0: 0.09, r1: 0.03, colorOf: { _ in hiSpot })
    }
    
    private func drawLilyPads(engine: PixelEngine) {
        // Flat circular lily pads with authentic V-notch cleft & blooming multi-petal lotus
        drawSingleLilyPad(engine: engine, cx: -2.8, cy: 1.8, radius: 0.95, notchAngle: Float.pi * 0.25)
        drawLotusFlower(engine: engine, at: SIMD3<Float>(-2.4, 1.5, waterZ + 0.06), scale: 1.0)
        
        drawSingleLilyPad(engine: engine, cx: -3.8, cy: 1.2, radius: 0.72, notchAngle: -Float.pi * 0.4)
        drawSingleLilyPad(engine: engine, cx: 2.2, cy: -1.8, radius: 0.88, notchAngle: Float.pi * 0.8)
        drawSingleLilyPad(engine: engine, cx: 2.9, cy: -1.1, radius: 0.60, notchAngle: -Float.pi * 0.2)
    }
    
    private func drawSingleLilyPad(engine: PixelEngine, cx: Float, cy: Float, radius: Float, notchAngle: Float) {
        let padGreen = SIMD3<Float>(48, 138, 58)
        let padRim = SIMD3<Float>(75, 168, 85)
        let z = waterZ + 0.03
        
        // Flat fan sectors leaving a classic V-notch (缺口)
        let sectors = 14
        for s in 0..<sectors {
            let theta = Float(s) * (2.0 * Float.pi / Float(sectors + 2)) + notchAngle + 0.35
            let rx = cos(theta) * radius
            let ry = sin(theta) * radius
            
            // Radiating flat leaf ribs from center to rim
            engine.capsule(a: SIMD3<Float>(cx, cy, z),
                           b: SIMD3<Float>(cx + rx, cy + ry, z),
                           r0: 0.14, r1: 0.10,
                           colorOf: { _ in padGreen })
            // Upturned bright green pad rim
            engine.sphere(cx + rx, cy + ry, z + 0.02, 0.08, padRim)
        }
    }
    
    private func drawLotusFlower(engine: PixelEngine, at: SIMD3<Float>, scale: Float) {
        let flowerPink = SIMD3<Float>(255, 175, 205)
        let flowerWhite = SIMD3<Float>(255, 248, 252)
        let stamenGold = SIMD3<Float>(255, 225, 75)
        
        // 1. Central golden seedpod/stamen core (莲蓬花蕊)
        engine.sphere(at.x, at.y, at.z + 0.12 * scale, 0.15 * scale, stamenGold, mode: .gloss)
        
        // 2. Inner upright white-pink petals (4 petals)
        for i in 0..<4 {
            let theta = Float(i) * (Float.pi * 0.5) + 0.3
            let px = at.x + cos(theta) * 0.18 * scale
            let py = at.y + sin(theta) * 0.18 * scale
            let pz = at.z + 0.15 * scale
            engine.capsule(a: at + SIMD3<Float>(0, 0, 0.04),
                           b: SIMD3<Float>(px, py, pz),
                           r0: 0.10 * scale, r1: 0.06 * scale,
                           colorOf: { _ in flowerWhite })
        }
        
        // 3. Outer radiating open pointed petals (8 radiating petals opening onto water)
        for i in 0..<8 {
            let theta = Float(i) * (Float.pi * 0.25)
            let px = at.x + cos(theta) * 0.38 * scale
            let py = at.y + sin(theta) * 0.38 * scale
            let pz = at.z + 0.04 * scale
            let tip = at + SIMD3<Float>(cos(theta) * 0.52 * scale, sin(theta) * 0.52 * scale, 0.02 * scale)
            engine.capsule(a: at, b: SIMD3<Float>(px, py, pz), r0: 0.11 * scale, r1: 0.08 * scale, colorOf: { _ in flowerPink })
            engine.capsule(a: SIMD3<Float>(px, py, pz), b: tip, r0: 0.08 * scale, r1: 0.03 * scale, colorOf: { _ in flowerPink })
        }
    }
    
    private func drawWaterShimmer(engine: PixelEngine) {
        // Subtle shimmering water caustics across the surface
        let step: Float = 0.65
        var x = -pondHalfX + 0.6
        while x <= pondHalfX - 0.6 {
            var y = -pondHalfY + 0.6
            while y <= pondHalfY - 0.6 {
                let wave = sin(x * 1.6 + time * 2.0) * cos(y * 1.6 + time * 1.8)
                if wave > 0.68 {
                    let p = engine.project(x, y, waterZ)
                    let ix = Int(floor(p.sx))
                    let iy = Int(floor(p.sy))
                    if ix >= 0 && iy >= 0 && ix < PixelEngine.W && iy < PixelEngine.H {
                        let i = iy * PixelEngine.W + ix
                        if p.d > engine.zb[i] {
                            engine.zb[i] = p.d
                            engine.pix[i] = PixelEngine.rgb(225, 248, 255)
                        }
                    }
                }
                y += step
            }
            x += step
        }
    }
    
    private func drawWaterRipples(engine: PixelEngine) {
        let rippleColor = SIMD3<Float>(215, 242, 255)
        for r in ripples {
            let steps = 16
            for s in 0..<steps {
                let theta = Float(s) * (2.0 * Float.pi / Float(steps))
                let rx = r.x + cos(theta) * r.radius
                let ry = r.y + sin(theta) * r.radius
                if rx > -pondHalfX + 0.3 && rx < pondHalfX - 0.3 && ry > -pondHalfY + 0.3 && ry < pondHalfY - 0.3 {
                    engine.sphere(rx, ry, waterZ + 0.02, 0.10, rippleColor)
                }
            }
        }
    }
    
    // MARK: - Interactions
    public func handleKeystroke() {
        // Typing sprinkles fish food flakes randomly into the pond
        let rx = Float.random(in: -pondHalfX + 1.2 ... pondHalfX - 1.2)
        let ry = Float.random(in: -pondHalfY + 1.2 ... pondHalfY - 1.2)
        pellets.append(Pellet(
            pos: SIMD3<Float>(rx, ry, waterZ + 1.2),
            vel: SIMD3<Float>(Float.random(in: -0.2...0.2), Float.random(in: -0.2...0.2), -2.2),
            life: 6.0,
            color: SIMD3<Float>(235, 135, 55)
        ))
        ripples.append(Ripple(x: rx, y: ry, radius: 0.15, maxRadius: 1.4, alpha: 0.9))
    }
    
    public func handlePointerDown(screenPoint: CGPoint) {
        let (unX, unY) = (Float.random(in: -2.0...2.0), Float.random(in: -1.6...1.6))
        SoundManager.shared.play(.splash)
        
        // Feed 3 tasty pellets
        for _ in 0..<3 {
            pellets.append(Pellet(
                pos: SIMD3<Float>(unX + Float.random(in: -0.4...0.4), unY + Float.random(in: -0.4...0.4), waterZ + 1.0),
                vel: SIMD3<Float>(Float.random(in: -0.2...0.2), Float.random(in: -0.2...0.2), -1.8),
                life: 7.0,
                color: SIMD3<Float>(245, 125, 45)
            ))
        }
        ripples.append(Ripple(x: unX, y: unY, radius: 0.25, maxRadius: 2.2, alpha: 1.0))
    }
    
    public func handlePointerMove(screenPoint: CGPoint) {}
    public func handlePointerUp() {}
    
    public func handleActionKey() {
        handlePointerDown(screenPoint: .zero)
    }
}
