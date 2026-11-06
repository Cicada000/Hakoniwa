//
//  DesktopEventMonitor.swift
//  Hakoniwa
//

import AppKit

public final class DesktopEventMonitor {
    private var downMonitor: Any?
    private var dragMonitor: Any?
    private var upMonitor: Any?
    private var isDragging = false
    
    public var isEnabled: Bool = false {
        didSet {
            if isEnabled { start() } else { stop() }
        }
    }
    
    public var onGlobalMouseDown: ((CGPoint) -> Bool)?
    public var onGlobalMouseDragged: ((CGPoint) -> Void)?
    public var onGlobalMouseUp: (() -> Void)?
    
    public init() {}
    
    public func start() {
        stop()
        
        // Passive monitors that NEVER block or swallow events for other windows!
        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self else { return }
            // Only trigger if frontmost application is Finder (i.e. user clicked on the desktop!)
            let front = NSWorkspace.shared.frontmostApplication
            guard front?.bundleIdentifier == "com.apple.finder" else { return }
            
            let mouseLoc = NSEvent.mouseLocation
            if let consumed = self.onGlobalMouseDown?(mouseLoc), consumed {
                self.isDragging = true
            }
        }
        
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            guard let self = self, self.isDragging else { return }
            let mouseLoc = NSEvent.mouseLocation
            self.onGlobalMouseDragged?(mouseLoc)
        }
        
        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            if self.isDragging {
                self.isDragging = false
                self.onGlobalMouseUp?()
            }
        }
    }
    
    public func stop() {
        if let m = downMonitor { NSEvent.removeMonitor(m); downMonitor = nil }
        if let m = dragMonitor { NSEvent.removeMonitor(m); dragMonitor = nil }
        if let m = upMonitor { NSEvent.removeMonitor(m); upMonitor = nil }
        isDragging = false
    }
    
    deinit {
        stop()
    }
}
