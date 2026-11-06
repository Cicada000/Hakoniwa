//
//  PachinkoScene.swift
//  Hakoniwa
//
//  Typing-Powered Pachinko / Pinball Diorama.
//  Keystrokes charge colorful bouncy balls into the top reservoir.
//  Release to watch dozens of balls cascade down through brass pins with joyful clatter!
//

import Foundation
import CoreGraphics
import QuartzCore
import simd

public final class PachinkoScene: HakoniwaScene {
    public let sceneId = "pachinko"
    public let sceneName = "弹珠连击 (Pachinko)"
    public let sceneIcon = "flame.fill"
    public let originY: Float = 18.0
    public let shadowX: Float = 1.3
    public let shadowY: Float = -0.16
    
    // Physics Ball Structure
    private struct PinBall {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var color: SIMD3<Float>
        var r: Float
        var lastSoundTime: CFTimeInterval
    }
    
    // Static obstacle pins on board
    private struct Pin {
        var x: Float
        var y: Float
        var z: Float
        var r: Float
    }
    private var pins: [Pin] = []
    
    // Score Slot definition (at the front/bottom of the board)
    private struct Slot {
        var xMin: Float
        var xMax: Float
        var score: Int
        var highlightTimer: Float
    }
    private var slots: [Slot] = []
    
    // Game State
    public var ballsReady: Int = 12
    public var totalScore: Int = 0
    private var activeBalls: [PinBall] = []
    
    // Release trigger timer
    private var cascadeTimer: Float = 0.0
    private var cascadeQueue: Int = 0
    private var plungerPull: Float = 0.0
    
    // Board Bounds (Y-min is back/top, Y-max is front/bottom towards camera)
    private let boardHalfW: Float = 5.8
    private let boardYMin: Float = -6.8
    private let boardYMax: Float = 5.8
    
    public var statusDescription: String {
        return "得分: \(totalScore) • 蓄能弹珠: \(ballsReady) 颗 • [空格 / 点击] 倾泻弹射"
    }
    
    public init() {
        setupBoardLayout()
    }
    
    private func setupBoardLayout() {
        // Lay out staggered hexagonal brass pins across the board
        pins.removeAll()
        let rows = 7
        for r in 0..<rows {
            // y ranges from -4.5 (back) to 3.2 (front)
            let y = Float(r) * 1.35 - 4.5
            let count = (r % 2 == 0) ? 6 : 5
            let startX: Float = (r % 2 == 0) ? -4.0 : -3.2
            let spacingX: Float = 1.6
            for c in 0..<count {
                let x = startX + Float(c) * spacingX
                let z = boardZAt(y: y) + 0.32
                pins.append(Pin(x: x, y: y, z: z, r: 0.22))
            }
        }
        
        // 5 Catch Slots at the front (Y = 4.2 to 5.6)
        slots = [
            Slot(xMin: -5.5, xMax: -3.3, score: 100, highlightTimer: 0),
            Slot(xMin: -3.3, xMax: -1.1, score: 300, highlightTimer: 0),
            Slot(xMin: -1.1, xMax: 1.1, score: 1000, highlightTimer: 0), // JACKPOT
            Slot(xMin: 1.1, xMax: 3.3, score: 300, highlightTimer: 0),
            Slot(xMin: 3.3, xMax: 5.5, score: 100, highlightTimer: 0)
        ]
    }
    
    // Slanted board elevation: high in back (Y=-6.8 -> Z=3.6), low in front (Y=5.8 -> Z=0.6)
    private func boardZAt(y: Float) -> Float {
        let t = clamp((y - boardYMin) / (boardYMax - boardYMin), 0.0, 1.0)
        return 3.6 - t * 3.0
    }
    
