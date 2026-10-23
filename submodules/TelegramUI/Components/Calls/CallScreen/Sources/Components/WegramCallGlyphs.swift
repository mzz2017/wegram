import Foundation
import CoreGraphics

// WeChat's voice-call glyphs, drawn to proportions measured on a 402x874 WeChat 8 outgoing-call
// screenshot. Every function draws in
// points around (0, 0), the centre of the glyph's button, in a y-down context.

func drawWegramCallMicrophone(_ context: CGContext, color: CGColor, isMuted: Bool) {
    context.saveGState()
    defer {
        context.restoreGState()
    }
    if isMuted {
        context.beginTransparencyLayer(auxiliaryInfo: nil)
    }
    context.setFillColor(color)
    context.setStrokeColor(color)

    context.addPath(CGPath(roundedRect: CGRect(x: -6.34, y: -14.6, width: 12.68, height: 21.0), cornerWidth: 6.34, cornerHeight: 6.34, transform: nil))
    context.fillPath()

    let radius: CGFloat = 10.49
    let arcCenterY: CGFloat = 0.4
    context.setLineWidth(3.06)
    context.setLineCap(.butt)
    context.move(to: CGPoint(x: -radius, y: -1.5))
    context.addLine(to: CGPoint(x: -radius, y: arcCenterY))
    context.addArc(center: CGPoint(x: 0.0, y: arcCenterY), radius: radius, startAngle: .pi, endAngle: 0.0, clockwise: true)
    context.addLine(to: CGPoint(x: radius, y: -1.5))
    context.strokePath()

    context.fill(CGRect(x: -1.53, y: arcCenterY + radius, width: 3.06, height: 16.8 - arcCenterY - radius))

    if isMuted {
        drawWegramCallSlash(context, color: color, from: CGPoint(x: -11.6, y: -14.6), to: CGPoint(x: 14.0, y: 15.4))
        context.endTransparencyLayer()
    }
}

func drawWegramCallSpeaker(_ context: CGContext, color: CGColor, isOn: Bool) {
    context.saveGState()
    defer {
        context.restoreGState()
    }
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setFillColor(color)
    context.setStrokeColor(color)

    let body = CGMutablePath()
    body.addRoundedRect(in: CGRect(x: -16.4, y: -5.5, width: 9.0, height: 11.4), cornerWidth: 1.2, cornerHeight: 1.2)
    context.addPath(body)
    context.fillPath()

    let cone = CGMutablePath()
    cone.move(to: CGPoint(x: -8.4, y: -5.5))
    cone.addLine(to: CGPoint(x: 0.6, y: -11.9))
    cone.addQuadCurve(to: CGPoint(x: 1.97, y: -11.2), control: CGPoint(x: 1.97, y: -12.8))
    cone.addLine(to: CGPoint(x: 1.97, y: 11.6))
    cone.addQuadCurve(to: CGPoint(x: 0.6, y: 12.3), control: CGPoint(x: 1.97, y: 13.2))
    cone.addLine(to: CGPoint(x: -8.4, y: 5.9))
    cone.closeSubpath()
    context.addPath(cone)
    context.fillPath()

    context.setLineCap(.round)
    let halfAngle: CGFloat = 43.0 * .pi / 180.0
    context.setLineWidth(3.06)
    context.addArc(center: CGPoint(x: 0.0, y: -0.2), radius: 8.74, startAngle: -halfAngle, endAngle: halfAngle, clockwise: false)
    context.strokePath()
    context.setLineWidth(2.7)
    context.addArc(center: CGPoint(x: 0.0, y: -0.2), radius: 13.33, startAngle: -halfAngle, endAngle: halfAngle, clockwise: false)
    context.strokePath()

    if !isOn {
        drawWegramCallSlash(context, color: color, from: CGPoint(x: -11.1, y: -14.4), to: CGPoint(x: 15.3, y: 14.8))
    }
    context.endTransparencyLayer()
}

