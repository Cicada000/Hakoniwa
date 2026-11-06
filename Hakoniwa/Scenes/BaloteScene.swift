//
//  BaloteScene.swift
//  Hakoniwa
//
//  Ported and adapted from `balote/index.html` in pixel-plays:
//  https://github.com/amirmushichge/pixel-plays
//  Copyright (c) 2026 Amir Mushich
//  Licensed under the MIT License.
//

import Foundation
import CoreGraphics
import simd

public final class BaloteBall {
    public var x: Float
    public var y: Float
    public var z: Float
    public var vx: Float
    public var vy: Float
    public var vz: Float
    public var team: Int // -1 for jack, 0 for player, 1 for rival
    public var r: Float
    public var mass: Float
    
    public init(x: Float, y: Float, z: Float, team: Int, r: Float, mass: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.vx = 0
        self.vy = 0
        self.vz = 0
        self.team = team
        self.r = r
        self.mass = mass
    }
}

public struct BaloteResult {
    public var winner: Int
    public var counted: [BaloteBall]
}

public final class BaloteScene: HakoniwaScene {
    public let sceneId = "balote"
    public let originY: Float = 22.0
    public let shadowX: Float = 1.3
    public let shadowY: Float = -0.12
    
    // Constants
    private let COURT_X: Float = 12.0
    private let COURT_Y: Float = 3.8
    private let BOARD: Float = 0.3
    private let THROW_X: Float = 9.5
    private let GRAVITY: Float = 12.0
    private let LAUNCH_VZ: Float = 3.0
    private let ROLL_DECEL: Float = 6.0
    private let MAX_SPEED: Float = 15.0
    private let WIN_SCORE: Int = 5
    private let BALLS_PER_TEAM: Int = 4
    private let BALL_R: Float = 0.3
    private let JACK_R: Float = 0.16
    private let JACK_COLOR = SIMD3<Float>(232, 200, 62)
    
    private let TEAMS: [FigurePalette] = [
        FigurePalette(
            ball: SIMD3<Float>(176, 58, 44),
            shirt: SIMD3<Float>(188, 60, 44),
            stripe: SIMD3<Float>(240, 232, 214),
            legs: SIMD3<Float>(48, 47, 58),
            hair: SIMD3<Float>(38, 28, 24),
            skin: SIMD3<Float>(222, 170, 132)
        ),
        FigurePalette(
            ball: SIMD3<Float>(42, 76, 112),
            shirt: SIMD3<Float>(40, 72, 110),
            stripe: SIMD3<Float>(226, 228, 224),
            legs: SIMD3<Float>(84, 72, 58),
            hair: SIMD3<Float>(120, 112, 104),
            skin: SIMD3<Float>(196, 146, 110)
        )
    ]
    
    private let SAND = SIMD3<Float>(224, 198, 152)
    private let DIRT = SIMD3<Float>(132, 100, 72)
    private let SAND_TONES: [SIMD3<Float>] = [
        SIMD3<Float>(200, 172, 130),
        SIMD3<Float>(211, 185, 141),
        SIMD3<Float>(220, 196, 151),
        SIMD3<Float>(229, 207, 163)
    ]
    
    private let KIND_COURT: UInt8 = 1
    private let KIND_DIRT: UInt8 = 2
    
    // State
    private var pristinePix = [UInt32](repeating: 0x00000000, count: PixelEngine.totalPixels)
    private var trackMark = [UInt8](repeating: 0, count: PixelEngine.totalPixels)
    
    public enum Phase {
        case aim
        case swing
        case roll
        case settleJack
        case frameEnd
        case over
    }
    
    public private(set) var phase: Phase = .aim
    public private(set) var team: Int = 0
    public private(set) var balls: [BaloteBall] = []
    public private(set) var jack: BaloteBall? = nil
    public private(set) var left: [Int] = [4, 4]
    public private(set) var score: [Int] = [0, 0]
    public private(set) var yaw: Float = Float.pi
    public private(set) var power: Float = 0
    public private(set) var swing: Float = 0
    public private(set) var timer: Float = 0
    public private(set) var starter: Int = 0
    public private(set) var result: BaloteResult? = nil
    public private(set) var aiTarget: (power: Float, yaw: Float) = (0, Float.pi)
    public private(set) var released: Bool = false
    public private(set) var gameTime: Float = 0
    public private(set) var statusText: String = ""
    
    private var dragStart: CGPoint? = nil
    
    public init() {}
    
    private func pickLevel(_ v: Float, _ ix: Int, _ iy: Int) -> Int {
        return clamp(Int(floor(1.5 + v * 2.4 + (PixelEngine.bayerAt(ix, iy) - 0.5) * 0.9)), 1, 4)
    }
    
