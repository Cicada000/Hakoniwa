//
//  MathUtils.swift
//  Hakoniwa
//
//  Math utilities adapted from `engine.js` in pixel-plays:
//  https://github.com/amirmushichge/pixel-plays
//  Copyright (c) 2026 Amir Mushich
//  Licensed under the MIT License.
//

import Foundation
import simd

@inline(__always)
public func clamp(_ v: Float, _ a: Float, _ b: Float) -> Float {
    return max(a, min(b, v))
}

@inline(__always)
public func clamp(_ v: Int, _ a: Int, _ b: Int) -> Int {
    return max(a, min(b, v))
}

@inline(__always)
public func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T {
    return max(a, min(b, v))
}

@inline(__always)
public func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
    return a + (b - a) * t
}

@inline(__always)
public func ease(_ t: Float) -> Float {
    return t * t * (3.0 - 2.0 * t)
}

@inline(__always)
public func hash2D(_ x: Float, _ y: Float) -> Float {
    let s = sin(x * 127.1 + y * 311.7) * 43758.5453
    return s - floor(s)
}

public func noise2D(_ x: Float, _ y: Float) -> Float {
    let ix = floor(x)
    let iy = floor(y)
    let fx = ease(x - ix)
    let fy = ease(y - iy)
    let h00 = hash2D(ix, iy)
    let h10 = hash2D(ix + 1.0, iy)
    let h01 = hash2D(ix, iy + 1.0)
    let h11 = hash2D(ix + 1.0, iy + 1.0)
    return lerp(lerp(h00, h10, fx), lerp(h01, h11, fx), fy)
}