/// A slash that cuts a clear margin out of what it crosses. The caller must be inside a
/// transparency layer so the cut does not reach the button underneath.
private func drawWegramCallSlash(_ context: CGContext, color: CGColor, from: CGPoint, to: CGPoint) {
    context.setLineCap(.round)
    context.setBlendMode(.clear)
    context.setLineWidth(2.6 + 2.0 * 1.3)
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
    context.setBlendMode(.normal)
    context.setStrokeColor(color)
    context.setLineWidth(2.6)
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
}

public func drawWegramCallHangUp(_ context: CGContext, color: CGColor) {
    context.saveGState()
    defer {
        context.restoreGState()
    }
    context.setFillColor(color)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: -13.9, y: 4.6))
    path.addQuadCurve(to: CGPoint(x: -19.7, y: 0.6), control: CGPoint(x: -19.9, y: 5.4))
    path.addCurve(to: CGPoint(x: 19.9, y: 0.6), control1: CGPoint(x: -18.2, y: -13.6), control2: CGPoint(x: 18.4, y: -13.6))
    path.addQuadCurve(to: CGPoint(x: 14.1, y: 4.6), control: CGPoint(x: 20.1, y: 5.4))
    path.addQuadCurve(to: CGPoint(x: 8.8, y: 1.0), control: CGPoint(x: 9.6, y: 3.6))
    path.addQuadCurve(to: CGPoint(x: 7.6, y: -3.9), control: CGPoint(x: 8.4, y: -2.8))
    path.addQuadCurve(to: CGPoint(x: -7.4, y: -3.9), control: CGPoint(x: 0.1, y: -7.6))
    path.addQuadCurve(to: CGPoint(x: -8.6, y: 1.0), control: CGPoint(x: -8.2, y: -2.8))
    path.addQuadCurve(to: CGPoint(x: -13.9, y: 4.6), control: CGPoint(x: -9.4, y: 3.6))
    path.closeSubpath()
    context.addPath(path)
    context.fillPath()
}

func drawWegramCallMinimize(_ context: CGContext, color: CGColor) {
    context.saveGState()
    defer {
        context.restoreGState()
    }
    context.setStrokeColor(color)
    context.setLineWidth(1.75)
    context.setLineCap(.butt)
    context.setLineJoin(.round)
    let corner: CGFloat = 1.6
    let big = CGRect(x: -10.7, y: -9.84, width: 17.47, height: 16.24)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: big.maxX, y: -3.3))
    path.addLine(to: CGPoint(x: big.maxX, y: big.minY + corner))
    path.addArc(tangent1End: CGPoint(x: big.maxX, y: big.minY), tangent2End: CGPoint(x: big.minX, y: big.minY), radius: corner)
    path.addArc(tangent1End: CGPoint(x: big.minX, y: big.minY), tangent2End: CGPoint(x: big.minX, y: big.maxY), radius: corner)
    path.addArc(tangent1End: CGPoint(x: big.minX, y: big.maxY), tangent2End: CGPoint(x: big.maxX, y: big.maxY), radius: corner)
    path.addLine(to: CGPoint(x: -3.3, y: big.maxY))
    context.addPath(path)
    context.strokePath()
    context.addPath(CGPath(roundedRect: CGRect(x: 0.21, y: 0.66, width: 10.5, height: 9.61), cornerWidth: 2.4, cornerHeight: 2.4, transform: nil))
    context.strokePath()
}

func drawWegramCallPlus(_ context: CGContext, color: CGColor) {
    context.saveGState()
    defer {
        context.restoreGState()
    }
    context.setStrokeColor(color)
    context.setLineWidth(1.5)
    context.move(to: CGPoint(x: -8.5, y: 0.0))
    context.addLine(to: CGPoint(x: 8.5, y: 0.0))
    context.move(to: CGPoint(x: 0.0, y: -8.5))
    context.addLine(to: CGPoint(x: 0.0, y: 8.5))
    context.strokePath()
}