    private func groundColor(x: Float, y: Float, ix: Int, iy: Int, i: Int, engine: PixelEngine) -> UInt32 {
        let edge = pow(pow(abs(x) / 16.2, 4.0) + pow(abs(y) / 7.4, 4.0), 0.25)
        let rough = edge + (noise2D(x * 1.3, y * 1.3) - 0.5) * 0.13
        if rough > 1.04 { return 0 }
        if rough > 0.93 && hash2D(Float(ix), Float(iy)) < (rough - 0.93) / 0.11 { return 0 }
        
        let fine = hash2D(Float(ix), Float(iy))
        let pebble = fine > 0.975
        let pebbleShade = hash2D(Float(ix - 1), Float(iy - 1)) > 0.975
        let onCourt = abs(x) <= COURT_X && abs(y) <= COURT_Y
        
        if onCourt {
            engine.kinds[i] = KIND_COURT
            if abs(abs(x) - 8.0) < 0.07 && fine > 0.16 {
                return PixelEngine.rgb(246, 240, 224)
            }
            let lane = max(0, 1.0 - abs(y) / 1.8)
            let rake = sin(y * 5.0 + noise2D(x * 0.4, y) * 3.0) * 0.05
            let scuff: Float = (abs(x - THROW_X) < 1.5 && abs(y) < 1.3) ? noise2D(x * 2.0, y * 2.0) * 0.3 : 0
            let v = 0.5 + (noise2D(x * 0.7, y * 0.9) - 0.5) * 0.7 + lane * 0.18 + rake - scuff
            let ramp = engine.rampOf(SAND)
            if pebble { return ramp[4] }
            if pebbleShade { return ramp[1] }
            let toneIdx = clamp(Int(floor(v * 4.0 + (PixelEngine.bayerAt(ix, iy) - 0.5) * 0.6)), 0, 3)
            let tone = SAND_TONES[toneIdx]
            return PixelEngine.rgb(tone.x, tone.y, tone.z)
        }
        
        let dirt = max(abs(x) - COURT_X, abs(y) - COURT_Y)
        if dirt < 0.3 + noise2D(x * 2.2, y * 2.2) * 0.9 {
            engine.kinds[i] = KIND_DIRT
            let ramp = engine.rampOf(DIRT)
            if pebble { return ramp[4] }
            if pebbleShade { return ramp[0] }
            return ramp[pickLevel(0.25 + noise2D(x * 3.0, y * 3.0) * 0.6, ix, iy)]
        }
        
        engine.kinds[i] = PixelEngine.KIND_GRASS
        let t = noise2D(x * 0.9, y * 0.9) * 1.15 + (fine - 0.5) * 0.55 - 0.08
        let grassIdx = clamp(Int(floor(t * 4.2)), 0, 3)
        let gc = PixelEngine.GRASS_COLORS[grassIdx]
        return PixelEngine.rgb(gc.x, gc.y, gc.z)
    }
    
    private func stampTrack(_ b: BaloteBall, engine: PixelEngine) {
        let p = engine.project(b.x, b.y, 0)
        let ix = Int(floor(p.sx))
        let iy = Int(floor(p.sy))
        if ix < 0 || iy < 0 || ix >= PixelEngine.W || iy >= PixelEngine.H { return }
        let i = iy * PixelEngine.W + ix
        if engine.kinds[i] != KIND_COURT || trackMark[i] != 0 { return }
        trackMark[i] = 1
        let c = engine.bakedPix[i]
        let cr = Float(c & 0xFF) * 0.88
        let cg = Float((c >> 8) & 0xFF) * 0.87
        let cb = Float((c >> 16) & 0xFF) * 0.90
        engine.bakedPix[i] = PixelEngine.rgb(cr, cg, cb)
    }
    