    // MARK: - Bake Static Cabinet & Open Frame
    public func bake(engine: PixelEngine) {
        engine.reset()
        engine.originY = originY
        engine.shadowX = shadowX
        engine.shadowY = shadowY
        
        let woodOuter = SIMD3<Float>(78, 52, 38)     // Rich walnut cabinet
        let woodTrim = SIMD3<Float>(115, 78, 54)     // Lighter wood molding
        let boardBack = SIMD3<Float>(245, 240, 230)  // Creamy ivory playfield
        let brassGold = SIMD3<Float>(225, 185, 75)
        let redBumper = SIMD3<Float>(215, 55, 45)
        
        // 1. Slanted Base Bed under the playfield
        engine.box(x0: -boardHalfW - 0.8, y0: boardYMin - 0.8, z0: -0.6,
                   x1: boardHalfW + 0.8, y1: boardYMax + 0.6, z1: 0.1,
                   c: woodOuter)
        
        // 2. Playfield Backboard (Slanted ivory surface)
        // Stepped boxes to approximate smooth slope
        let steps = 24
        for s in 0..<steps {
            let t0 = Float(s) / Float(steps)
            let t1 = Float(s + 1) / Float(steps)
            let y0 = boardYMin + t0 * (boardYMax - boardYMin)
            let y1 = boardYMin + t1 * (boardYMax - boardYMin)
            let z = boardZAt(y: (y0 + y1) * 0.5)
            engine.box(x0: -boardHalfW, y0: y0, z0: 0.1,
                       x1: boardHalfW, y1: y1, z1: z,
                       c: boardBack)
        }
        
        // 3. Tall Backboard in Background (Ball reservoir & header)
        // Back wall at boardYMin is AWAY from camera, so height does NOT occlude anything!
        engine.box(x0: -boardHalfW - 0.5, y0: boardYMin - 0.8, z0: 0.1,
                   x1: boardHalfW + 0.5, y1: boardYMin, z1: 4.8,
                   c: woodOuter)
        engine.box(x0: -boardHalfW - 0.6, y0: boardYMin - 0.9, z0: 4.6,
                   x1: boardHalfW + 0.6, y1: boardYMin + 0.1, z1: 4.95,
                   c: woodTrim)
        
        // 4. Low Side Rails (Sloping from back to front, keeping field 100% visible)
        for s in 0..<steps {
            let t0 = Float(s) / Float(steps)
            let t1 = Float(s + 1) / Float(steps)
            let y0 = boardYMin + t0 * (boardYMax - boardYMin)
            let y1 = boardYMin + t1 * (boardYMax - boardYMin)
            let zTop = boardZAt(y: (y0 + y1) * 0.5) + 0.6
            // Left rail
            engine.box(x0: -boardHalfW - 0.5, y0: y0, z0: 0.1,
                       x1: -boardHalfW, y1: y1, z1: zTop,
                       c: woodTrim)
            // Right rail
            engine.box(x0: boardHalfW, y0: y0, z0: 0.1,
                       x1: boardHalfW + 0.5, y1: y1, z1: zTop,
                       c: woodTrim)
        }
        
        // 5. LOW FRONT LIP in Foreground (Low profile so player has 100% unobstructed view!)
        engine.box(x0: -boardHalfW - 0.5, y0: boardYMax, z0: 0.1,
                   x1: boardHalfW + 0.5, y1: boardYMax + 0.5, z1: 0.85,
                   c: woodTrim)
        
        // 6. Side Triangular Deflector Bumpers
        engine.box(x0: -boardHalfW, y0: -1.5, z0: boardZAt(y: -1.5),
                   x1: -boardHalfW + 0.9, y1: 0.6, z1: boardZAt(y: 0.6) + 0.55,
                   c: redBumper)
        engine.box(x0: boardHalfW - 0.9, y0: -1.5, z0: boardZAt(y: -1.5),
                   x1: boardHalfW, y1: 0.6, z1: boardZAt(y: 0.6) + 0.55,
                   c: redBumper)
        
        // 7. Brass Obstacle Pins (Pillars)
        for p in pins {
            let base = SIMD3<Float>(p.x, p.y, p.z - 0.28)
            let top = SIMD3<Float>(p.x, p.y, p.z + 0.42)
            engine.capsule(a: base, b: top, r0: p.r, r1: p.r, colorOf: { _ in brassGold })
            engine.sphere(top.x, top.y, top.z, p.r * 1.15, brassGold)
        }
        
        // 8. Slot Dividers at Front (Y = 4.2 to 5.8)
        let dividerWood = SIMD3<Float>(105, 72, 52)
        for s in slots {
            engine.box(x0: s.xMin - 0.12, y0: 4.2, z0: boardZAt(y: 5.0),
                       x1: s.xMin + 0.12, y1: boardYMax, z1: boardZAt(y: 5.0) + 0.65,
                       c: dividerWood)
        }
        engine.box(x0: slots.last!.xMax - 0.12, y0: 4.2, z0: boardZAt(y: 5.0),
                   x1: slots.last!.xMax + 0.12, y1: boardYMax, z1: boardZAt(y: 5.0) + 0.65,
                   c: dividerWood)
        
        // Bake shadows
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
        let now = CACurrentMediaTime()
        
        // Cascade release dispenser
        if cascadeQueue > 0 {
            cascadeTimer -= dt
            if cascadeTimer <= 0 {
                cascadeTimer = 0.09
                cascadeQueue -= 1
                spawnPinBall()
            }
        }
        
        if plungerPull > 0 {
            plungerPull = max(0, plungerPull - dt * 5.0)
        }
        
        // Slot highlights
        for i in 0..<slots.count {
            if slots[i].highlightTimer > 0 {
                slots[i].highlightTimer = max(0, slots[i].highlightTimer - dt)
            }
        }
        
        // Gravity pulls DOWN the slope towards +Y (towards the player!)
        let gravityY: Float = 22.0
        let gravityZ: Float = -16.0
        
        // Update Active Pinballs
        for i in (0..<activeBalls.count).reversed() {
            var ball = activeBalls[i]
            
            // Apply slope gravity
            ball.vel.y += gravityY * dt
            ball.vel.z += gravityZ * dt
            
            // Move
            ball.pos += ball.vel * dt
            
            // Keep ball grounded on slanted board
            let groundZ = boardZAt(y: ball.pos.y) + ball.r
            if ball.pos.z < groundZ {
                ball.pos.z = groundZ
                if ball.vel.z < -0.4 {
                    ball.vel.z = -ball.vel.z * 0.35
                } else {
                    ball.vel.z = 0
                }
            }
            
            // Side Wall Collisions
            let leftWall = -boardHalfW + ball.r
            let rightWall = boardHalfW - ball.r
            if ball.pos.x < leftWall {
                ball.pos.x = leftWall
                ball.vel.x = abs(ball.vel.x) * 0.65
                if (now - ball.lastSoundTime) > 0.08 {
                    ball.lastSoundTime = now
                    SoundManager.shared.play(.clack(amount: 0.4))
                }
            } else if ball.pos.x > rightWall {
                ball.pos.x = rightWall
                ball.vel.x = -abs(ball.vel.x) * 0.65
                if (now - ball.lastSoundTime) > 0.08 {
                    ball.lastSoundTime = now
                    SoundManager.shared.play(.clack(amount: 0.4))
                }
            }
            
            // Collision with Brass Pins
            for p in pins {
                let dx = ball.pos.x - p.x
                let dy = ball.pos.y - p.y
                let distSq = dx * dx + dy * dy
                let minDist = ball.r + p.r
                if distSq < minDist * minDist && distSq > 0.0001 {
                    let dist = sqrt(distSq)
                    let nx = dx / dist
                    let ny = dy / dist
                    // Push out
                    ball.pos.x = p.x + nx * minDist
                    ball.pos.y = p.y + ny * minDist
                    
                    // Elastic reflect
                    let dot = ball.vel.x * nx + ball.vel.y * ny
                    if dot < 0 {
                        ball.vel.x = (ball.vel.x - 1.7 * dot * nx) + Float.random(in: -0.7...0.7)
                        ball.vel.y = (ball.vel.y - 1.7 * dot * ny)
                        if (now - ball.lastSoundTime) > 0.08 {
                            ball.lastSoundTime = now
                            SoundManager.shared.play(.clack(amount: 0.5))
                        }
                    }
                }
            }
            
            // Front Catch Slot Check (Y reaches bottom of board)
            if ball.pos.y >= boardYMax - 0.4 {
                // Determine slot
                for sIdx in 0..<slots.count {
                    if ball.pos.x >= slots[sIdx].xMin && ball.pos.x < slots[sIdx].xMax {
                        totalScore += slots[sIdx].score
                        slots[sIdx].highlightTimer = 0.5
                        if slots[sIdx].score >= 500 {
                            SoundManager.shared.play(.bell) // JACKPOT!
                        } else {
                            SoundManager.shared.play(.point)
                        }
                        break
                    }
                }
                activeBalls.remove(at: i)
                continue
            }
            
            activeBalls[i] = ball
        }
    }
    
