//
//  HakoniwaAppModel.swift
//  Hakoniwa
//

import Foundation
import Combine
import QuartzCore
import AppKit

public final class HakoniwaAppModel: ObservableObject {
    public static let shared = HakoniwaAppModel()
    
    public let engine = PixelEngine()
    
    @Published public var currentScene: HakoniwaScene = BaloteScene()
    @Published public var isPaused: Bool = false
    @Published public var isMuted: Bool = false {
        didSet {
            SoundManager.shared.isMuted = isMuted
        }
    }
    @Published public var isWallpaperEnabled: Bool = false {
        didSet {
            if isWallpaperEnabled {
                WallpaperManager.shared.enableWallpaper()
            } else {
                WallpaperManager.shared.disableWallpaper()
            }
        }
    }
    
    // Reactive HUD States for SwiftUI
    @Published public var hudStatusText: String = "Drag back, release to throw"
    @Published public var hudScores: [Int] = [0, 0]
    @Published public var hudLeft: [Int] = [4, 4]
    @Published public var hudTeam: Int = 0
    
    private var displayLink: CVDisplayLink?
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    private let renderLock = NSLock()
    
    // Callback for any preview window (e.g. in ContentView)
    public var onFrameRendered: (([UInt32]) -> Void)?
    
    private init() {
        currentScene = AppSettings.shared.currentSceneType.createScene()
        setupScene()
        setupKeystrokeMonitor()
        setupDisplayLink()
        setupThemeObserver()
        DispatchQueue.main.async { [weak self] in
            self?.updateDockIcon()
        }
    }
    
    private func setupKeystrokeMonitor() {
        KeystrokeMonitor.shared.onKeystroke = { [weak self] in
            guard let self = self else { return }
            if self.renderLock.try() {
                defer { self.renderLock.unlock() }
                self.currentScene.handleKeystroke()
            }
        }
    }
    
    public func switchScene(to type: SceneType) {
        renderLock.lock()
        defer { renderLock.unlock() }
        
        SoundManager.shared.stopAll()
        AppSettings.shared.currentSceneType = type
        engine.reset()
        let newScene = type.createScene()
        newScene.bake(engine: engine)
        self.currentScene = newScene
        self.hudStatusText = newScene.statusDescription
    }
    
    public func handlePointerDown(screenPoint: CGPoint) {
        renderLock.lock()
        defer { renderLock.unlock() }
        currentScene.handlePointerDown(screenPoint: screenPoint)
    }
    
    public func handlePointerMove(screenPoint: CGPoint) {
        renderLock.lock()
        defer { renderLock.unlock() }
        currentScene.handlePointerMove(screenPoint: screenPoint)
    }
    
    public func handlePointerUp() {
        renderLock.lock()
        defer { renderLock.unlock() }
        currentScene.handlePointerUp()
    }
    
    public func handleActionKey() {
        renderLock.lock()
        defer { renderLock.unlock() }
        currentScene.handleActionKey()
    }
    
    private func setupThemeObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    @objc private func handleThemeChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateDockIcon()
        }
    }
    
    public func updateDockIcon() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let icon = NSImage(named: isDark ? "AppIconDark" : "AppIconLight") {
            NSApplication.shared.applicationIconImage = icon
        }
    }
    
    public func setupScene() {
        renderLock.lock()
        defer { renderLock.unlock() }
        engine.reset()
        currentScene.bake(engine: engine)
    }
    
    private func setupDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let displayLink = link else { return }
        
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let model = Unmanaged<HakoniwaAppModel>.fromOpaque(userInfo).takeUnretainedValue()
            autoreleasepool {
                model.tick()
            }
            return kCVReturnSuccess
        }
        
        CVDisplayLinkSetOutputCallback(displayLink, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink)
        self.displayLink = displayLink
    }
    
    private var lastRenderTime: CFTimeInterval = 0
    private var isDispatchingFrame = false
    private var displayBuffer = [UInt32](repeating: 0, count: PixelEngine.totalPixels)
    
    private func tick() {
        guard !isPaused else { return }
        
        // Energy saving: If wallpaper is off AND window is not visible/occluded, throttle render loop
        let isWallpaperActive = isWallpaperEnabled
        let isWindowVisible: Bool
        if let win = AppSettings.shared.mainWindow {
            isWindowVisible = win.isVisible && win.occlusionState.contains(.visible)
        } else {
            isWindowVisible = true
        }
        if !isWallpaperActive && !isWindowVisible {
            return
        }
        
        // Backpressure: If main thread is still processing previous frame, drop this tick to prevent queue backlog
        if isDispatchingFrame {
            return
        }
        
        // Ensure atomic rendering: skip tick if scene is switching or baking
        guard renderLock.try() else {
            return
        }
        defer { renderLock.unlock() }
        
        let now = CACurrentMediaTime()
        let targetFPS = Double(AppSettings.shared.targetFPS)
        let minInterval = 1.0 / max(1.0, targetFPS)
        if lastRenderTime > 0 && (now - lastRenderTime) < minInterval - 0.002 {
            return
        }
        
        let dt = Float(min(0.05, lastRenderTime > 0 ? (now - lastRenderTime) : 0.016))
        lastRenderTime = now
        
        currentScene.update(dt: dt, engine: engine)
        currentScene.draw(engine: engine)
        
        // Copy to displayBuffer without retaining engine.pix (avoids Swift Array copy-on-write reallocation)
        _ = engine.pix.withUnsafeBufferPointer { src in
            displayBuffer.withUnsafeMutableBufferPointer { dst in
                memcpy(dst.baseAddress!, src.baseAddress!, PixelEngine.totalPixels * MemoryLayout<UInt32>.size)
            }
        }
        
        // Sync HUD snapshot if changed
        let status = currentScene.statusDescription
        if hudStatusText != status {
            DispatchQueue.main.async { [weak self] in
                self?.hudStatusText = status
            }
        }
        if let balote = currentScene as? BaloteScene {
            let scores = balote.score
            let left = balote.left
            let team = balote.team
            if hudScores != scores || hudLeft != left || hudTeam != team {
                DispatchQueue.main.async { [weak self] in
                    self?.hudScores = scores
                    self?.hudLeft = left
                    self?.hudTeam = team
                }
            }
        }
        
        isDispatchingFrame = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            defer { self.isDispatchingFrame = false }
            WallpaperManager.shared.renderFrame(pixels: self.displayBuffer)
            self.onFrameRendered?(self.displayBuffer)
        }
    }
    
    deinit {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }
}