    public func bake(engine: PixelEngine) {
        engine.originY = originY
        engine.shadowX = shadowX
        engine.shadowY = shadowY
        
        engine.zb = [Float](repeating: -1e9, count: PixelEngine.totalPixels)
        engine.pix = [UInt32](repeating: 0x00000000, count: PixelEngine.totalPixels)
        
        for iy in 0..<PixelEngine.H {
            let rowOffset = iy * PixelEngine.W
            for ix in 0..<PixelEngine.W {
                let g = engine.unproject(Float(ix) + 0.5, Float(iy) + 0.5)
                let i = rowOffset + ix
                let c = groundColor(x: g.x, y: g.y, ix: ix, iy: iy, i: i, engine: engine)
                if c == 0 { continue }
                engine.pix[i] = c
                engine.ground[i] = 1
                engine.zb[i] = (g.x + g.y) / PixelEngine.R2 * PixelEngine.COS
            }
        }
        engine.growGrass()
        engine.groundZ = engine.zb
        
        let wood = SIMD3<Float>(122, 84, 50)
        let woodLight = SIMD3<Float>(146, 104, 62)
        
        var x = -COURT_X - BOARD
        while x < COURT_X + BOARD {
            let w = (Int(floor(x / 3.0)) % 2 != 0) ? wood : woodLight
            engine.box(x0: x, y0: -COURT_Y - BOARD, z0: 0, x1: min(x + 3.0, COURT_X + BOARD), y1: -COURT_Y, z1: BOARD, c: w, seed: Float(Int(x)))
            engine.box(x0: x, y0: COURT_Y, z0: 0, x1: min(x + 3.0, COURT_X + BOARD), y1: COURT_Y + BOARD, z1: BOARD, c: w, seed: Float(Int(x) + 40))
            x += 3.0
        }
        for side in [-COURT_X - BOARD, COURT_X] {
            engine.box(x0: side, y0: -COURT_Y, z0: 0, x1: side + BOARD, y1: COURT_Y, z1: BOARD, c: wood, seed: Float(Int(side)))
        }
        
        // Bench
        engine.box(x0: -2.3, y0: -5.25, z0: 0.62, x1: 2.3, y1: -4.65, z1: 0.74, c: SIMD3<Float>(156, 112, 66), seed: 3)
        engine.box(x0: -2.3, y0: -5.30, z0: 0.90, x1: 2.3, y1: -5.20, z1: 1.50, c: SIMD3<Float>(132, 92, 54), seed: 4)
        for bx in [Float(-2.0), Float(1.85)] {
            engine.box(x0: bx, y0: -5.20, z0: 0, x1: bx + 0.15, y1: -4.70, z1: 0.62, c: SIMD3<Float>(60, 56, 54), seed: 5)
        }
        
        // Jug & Crate
        engine.box(x0: 2.9, y0: -5.5, z0: 0, x1: 3.8, y1: -4.7, z1: 0.5, c: SIMD3<Float>(146, 108, 66), seed: 6)
        let bottle = SIMD3<Float>(68, 110, 76)
        engine.capsule(a: SIMD3<Float>(3.35, -5.1, 0.6), b: SIMD3<Float>(3.35, -5.1, 1.0), r0: 0.16, r1: 0.10, colorOf: { _ in bottle }, mode: .gloss)
        
        engine.growTree(x: -9.5, y: -5.4)
        
        // Bench shadows
        var t: Float = -2.2
        while t <= 2.2 {
            engine.castShadow(x: t, y: -4.95, z: 0.68, r: 0.3)
            t += 0.3
        }
        engine.castShadow(x: 3.35, y: -5.1, z: 0.3, r: 0.5)
        engine.castShadow(x: 3.35, y: -5.1, z: 0.8, r: 0.14)
        
        // Spectator
        engine.pendingShadows.removeAll()
        engine.figure(px: -4.4, py: -5.3, yaw: 0.9, pose: FigurePose(stance: 0.08, armR: 0.1, armL: 0.1), palette: TEAMS[1]) { a, b, r0, r1, f in
            engine.dynamicAddBone(a: a, b: b, r0: r0, r1: r1, colorOf: f)
        }
        engine.flushShadows()
        engine.bakeOcclusion()
        engine.staticShadow = engine.shadowMask
        engine.applyShadows(refZ: engine.groundZ)
        
        pristinePix = engine.pix
        engine.bakedPix = engine.pix
        engine.bakedZ = engine.zb
        
        newFrame(engine: engine)
    }
    
    public func newFrame(engine: PixelEngine) {
        engine.bakedPix = pristinePix
        trackMark = [UInt8](repeating: 0, count: PixelEngine.totalPixels)
        balls.removeAll()
        
        let jx: Float = -8.0 + Float.random(in: 0..<5.0)
        let jy: Float = (Float.random(in: 0..<1.0) - 0.5) * 4.4
        let j = BaloteBall(x: jx + 2.4, y: jy * 0.6, z: 0.9, team: -1, r: JACK_R, mass: 0.25)
        j.vx = -3.6
        j.vy = jy * 0.35
        j.vz = 1.6
        jack = j
        
        left = [BALLS_PER_TEAM, BALLS_PER_TEAM]
        result = nil
        phase = .settleJack
    }
    
    private func allBalls() -> [BaloteBall] {
        if let j = jack {
            return [j] + balls
        }
        return balls
    }
    
    private func nearest(team: Int) -> Float {
        guard let j = jack else { return .infinity }
        var best: Float = .infinity
        for b in balls where b.team == team {
            let dist = hypot(b.x - j.x, b.y - j.y)
            if dist < best { best = dist }
        }
        return best
    }
    
    private func nextTurn() {
        if left[0] == 0 && left[1] == 0 {
            endFrame()
            return
        }
        let d = [nearest(team: 0), nearest(team: 1)]
        var t: Int
        if d[0] == .infinity && d[1] == .infinity {
            t = starter
        } else if d[0] == .infinity {
            t = 0
        } else if d[1] == .infinity {
            t = 1
        } else {
            t = d[0] > d[1] ? 0 : 1
        }
        if left[t] == 0 {
            t = 1 - t
        }
        team = t
        power = 0
        swing = 0
        if let j = jack {
            yaw = atan2(j.y, j.x - THROW_X)
        } else {
            yaw = Float.pi
        }
        phase = .aim
        if t == 1 {
            aiTarget = planAI()
            timer = 0
            statusText = "Rival is lining up"
        } else {
            statusText = "Drag back, release to throw"
        }
    }
    