    private func spawnPinBall() {
        let colors: [SIMD3<Float>] = [
            SIMD3<Float>(245, 65, 55),   // Ruby Red
            SIMD3<Float>(255, 205, 45),  // Gold Yellow
            SIMD3<Float>(55, 175, 235),  // Azure Blue
            SIMD3<Float>(165, 75, 225),  // Purple
            SIMD3<Float>(65, 215, 115)   // Emerald Green
        ]
        let c = colors.randomElement()!
        
        // Spawn near the top center chute (back of board Y = boardYMin + 0.6)
        let spawnX = Float.random(in: -1.2...1.2)
        let spawnY: Float = boardYMin + 0.6
        let spawnZ = boardZAt(y: spawnY) + 0.4
        
        let ball = PinBall(
            pos: SIMD3<Float>(spawnX, spawnY, spawnZ),
            vel: SIMD3<Float>(Float.random(in: -1.2...1.2), Float.random(in: 1.5...3.5), 0.0),
            color: c,
            r: 0.34,
            lastSoundTime: CACurrentMediaTime()
        )
        activeBalls.append(ball)
        SoundManager.shared.play(.thud(amount: 0.4))
    }
    
    // MARK: - Draw Dynamic Elements
    public func draw(engine: PixelEngine) {
        engine.restoreBaked()
        
        // 1. Draw Slot Highlights & Scores at the front
        drawSlotHighlights(engine: engine)
        
        // 2. Draw Ready Reservoir Balls at the top backboard
        drawTopReservoir(engine: engine)
        
        // 3. Draw Active Pinballs
        for ball in activeBalls {
            engine.sphere(ball.pos.x, ball.pos.y, ball.pos.z, ball.r, ball.color, mode: .gloss)
            engine.castShadow(x: ball.pos.x + 0.2, y: ball.pos.y - 0.1, z: ball.pos.z - ball.r, r: ball.r * 1.1, strength: 1)
        }
        
        // 4. Plunger Spring indicator on top-right backboard
        let plungerWood = SIMD3<Float>(135, 75, 45)
        let plungerZ: Float = boardZAt(y: boardYMin) + 0.8 - plungerPull * 0.6
        engine.box(x0: boardHalfW + 0.15, y0: boardYMin + 0.4, z0: plungerZ - 0.4,
                   x1: boardHalfW + 0.55, y1: boardYMin + 1.4, z1: plungerZ + 0.4,
                   c: plungerWood)
        
        engine.flushShadows()
    }
    
