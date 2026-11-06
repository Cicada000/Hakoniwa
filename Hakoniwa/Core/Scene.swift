//
//  Scene.swift
//  Hakoniwa
//

import Foundation
import CoreGraphics

public protocol HakoniwaScene: AnyObject {
    var sceneId: String { get }
    var sceneName: String { get }
    var sceneIcon: String { get }
    var statusDescription: String { get }
    var originY: Float { get }
    var shadowX: Float { get }
    var shadowY: Float { get }
    
    func bake(engine: PixelEngine)
    func update(dt: Float, engine: PixelEngine)
    func draw(engine: PixelEngine)
    
    func handlePointerDown(screenPoint: CGPoint)
    func handlePointerMove(screenPoint: CGPoint)
    func handlePointerUp()
    func handleActionKey() // space or enter
    func handleKeystroke()
}

extension HakoniwaScene {
    public var sceneName: String { sceneId }
    public var sceneIcon: String { "sparkles" }
    public var statusDescription: String { "" }
    public func handleKeystroke() {}
}