    private func planAI() -> (power: Float, yaw: Float) {
        guard let j = jack else { return (0.5, Float.pi) }
        let mine = nearest(team: 1)
        let yours = nearest(team: 0)
        var tx = j.x
        var ty = j.y
        var extra: Float = 0
        
        if yours < 1.0 && yours < mine && Float.random(in: 0..<1.0) < 0.45 {
            var target: BaloteBall? = nil
            var bestDist: Float = .infinity
            for b in balls where b.team == 0 {
                let d = hypot(b.x - j.x, b.y - j.y)
                if d < bestDist {
                    bestDist = d
                    target = b
                }
            }
            if let tgt = target {
                tx = tgt.x
                ty = tgt.y
                extra = 3.2
            }
        }
        
        let dist = hypot(tx - THROW_X, ty) + extra
        let air = 2.0 * LAUNCH_VZ / GRAVITY + 0.08
        let v = (-air + sqrt(air * air + 2.0 * dist / ROLL_DECEL)) * ROLL_DECEL
        let spread = 1.0 + (Float.random(in: 0..<1.0) - 0.5) * 0.13
        return (
            clamp(v * spread / MAX_SPEED, 0.12, 1.0),
            atan2(ty, tx - THROW_X) + (Float.random(in: 0..<1.0) - 0.5) * 0.07
        )
    }
    
    private func releaseBall() {
        if power < 0.05 {
            power = 0
            return
        }
        phase = .swing
        swing = 0
        released = false
        statusText = ""
    }
    
    private func launch() {
        let fx = cos(yaw)
        let fy = sin(yaw)
        let b = BaloteBall(x: THROW_X + fx * 0.8, y: fy * 0.8, z: 0.72, team: team, r: BALL_R, mass: 1.0)
        let v = power * MAX_SPEED
        b.vx = fx * v
        b.vy = fy * v
        b.vz = LAUNCH_VZ
        balls.append(b)
        left[team] -= 1
        SoundManager.shared.play(.whoosh)
    }
    
    private func endFrame() {
        guard let j = jack else { return }
        let d = [nearest(team: 0), nearest(team: 1)]
        let winner = d[0] < d[1] ? 0 : 1
        let other = d[1 - winner]
        let counted = balls.filter { $0.team == winner && hypot($0.x - j.x, $0.y - j.y) < other }
        score[winner] += counted.count
        starter = winner
        result = BaloteResult(winner: winner, counted: counted)
        timer = 0
        SoundManager.shared.play(.point)
        
        let n = counted.count
        let who = (winner == 0) ? "You take" : "Rival takes"
        if score[winner] >= WIN_SCORE {
            phase = .over
            statusText = "\((winner == 0 ? "You win" : "Rival wins")) \(score[0])–\(score[1]) · Click to play again"
        } else {
            phase = .frameEnd
            statusText = "\(who) \(n) \(n == 1 ? "point" : "points") · Click to continue"
        }
    }
    
    private func resetMatch(engine: PixelEngine) {
        score = [0, 0]
        starter = 0
        newFrame(engine: engine)
    }
    
    private func stepPhysics(dt: Float, engine: PixelEngine) {
        let list = allBalls()
        for b in list {
            if b.z > b.r || b.vz > 0 {
                b.vz -= GRAVITY * dt
                b.z += b.vz * dt
                if b.z <= b.r {
                    b.z = b.r
                    if b.vz < -1.6 {
                        SoundManager.shared.play(.thud(amount: min(1, -b.vz / 5.0)))
                        b.vz *= -0.22
                        b.vx *= 0.82
                        b.vy *= 0.82
                    } else {
                        b.vz = 0
                    }
                }
            }
            if b.z <= b.r && b.vz < 0 { b.vz = 0 }
            b.x += b.vx * dt
            b.y += b.vy * dt
            
            let sp = hypot(b.vx, b.vy)
            if b.z <= b.r + 0.001 && sp > 0 {
                if sp > 0.4 { stampTrack(b, engine: engine) }
                let next = max(0, sp - ROLL_DECEL * dt)
                let kick = 1.0 + (Float.random(in: 0..<1.0) - 0.5) * 0.002
                b.vx *= (next / sp) * kick
                b.vy *= (next / sp) / kick
                if next < 0.03 {
                    b.vx = 0
                    b.vy = 0
                }
            }
            if b.z < BOARD + b.r {
                let lx = COURT_X - b.r
                let ly = COURT_Y - b.r
                if abs(b.x) > lx {
                    b.x = (b.x > 0 ? 1 : -1) * lx
                    b.vx *= -0.5
                    SoundManager.shared.play(.board(amount: min(1, abs(b.vx) / 4.0)))
                }
                if abs(b.y) > ly {
                    b.y = (b.y > 0 ? 1 : -1) * ly
                    b.vy *= -0.5
                    SoundManager.shared.play(.board(amount: min(1, abs(b.vy) / 4.0)))
                }
            }
        }
        
        for i in 0..<list.count {
            for j in (i + 1)..<list.count {
                let a = list[i]
                let b = list[j]
                let minD = a.r + b.r
                let dx = b.x - a.x
                let dy = b.y - a.y
                let dz = b.z - a.z
                let dd = hypot(hypot(dx, dy), dz)
                if dd >= minD || dd == 0 { continue }
                let nx = dx / dd
                let ny = dy / dd
                let nz = dz / dd
                let overlap = minD - dd
                let total = a.mass + b.mass
                a.x -= nx * overlap * b.mass / total
                a.y -= ny * overlap * b.mass / total
                b.x += nx * overlap * a.mass / total
                b.y += ny * overlap * a.mass / total
                
                let rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny + (b.vz - a.vz) * nz
                if rel >= 0 { continue }
                let imp = -(1.0 + 0.82) * rel / (1.0 / a.mass + 1.0 / b.mass)
                a.vx -= imp / a.mass * nx
                a.vy -= imp / a.mass * ny
                a.vz -= imp / a.mass * nz
                b.vx += imp / b.mass * nx
                b.vy += imp / b.mass * ny
                b.vz += imp / b.mass * nz
                SoundManager.shared.play(.clack(amount: min(1, -rel / 6.0)))
            }
        }
    }
    