    private func drawSlotHighlights(engine: PixelEngine) {
        for s in slots {
            let col: SIMD3<Float> = (s.highlightTimer > 0)
                ? (s.score >= 500 ? SIMD3<Float>(255, 235, 75) : SIMD3<Float>(125, 225, 145))
                : (s.score >= 500 ? SIMD3<Float>(215, 175, 55) : SIMD3<Float>(75, 115, 145))
            
            let slotZ = boardZAt(y: 5.0) + 0.05
            engine.box(x0: s.xMin + 0.15, y0: 4.3, z0: slotZ,
                       x1: s.xMax - 0.15, y1: boardYMax - 0.1, z1: slotZ + 0.15,
                       c: col)
        }
    }
    
    private func drawTopReservoir(engine: PixelEngine) {
        let colors: [SIMD3<Float>] = [
            SIMD3<Float>(245, 65, 55),
            SIMD3<Float>(255, 205, 45),
            SIMD3<Float>(55, 175, 235),
            SIMD3<Float>(165, 75, 225),
            SIMD3<Float>(65, 215, 115)
        ]
        
        let displayCount = min(18, ballsReady)
        for i in 0..<displayCount {
            let x = -4.0 + Float(i % 9) * 1.0
            let row = Float(i / 9)
            let y = boardYMin - 0.35
            let z = 3.9 + row * 0.65
            let c = colors[i % colors.count]
            engine.sphere(x, y, z, 0.25, c, mode: .gloss)
        }
    }
    
    // MARK: - Interactions
    public func handleKeystroke() {
        // Typing adds balls to reservoir
        ballsReady = min(60, ballsReady + 1)
        if ballsReady % 5 == 0 {
            SoundManager.shared.play(.bubble)
        }
    }
    
    public func handlePointerDown(screenPoint: CGPoint) {
        // Trigger release of balls!
        plungerPull = 1.0
        let releaseCount = max(1, min(12, ballsReady))
        ballsReady = max(0, ballsReady - releaseCount)
        cascadeQueue += releaseCount
        SoundManager.shared.play(.whoosh)
    }
    
    public func handlePointerMove(screenPoint: CGPoint) {}
    public func handlePointerUp() {}
    
    public func handleActionKey() {
        // Space key triggers release
        handlePointerDown(screenPoint: .zero)
    }
}
