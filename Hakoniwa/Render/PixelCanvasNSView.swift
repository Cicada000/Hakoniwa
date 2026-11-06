//
//  PixelCanvasNSView.swift
//  Hakoniwa
//

import AppKit
import QuartzCore

public final class PixelCanvasNSView: NSView {
    private let imageLayer = CALayer()
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    
    private var pixelBuffer = [UInt32](repeating: 0, count: PixelEngine.totalPixels)
    private lazy var bitmapContext: CGContext? = {
        CGContext(
            data: &pixelBuffer,
            width: PixelEngine.W,
            height: PixelEngine.H,
            bitsPerComponent: 8,
            bytesPerRow: PixelEngine.W * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )
    }()
    
    public var onPointerDown: ((CGPoint) -> Void)?
    public var onPointerMove: ((CGPoint) -> Void)?
    public var onPointerUp: (() -> Void)?
    public var onActionKey: (() -> Void)?
    public var onAppearanceChanged: (() -> Void)?
    
    public var contentScaleMultiplier: CGFloat = 1.0 {
        didSet {
            needsLayout = true
            updateLayerFrame()
        }
    }
    
    private var isDragging = false
    
    public override var isFlipped: Bool { true }
    
    public override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        
        imageLayer.isOpaque = false
        imageLayer.magnificationFilter = .nearest
        imageLayer.minificationFilter = .nearest
        imageLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "frame": NSNull()]
        layer?.addSublayer(imageLayer)
    }
    
    public override func layout() {
        super.layout()
        updateLayerFrame()
    }
    
    public func getDrawnRect() -> CGRect {
        let viewW = bounds.width
        let viewH = bounds.height
        guard viewW > 0 && viewH > 0 else { return .zero }
        
        let fitScale = min(Float(viewW) / Float(PixelEngine.W), Float(viewH) / Float(PixelEngine.H)) * Float(contentScaleMultiplier)
        let scale = CGFloat(max(1.0, fitScale))
        
        let drawnW = CGFloat(PixelEngine.W) * scale
        let drawnH = CGFloat(PixelEngine.H) * scale
        let originX = (viewW - drawnW) / 2.0
        let originY = (viewH - drawnH) / 2.0
        return CGRect(x: originX, y: originY, width: drawnW, height: drawnH)
    }
    
    private func updateLayerFrame() {
        let rect = getDrawnRect()
        if imageLayer.frame != rect {
            imageLayer.frame = rect
        }
    }
    
    public func convertToCanvas(point: CGPoint, checkBounds: Bool = true) -> CGPoint? {
        let rect = getDrawnRect()
        if checkBounds && !rect.contains(point) { return nil }
        guard rect.width > 0 && rect.height > 0 else { return nil }
        let relX = (point.x - rect.origin.x) / rect.width * CGFloat(PixelEngine.W)
        let relY = (point.y - rect.origin.y) / rect.height * CGFloat(PixelEngine.H)
        return CGPoint(x: relX, y: relY)
    }
    
    public func updateFrame(with pixels: [UInt32]) {
        _ = pixels.withUnsafeBufferPointer { src in
            pixelBuffer.withUnsafeMutableBufferPointer { dst in
                memcpy(dst.baseAddress!, src.baseAddress!, PixelEngine.totalPixels * 4)
            }
        }
        
        autoreleasepool {
            if let image = bitmapContext?.makeImage() {
                imageLayer.contents = image
            }
        }
    }
    
    // MARK: - Direct Mouse Events
    
    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let rect = getDrawnRect()
        if rect.contains(loc) {
            isDragging = true
            if let canvasPt = convertToCanvas(point: loc, checkBounds: false) {
                onPointerDown?(canvasPt)
            }
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if let canvasPt = convertToCanvas(point: loc, checkBounds: false) {
            onPointerMove?(canvasPt)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            onPointerUp?()
        }
    }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 || event.keyCode == 36 { // Space or Enter
            onActionKey?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChanged?()
    }
    
    public override var acceptsFirstResponder: Bool { true }
}