    private func isAtRest() -> Bool {
        return allBalls().allSatisfy { $0.vx == 0 && $0.vy == 0 && $0.vz == 0 && $0.z <= $0.r + 0.001 }
    }
    
    public func update(dt: Float, engine: PixelEngine) {
        gameTime += dt
        if !isAtRest() {
            for _ in 0..<4 {
                stepPhysics(dt: dt / 4.0, engine: engine)
            }
        }
        
        switch phase {
        case .settleJack:
            statusText = ""
            if isAtRest() {
                nextTurn()
            }
        case .aim:
            if team == 1 {
                timer += dt
                let t = clamp((timer - 0.55) / 0.7, 0, 1)
                yaw = lerp(yaw, aiTarget.yaw, min(1, dt * 6.0))
                power = aiTarget.power * ease(t)
                if t >= 1 && timer > 1.45 {
                    releaseBall()
                }
            }
        case .swing:
            swing = min(1.0, swing + dt / 0.22)
            if !released && swing > 0.62 {
                released = true
                launch()
            }
            if swing >= 1.0 {
                phase = .roll
                timer = 0
            }
        case .roll:
            timer += dt
            if timer > 0.25 && isAtRest() {
                nextTurn()
            }
        case .frameEnd, .over:
            timer += dt
        }
    }
    
    private func poseFor(active: Bool) -> FigurePose {
        let breathe = sin(gameTime * 1.8) * 0.012
        if !active {
            return FigurePose(lean: breathe, stance: 0.08, armR: 0.05 + breathe, armL: 0.1)
        }
        let pull = (phase == .aim) ? power : 0
        if phase == .aim {
            return FigurePose(
                crouch: 0.35 + pull * 0.45,
                lean: 0.30 + pull * 0.24,
                stance: 0.20 + pull * 0.10,
                armR: -0.10 - pull * 1.15,
                armL: 0.38 + pull * 0.30
            )
        }
        if phase == .swing {
            let t = ease(swing)
            let from = -0.10 - power * 1.15
            return FigurePose(
                crouch: lerp(0.35 + power * 0.45, 0.42, t),
                lean: lerp(0.30 + power * 0.24, 0.50, t),
                stance: 0.30,
                armR: lerp(from, 1.35, t),
                armL: lerp(0.38, -0.25, t)
            )
        }
        let settle = clamp(timer * 1.5, 0, 1)
        return FigurePose(
            crouch: lerp(0.42, 0.08, ease(settle)),
            lean: lerp(0.50, 0.08, ease(settle)),
            stance: lerp(0.30, 0.14, settle),
            armR: lerp(1.35, 0.10, ease(settle)),
            armL: lerp(-0.25, 0.10, settle)
        )
    }
    
    private func drawAim(engine: PixelEngine) {
        let fx = cos(yaw)
        let fy = sin(yaw)
        let v = power * MAX_SPEED
        if power < 0.05 { return }
        
        var dots: [(Float, Float)] = []
        var x = THROW_X + fx * 0.8
        var y = fy * 0.8
        var z: Float = 0.72
        var vz = LAUNCH_VZ
        var landed: (x: Float, y: Float)? = nil
        
        for k in 0..<40 {
            x += fx * v * 0.03
            y += fy * v * 0.03
            vz -= GRAVITY * 0.03
            z += vz * 0.03
            if z <= BALL_R {
                landed = (x, y)
                break
            }
            if k % 2 == 0 {
                let p = engine.project(x, y, z)
                dots.append((p.sx, p.sy))
            }
        }
        let dark = PixelEngine.rgb(28, 27, 25)
        engine.drawDots(dots, color: dark)
        if let l = landed {
            let p = engine.project(l.x, l.y, 0)
            var cross: [(Float, Float)] = []
            for k in -2...2 {
                cross.append((p.sx + Float(k), p.sy))
                cross.append((p.sx, p.sy + Float(k)))
            }
            engine.drawDots(cross, color: dark)
        }
    }
    
