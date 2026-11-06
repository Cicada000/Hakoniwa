//
//  WallpaperManager.swift
//  Hakoniwa
//

import AppKit

public final class DesktopWallpaperWindow: NSWindow {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

public final class WallpaperManager {
    public static let shared = WallpaperManager()
    
    // Very light grey (#F2F3F6) and very dark grey (#1C1D21), never pure white or pure black
    public static let lightDesktopColor = NSColor(red: 242/255, green: 243/255, blue: 246/255, alpha: 1.0)
    public static let darkDesktopColor = NSColor(red: 28/255, green: 29/255, blue: 33/255, alpha: 1.0)
    
    private var wallpaperWindow: DesktopWallpaperWindow?
    private var canvasView: PixelCanvasNSView?
    private let eventMonitor = DesktopEventMonitor()
    
    public var isWallpaperActive: Bool {
        wallpaperWindow != nil
    }
    
    private init() {
        setupEventMonitor()
        setupThemeObserver()
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
            self?.updateDesktopTheme(animated: true)
        }
    }
    
    public func updateDesktopTheme(animated: Bool = true) {
        guard let win = wallpaperWindow else { return }
        let isTransparent = AppSettings.shared.wallpaperBackgroundStyle == .transparent
        let isDark = AppSettings.shared.isDarkMode
        let targetColor = isDark ? Self.darkDesktopColor : Self.lightDesktopColor
        
        if isTransparent {
            win.isOpaque = false
            let transparentTarget = win.backgroundColor?.withAlphaComponent(0.0) ?? NSColor.clear
            if animated {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.5
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    win.animator().backgroundColor = transparentTarget
                } completionHandler: {
                    win.backgroundColor = NSColor.clear
                }
            } else {
                win.backgroundColor = NSColor.clear
            }
        } else {
            if animated {
                if win.backgroundColor == NSColor.clear {
                    win.backgroundColor = targetColor.withAlphaComponent(0.0)
                }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.5
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    win.animator().backgroundColor = targetColor
                } completionHandler: {
                    win.isOpaque = true
                }
            } else {
                win.backgroundColor = targetColor
                win.isOpaque = true
            }
        }
    }
    
    private func setupEventMonitor() {
        eventMonitor.onGlobalMouseDown = { [weak self] screenPt in
            guard AppSettings.shared.desktopInteractionEnabled else { return false }
            guard let self = self, let win = self.wallpaperWindow, let view = self.canvasView else { return false }
            let ptInWin = win.convertPoint(fromScreen: screenPt)
            let ptInView = view.convert(ptInWin, from: nil)
            if let canvasPt = view.convertToCanvas(point: ptInView, checkBounds: true) {
                HakoniwaAppModel.shared.currentScene.handlePointerDown(screenPoint: canvasPt)
                return true
            }
            return false
        }
        
        eventMonitor.onGlobalMouseDragged = { [weak self] screenPt in
            guard AppSettings.shared.desktopInteractionEnabled else { return }
            guard let self = self, let win = self.wallpaperWindow, let view = self.canvasView else { return }
            let ptInWin = win.convertPoint(fromScreen: screenPt)
            let ptInView = view.convert(ptInWin, from: nil)
            if let canvasPt = view.convertToCanvas(point: ptInView, checkBounds: false) {
                HakoniwaAppModel.shared.currentScene.handlePointerMove(screenPoint: canvasPt)
            }
        }
        
        eventMonitor.onGlobalMouseUp = {
            HakoniwaAppModel.shared.currentScene.handlePointerUp()
        }
    }
    
    public func enableWallpaper(on targetScreen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        disableWallpaper()
        
        let screenRect = targetScreen.frame
        let window = DesktopWallpaperWindow(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: targetScreen
        )
        
        // Sits strictly at true desktop wallpaper level (below all desktop icons and files)
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        let isTransparent = AppSettings.shared.wallpaperBackgroundStyle == .transparent
        window.isOpaque = !isTransparent
        
        let isDark = AppSettings.shared.isDarkMode
        let solidColor = isDark ? Self.darkDesktopColor : Self.lightDesktopColor
        window.backgroundColor = isTransparent ? NSColor.clear : solidColor
        window.hasShadow = false
        window.ignoresMouseEvents = true // Zero interference with other windows or desktop icons!
        
        let view = PixelCanvasNSView(frame: NSRect(origin: .zero, size: screenRect.size))
        view.contentScaleMultiplier = CGFloat(AppSettings.shared.desktopScale)
        view.onAppearanceChanged = { [weak self] in
            self?.updateDesktopTheme(animated: true)
        }
        window.contentView = view
        window.orderFrontRegardless()
        
        self.wallpaperWindow = window
        self.canvasView = view
        
        eventMonitor.isEnabled = true
    }
    
    public func updateDesktopScale() {
        guard let view = canvasView else { return }
        view.contentScaleMultiplier = CGFloat(AppSettings.shared.desktopScale)
    }
    
    public func disableWallpaper() {
        eventMonitor.isEnabled = false
        wallpaperWindow?.orderOut(nil)
        wallpaperWindow = nil
        canvasView = nil
    }
    
    public func renderFrame(pixels: [UInt32]) {
        canvasView?.updateFrame(with: pixels)
    }
}
