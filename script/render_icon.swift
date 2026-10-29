#!/usr/bin/env swift
// Renders Resources/AppIcon.png: a 1024 px macOS app icon drawn with Core Graphics.
// Usage: swift script/render_icon.swift [output.png]
import AppKit

let tileTop = rgb(0x6E9CFF), tileBottom = rgb(0x3550E0)
let screenTop = rgb(0x0E1C5A), screenBottom = rgb(0x2242B0)
let bezelTop = rgb(0xF6F9FF), bezelBottom = rgb(0xD3DEFA)
let standTop = rgb(0xE6EDFC), standBottom = rgb(0xA9B8DE)
let shadowTint = rgb(0x0A1650)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func white(_ alpha: CGFloat) -> CGColor { CGColor(gray: 1, alpha: alpha) }

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

extension CGContext {
    /// Fills a path with a linear gradient, top to bottom unless `start` and `end` are given.
    func fill(_ path: CGPath, from top: CGColor, to bottom: CGColor, start: CGPoint? = nil, end: CGPoint? = nil) {
        let box = path.boundingBox
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top, bottom] as CFArray, locations: [0, 1])!
        saveGState()
        addPath(path)
        clip()
        drawLinearGradient(gradient, start: start ?? CGPoint(x: box.midX, y: box.minY),
                           end: end ?? CGPoint(x: box.midX, y: box.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        restoreGState()
    }

    func withShadow(offset: CGFloat, blur: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
        saveGState()
        // The context is flipped, so a positive height moves the shadow down.
        setShadow(offset: CGSize(width: 0, height: offset), blur: blur, color: shadowTint.copy(alpha: alpha)!)
        beginTransparencyLayer(auxiliaryInfo: nil)
        draw()
        endTransparencyLayer()
        restoreGState()
    }
}

let size = 1024
let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.png"
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Draw in top-left coordinates.
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1)

// Tile: the standard 824 px macOS icon grid on a 1024 px canvas, with a ~22.5% corner radius.
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tile = roundedRect(tileRect, 185)
context.withShadow(offset: 12, blur: 28, alpha: 0.35) {
    context.fill(tile, from: tileTop, to: tileBottom)
}
context.saveGState()
context.addPath(tile)
context.clip()
// A soft sheen across the upper half and a fine rim keep the tile from looking flat.
context.fill(CGPath(rect: CGRect(x: 100, y: 100, width: 824, height: 460), transform: nil), from: white(0.16), to: white(0))
context.addPath(tile)
context.setStrokeColor(white(0.30))
context.setLineWidth(4)
context.strokePath()
context.restoreGState()

// Two glass panels recede up and to the right of the main display: several remote Macs.
let displaySize = CGSize(width: 512, height: 320)
let step = CGSize(width: 80, height: -80)
let front = CGRect(origin: CGPoint(x: 176, y: 408), size: displaySize)
for (depth, alpha) in [(2, 0.22), (1, 0.34)] as [(CGFloat, CGFloat)] {
    let rect = front.offsetBy(dx: step.width * depth, dy: step.height * depth)
    let panel = roundedRect(rect, 40)
    context.withShadow(offset: 10, blur: 24, alpha: 0.18) {
        context.fill(panel, from: white(alpha + 0.08), to: white(alpha - 0.06))
    }
    context.addPath(panel)
    context.setStrokeColor(white(0.5))
    context.setLineWidth(4)
    context.strokePath()
    context.addPath(roundedRect(rect.insetBy(dx: 22, dy: 22), 22))
    context.setFillColor(white(0.14))
    context.fillPath()
}

// Main display: bezel, stand, and dark glass screen.
let neck = CGMutablePath()
neck.addLines(between: [CGPoint(x: front.midX - 52, y: front.maxY - 8), CGPoint(x: front.midX + 52, y: front.maxY - 8),
                        CGPoint(x: front.midX + 72, y: front.maxY + 72), CGPoint(x: front.midX - 72, y: front.maxY + 72)])
neck.closeSubpath()
let base = roundedRect(CGRect(x: front.midX - 116, y: front.maxY + 64, width: 232, height: 28), 14)
context.withShadow(offset: 18, blur: 36, alpha: 0.40) {
    context.fill(neck, from: standTop, to: standBottom)
    context.fill(base, from: standTop, to: standBottom)
    context.fill(roundedRect(front, 44), from: bezelTop, to: bezelBottom)
}
let screenRect = front.insetBy(dx: 22, dy: 22)
let screen = roundedRect(screenRect, 24)
context.fill(screen, from: screenTop, to: screenBottom)
// Diagonal glare on the glass.
context.saveGState()
context.addPath(screen)
context.clip()
let glare = CGMutablePath()
glare.addLines(between: [CGPoint(x: screenRect.minX, y: screenRect.minY), CGPoint(x: screenRect.minX + 280, y: screenRect.minY),
                         CGPoint(x: screenRect.minX + 110, y: screenRect.maxY), CGPoint(x: screenRect.minX, y: screenRect.maxY)])
glare.closeSubpath()
context.fill(glare, from: white(0.14), to: white(0.03))
// A menu bar and a soft glow suggest a remote desktop without drawing a screen inside a screen.
context.setFillColor(white(0.20))
context.fill(CGRect(x: screenRect.minX, y: screenRect.minY, width: screenRect.width, height: 22))
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(0x7FB2FF, 0.55), rgb(0x7FB2FF, 0)] as CFArray, locations: [0, 1])!
context.drawRadialGradient(glow, startCenter: CGPoint(x: screenRect.maxX - 120, y: screenRect.maxY - 40), startRadius: 0,
                           endCenter: CGPoint(x: screenRect.maxX - 120, y: screenRect.maxY - 40), endRadius: 300, options: [])
context.restoreGState()

let image = context.makeImage()!
let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: output))
print(output)