    private func drawResult(engine: PixelEngine) {
        guard let res = result, let j = jack else { return }
        let jp = engine.project(j.x, j.y, 0.05)
        let tick = Int(floor(gameTime * 6.0)) % 2
        let teamBall = TEAMS[res.winner].ball
        let color = PixelEngine.rgb(teamBall.x, teamBall.y, teamBall.z)
        
        for b in res.counted {
            let bp = engine.project(b.x, b.y, 0.05)
            let n = max(1, Int(ceil(hypot(bp.sx - jp.sx, bp.sy - jp.sy) / 2.0)))
            var dots: [(Float, Float)] = []
            for k in 0...n {
                if (k + tick) % 2 != 0 {
                    let t = Float(k) / Float(n)
                    dots.append((lerp(jp.sx, bp.sx, t), lerp(jp.sy, bp.sy, t)))
                }
            }
            engine.drawDots(dots, color: color)
        }
    }
    
    public func draw(engine: PixelEngine) {
        engine.restoreBaked()
        
        let thrower = team
        let waiter = 1 - team
        let showActive = (phase == .aim || phase == .swing || phase == .roll)
        
        engine.pendingShadows.removeAll()
        let pActive = poseFor(active: showActive)
        let hand = engine.figure(px: THROW_X, py: 0, yaw: yaw, pose: pActive, palette: TEAMS[thrower]) { a, b, r0, r1, f in
            engine.dynamicAddBone(a: a, b: b, r0: r0, r1: r1, colorOf: f)
        }
        
        let waiterYaw = Float.pi + (waiter == 0 ? 0.25 : -0.25)
        let waiterY: Float = (waiter == 0 ? 2.7 : -2.7)
        engine.figure(px: 11.2, py: waiterY, yaw: waiterYaw, pose: poseFor(active: false), palette: TEAMS[waiter]) { a, b, r0, r1, f in
            engine.dynamicAddBone(a: a, b: b, r0: r0, r1: r1, colorOf: f)
        }
        
        if phase == .aim && left[team] > 0 {
            engine.sphere(hand.x, hand.y, hand.z - 0.04, BALL_R, TEAMS[team].ball, mode: .gloss)
            engine.pendingShadows.append((a: hand, r0: BALL_R, b: hand, r1: BALL_R))
        }
        
        for b in allBalls() {
            let color = (b.team < 0) ? JACK_COLOR : TEAMS[b.team].ball
            engine.sphere(b.x, b.y, b.z, b.r, color, mode: .gloss)
            engine.castShadow(x: b.x, y: b.y, z: b.z - b.r, r: b.r * 0.96, strength: 1, dither: 0)
            if b.z < b.r + 0.1 {
                engine.castShadow(x: b.x, y: b.y, z: 0, r: b.r * 0.72, strength: 2, dither: 0)
            }
        }
        
        let windT = floor(gameTime * PixelEngine.WIND_FPS) / PixelEngine.WIND_FPS
        engine.drawLeaves(t: windT)
        engine.drawTufts(t: windT)
        
        engine.flushShadows()
        engine.applyShadows(refZ: engine.bakedZ)
        engine.shadeEdges()
        
        if phase == .aim {
            drawAim(engine: engine)
        }
        drawResult(engine: engine)
        
        // Draw in-canvas retro pixel-art scoreboard
        drawScoreboard(engine: engine)
    }
    
    // MARK: - In-Canvas Pixel Scoreboard
    
    private static let FONT_3x5: [Character: [UInt8]] = [
        "Y": [0b101, 0b101, 0b010, 0b010, 0b010],
        "O": [0b111, 0b101, 0b101, 0b101, 0b111],
        "U": [0b101, 0b101, 0b101, 0b101, 0b111],
        "C": [0b111, 0b100, 0b100, 0b100, 0b111],
        "P": [0b111, 0b101, 0b111, 0b100, 0b100],
    ]
    
    private static let DIGITS_5x7: [[UInt8]] = [
        [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110], // 0
        [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110], // 1
        [0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111], // 2
        [0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110], // 3
        [0b10001, 0b10001, 0b10001, 0b11111, 0b00001, 0b00001, 0b00001], // 4
        [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110], // 5
        [0b01110, 0b10000, 0b11110, 0b10001, 0b10001, 0b10001, 0b01110], // 6
        [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000], // 7
        [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110], // 8
        [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110], // 9
    ]
    
    private static let TURN_ARROW: [UInt8] = [0b100, 0b011, 0b111, 0b011, 0b100]
    
