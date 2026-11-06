//
//  SoundManager.swift
//  Hakoniwa
//
//  Sound synthesizer design and parameters adapted from `shell.js` in pixel-plays:
//  https://github.com/amirmushichge/pixel-plays
//  Copyright (c) 2026 Amir Mushich
//  Licensed under the MIT License.
//

import Foundation
import AVFoundation

public enum SoundEffect {
    case clack(amount: Float)
    case thud(amount: Float)
    case board(amount: Float)
    case whoosh
    case point
    case waterDrop
    case hammer
    case bell
    case bubble
    case splash
}

public final class SoundManager {
    public static let shared = SoundManager()
    
    public var isMuted: Bool = false
    public var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = max(0, min(1, volume))
        }
    }
    
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100.0
    private let format: AVAudioFormat
    
    // Audio throttling: prevents queuing hundreds of sounds into a long repeating buffer backlog
    private var lastSoundTimes: [String: CFTimeInterval] = [:]
    private let minInterval: CFTimeInterval = 0.045
    
    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }
    
    public func stopAll() {
        player.stop()
        player.reset()
        lastSoundTimes.removeAll()
    }
    
    public func play(_ effect: SoundEffect) {
        guard !isMuted else { return }
        
        let now = CACurrentMediaTime()
        let effectKey: String = {
            switch effect {
            case .clack: return "clack"
            case .thud: return "thud"
            case .board: return "board"
            case .whoosh: return "whoosh"
            case .point: return "point"
            case .waterDrop: return "waterDrop"
            case .hammer: return "hammer"
            case .bell: return "bell"
            case .bubble: return "bubble"
            case .splash: return "splash"
            }
        }()
        
        if let last = lastSoundTimes[effectKey], (now - last) < minInterval {
            return // Throttled: drop to prevent buffer queue flood
        }
        lastSoundTimes[effectKey] = now
        
        let (f0, f1, duration, gain, waveType): (Float, Float, Float, Float, Int) = {
            switch effect {
            case .clack(let amount):
                return (1500, 620, 0.05, 0.28 * amount + 0.05, 1) // square
            case .thud(let amount):
                return (150, 70, 0.09, 0.30 * amount + 0.04, 0) // sine
            case .board(let amount):
                return (240, 120, 0.06, 0.22 * amount + 0.03, 2) // triangle
            case .whoosh:
                return (320, 180, 0.10, 0.035, 2) // triangle
            case .point:
                return (660, 880, 0.16, 0.08, 2) // triangle
            case .waterDrop:
                return (1400, 750, 0.08, 0.22, 0) // sine drop
            case .hammer:
                return (380, 130, 0.06, 0.26, 1) // square wood knock
            case .bell:
                return (1760, 1760, 0.28, 0.20, 0) // high pure chime
            case .bubble:
                return (420, 960, 0.08, 0.18, 0) // upward sine sweep
            case .splash:
                return (320, 80, 0.12, 0.22, 2) // triangle splash
            }
        }()
        
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        guard let channels = buffer.floatChannelData else { return }
        let channel = channels[0]
        
        var phase: Float = 0
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(frameCount)
            // exponential frequency sweep: f0 * (f1 / f0)^t
            let freq = f0 * pow(f1 / f0, t)
            phase += 2.0 * Float.pi * freq / Float(sampleRate)
            if phase > 2.0 * Float.pi { phase -= 2.0 * Float.pi }
            
            // Envelope: exponential decay
            let env = gain * exp(-t * 5.0)
            
            var sample: Float = 0
            if waveType == 0 { // Sine
                sample = sin(phase)
            } else if waveType == 1 { // Square
                sample = sin(phase) >= 0 ? 0.7 : -0.7
            } else { // Triangle
                let p = phase / (2.0 * Float.pi)
                sample = 4.0 * abs(p - 0.5) - 1.0
            }
            channel[i] = sample * env
        }
        
        if !engine.isRunning {
            try? engine.start()
        }
        player.play()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}