    private func blendPixel(engine: PixelEngine, x: Int, y: Int, r: UInt32, g: UInt32, b: UInt32, a: UInt32) {
        guard x >= 0 && x < PixelEngine.W && y >= 0 && y < PixelEngine.H else { return }
        let idx = y * PixelEngine.W + x
        let dst = engine.pix[idx]
        let dstA = (dst >> 24) & 0xFF
        if dstA == 0 {
            let pr = (r * a) / 255
            let pg = (g * a) / 255
            let pb = (b * a) / 255
            engine.pix[idx] = (a << 24) | (pb << 16) | (pg << 8) | pr
        } else {
            let invA = 255 - a
            let dstR = dst & 0xFF
            let dstG = (dst >> 8) & 0xFF
            let dstB = (dst >> 16) & 0xFF
            let outR = (r * a + dstR * invA) / 255
            let outG = (g * a + dstG * invA) / 255
            let outB = (b * a + dstB * invA) / 255
            let outA = min(255, a + (dstA * invA) / 255)
            engine.pix[idx] = (outA << 24) | (outB << 16) | (outG << 8) | outR
        }
    }
    
    private func drawBits3x5(engine: PixelEngine, bits: [UInt8], x: Int, y: Int, r: UInt32, g: UInt32, b: UInt32, a: UInt32 = 255) {
        for row in 0..<5 {
            let val = bits[row]
            for col in 0..<3 {
                if ((val >> (2 - col)) & 1) != 0 {
                    blendPixel(engine: engine, x: x + col, y: y + row, r: r, g: g, b: b, a: a)
                }
            }
        }
    }
    
    private func drawBits5x7(engine: PixelEngine, bits: [UInt8], x: Int, y: Int, r: UInt32, g: UInt32, b: UInt32, a: UInt32 = 255) {
        for row in 0..<7 {
            let val = bits[row]
            for col in 0..<5 {
                if ((val >> (4 - col)) & 1) != 0 {
                    blendPixel(engine: engine, x: x + col, y: y + row, r: r, g: g, b: b, a: a)
                }
            }
        }
    }
    
    private func drawScoreboard(engine: PixelEngine) {
        let bx = PixelEngine.W - 92
        let by = 12
        let bw = 84
        let bh = 32
        
        // 1. Subtle drop shadow into scene background
        for dy in 1...bh {
            for dx in 1...bw {
                if (dx == 1 || dx == bw) && (dy == 1 || dy == bh) { continue }
                blendPixel(engine: engine, x: bx + dx + 1, y: by + dy + 1, r: 0, g: 0, b: 0, a: 60)
            }
        }
        
        // 2. Main plate background and border
        for dy in 0..<bh {
            for dx in 0..<bw {
                if (dx == 0 || dx == bw - 1) && (dy == 0 || dy == bh - 1) { continue }
                let px = bx + dx
                let py = by + dy
                
                if dx == 0 || dx == bw - 1 || dy == 0 || dy == bh - 1 {
                    // Warm rustic border
                    blendPixel(engine: engine, x: px, y: py, r: 75, g: 70, b: 65, a: 220)
                } else if dy == 16 {
                    // Divider line
                    blendPixel(engine: engine, x: px, y: py, r: 45, g: 42, b: 40, a: 180)
                } else {
                    // Dark plate background
                    blendPixel(engine: engine, x: px, y: py, r: 24, g: 25, b: 28, a: 220)
                }
            }
        }
        
        // 3. Team 0 (YOU / Red Team)
        // Turn arrow indicator
        if team == 0 && (phase == .aim || phase == .swing || phase == .roll) {
            drawBits3x5(engine: engine, bits: Self.TURN_ARROW, x: bx + 3, y: by + 6, r: 245, g: 190, b: 45)
        }
        // Red ball sphere icon (4x4)
        for dy in 0..<4 {
            for dx in 0..<4 {
                if (dx == 0 || dx == 3) && (dy == 0 || dy == 3) { continue }
                let isHighlight = (dx == 1 && dy == 1)
                let r: UInt32 = isHighlight ? 255 : 210
                let g: UInt32 = isHighlight ? 150 : 45
                let b: UInt32 = isHighlight ? 140 : 35
                blendPixel(engine: engine, x: bx + 9 + dx, y: by + 6 + dy, r: r, g: g, b: b, a: 255)
            }
        }
        // Label "YOU"
        if let yBits = Self.FONT_3x5["Y"], let oBits = Self.FONT_3x5["O"], let uBits = Self.FONT_3x5["U"] {
            drawBits3x5(engine: engine, bits: yBits, x: bx + 16, y: by + 6, r: 225, g: 220, b: 215)
            drawBits3x5(engine: engine, bits: oBits, x: bx + 20, y: by + 6, r: 225, g: 220, b: 215)
            drawBits3x5(engine: engine, bits: uBits, x: bx + 24, y: by + 6, r: 225, g: 220, b: 215)
        }
        // Score digit (0-9)
        let s0 = clamp(score[0], 0, 9)
        drawBits5x7(engine: engine, bits: Self.DIGITS_5x7[s0], x: bx + 34, y: by + 5, r: 255, g: 255, b: 255)
        // Remaining ball pips
        for i in 0..<BALLS_PER_TEAM {
            let active = i < left[0]
            let pipR: UInt32 = active ? 220 : 60
            let pipG: UInt32 = active ? 50 : 25
            let pipB: UInt32 = active ? 40 : 25
            for dy in 0..<3 {
                for dx in 0..<3 {
                    blendPixel(engine: engine, x: bx + 48 + i * 8 + dx, y: by + 7 + dy, r: pipR, g: pipG, b: pipB, a: 240)
                }
            }
            if active {
                blendPixel(engine: engine, x: bx + 48 + i * 8 + 1, y: by + 7 + 1, r: 255, g: 140, b: 120, a: 255)
            }
        }
        
        // 4. Team 1 (CPU / Blue Team)
        // Turn arrow indicator
        if team == 1 && (phase == .aim || phase == .swing || phase == .roll) {
            drawBits3x5(engine: engine, bits: Self.TURN_ARROW, x: bx + 3, y: by + 20, r: 245, g: 190, b: 45)
        }
        // Blue ball sphere icon (4x4)
        for dy in 0..<4 {
            for dx in 0..<4 {
                if (dx == 0 || dx == 3) && (dy == 0 || dy == 3) { continue }
                let isHighlight = (dx == 1 && dy == 1)
                let r: UInt32 = isHighlight ? 140 : 45
                let g: UInt32 = isHighlight ? 185 : 85
                let b: UInt32 = isHighlight ? 245 : 145
                blendPixel(engine: engine, x: bx + 9 + dx, y: by + 20 + dy, r: r, g: g, b: b, a: 255)
            }
        }
        // Label "CPU"
        if let cBits = Self.FONT_3x5["C"], let pBits = Self.FONT_3x5["P"], let uBits = Self.FONT_3x5["U"] {
            drawBits3x5(engine: engine, bits: cBits, x: bx + 16, y: by + 20, r: 180, g: 190, b: 205)
            drawBits3x5(engine: engine, bits: pBits, x: bx + 20, y: by + 20, r: 180, g: 190, b: 205)
            drawBits3x5(engine: engine, bits: uBits, x: bx + 24, y: by + 20, r: 180, g: 190, b: 205)
        }
        // Score digit (0-9)
        let s1 = clamp(score[1], 0, 9)
        drawBits5x7(engine: engine, bits: Self.DIGITS_5x7[s1], x: bx + 34, y: by + 19, r: 255, g: 255, b: 255)
        // Remaining ball pips
        for i in 0..<BALLS_PER_TEAM {
            let active = i < left[1]
            let pipR: UInt32 = active ? 50 : 22
            let pipG: UInt32 = active ? 105 : 35
            let pipB: UInt32 = active ? 180 : 55
            for dy in 0..<3 {
                for dx in 0..<3 {
                    blendPixel(engine: engine, x: bx + 48 + i * 8 + dx, y: by + 21 + dy, r: pipR, g: pipG, b: pipB, a: 240)
                }
            }
            if active {
                blendPixel(engine: engine, x: bx + 48 + i * 8 + 1, y: by + 21 + 1, r: 130, g: 180, b: 255, a: 255)
            }
        }
    }
    
    // MARK: - Input Handling
    
    public func handlePointerDown(screenPoint: CGPoint) {
        if phase == .frameEnd && timer > 0.5 {
            // New frame
            newFrame(engine: HakoniwaAppModel.shared.engine)
            return
        }
        if phase == .over && timer > 0.5 {
            resetMatch(engine: HakoniwaAppModel.shared.engine)
            return
        }
        if phase != .aim || team != 0 { return }
        dragStart = screenPoint
    }
    
    public func handlePointerMove(screenPoint: CGPoint) {
        guard let start = dragStart else { return }
        let dx = Float(screenPoint.x - start.x) / PixelEngine.S
        let dy = Float(screenPoint.y - start.y) / (PixelEngine.S * PixelEngine.SIN)
        let wx = (dx + dy) / PixelEngine.R2
        let wy = (dy - dx) / PixelEngine.R2
        let len = hypot(wx, wy)
        power = clamp(len / 18.0, 0, 1)
        if len > 0.4 && wx > 0 {
            yaw = atan2(-wy, -wx)
        }
    }
    
    public func handlePointerUp() {
        guard dragStart != nil else { return }
        dragStart = nil
        if phase == .aim && team == 0 {
            releaseBall()
        }
    }
    
    public func handleActionKey() {
        if phase == .frameEnd {
            newFrame(engine: HakoniwaAppModel.shared.engine)
            return
        }
        if phase == .over {
            resetMatch(engine: HakoniwaAppModel.shared.engine)
            return
        }
        if phase == .aim && team == 0 {
            releaseBall()
        }
    }
}
