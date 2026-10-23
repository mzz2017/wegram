import UIKit
import Display

/// Template artwork shared by the four WeChat-style tabs and chat-list shortcuts.
public enum WegramIcon: String {
    case chats = "Wegram/Chats"
    case contacts = "Wegram/Contacts"
    case discover = "Wegram/Discover"
    case me = "Wegram/Me"
    case star = "Wegram/Star"
    case plus = "Wegram/Plus"
    case chatMore = "Wegram/ChatMore"
    case chatInputMore = "Wegram/ChatInputMore"
    case chatInputVoice = "Wegram/ChatInputVoice"
    case chatInputEmoji = "Wegram/ChatInputEmoji"
    case chatInputKeyboard = "Wegram/ChatInputKeyboard"
    case addContact = "Wegram/AddContact"
    case moments = "Wegram/Moments"
    case scan = "Wegram/Scan"
    case search = "Wegram/Search"
    case navigationSearch = "Wegram/NavigationSearch"
    case miniPrograms = "Wegram/MiniPrograms"
    case phoneContacts = "Wegram/PhoneContacts"
    case officialAccounts = "Wegram/OfficialAccounts"
    case serviceAccounts = "Wegram/ServiceAccounts"
    case attachmentPhoto = "Wegram/AttachmentPhoto"
    case attachmentCamera = "Wegram/AttachmentCamera"
    case attachmentVideo = "Wegram/AttachmentVideo"
    case attachmentLocation = "Wegram/AttachmentLocation"
    case attachmentContact = "Wegram/AttachmentContact"
    case attachmentFile = "Wegram/AttachmentFile"
    case attachmentMusic = "Wegram/AttachmentMusic"
    case attachmentFavorite = "Wegram/AttachmentFavorite"
    case attachmentVoiceInput = "Wegram/AttachmentVoiceInput"

    public func image(selected: Bool = false) -> UIImage? {
        return generateImage(CGSize(width: 28.0, height: 28.0), rotatedContext: { _, context in
            context.clear(CGRect(x: 0, y: 0, width: 28, height: 28))
            context.setStrokeColor(UIColor.black.cgColor)
            context.setFillColor(UIColor.black.cgColor)
            context.setLineWidth(1.5)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            func draw(_ path: CGPath, filled: Bool = false) {
                context.addPath(path)
                context.drawPath(using: filled ? .fill : .stroke)
            }
            switch self {
            case .attachmentPhoto:
                draw(UIBezierPath(roundedRect: CGRect(x: 1.5, y: 4, width: 25, height: 20), cornerRadius: 1.25).cgPath, filled: true)
                let sky = UIBezierPath()
                sky.move(to: CGPoint(x: 3.5, y: 6))
                sky.addLine(to: CGPoint(x: 24.5, y: 6))
                sky.addLine(to: CGPoint(x: 24.5, y: 17))
                sky.addLine(to: CGPoint(x: 20, y: 14))
                sky.addLine(to: CGPoint(x: 17, y: 17))
                sky.addLine(to: CGPoint(x: 10, y: 11.5))
                sky.addLine(to: CGPoint(x: 3.5, y: 17))
                sky.close()
                context.saveGState()
                context.setBlendMode(.clear)
                draw(sky.cgPath, filled: true)
                context.restoreGState()
            case .attachmentCamera:
                draw(UIBezierPath(roundedRect: CGRect(x: 1.5, y: 8, width: 25, height: 16), cornerRadius: 1.25).cgPath, filled: true)
                let top = UIBezierPath()
                top.move(to: CGPoint(x: 7.5, y: 9))
                top.addLine(to: CGPoint(x: 10, y: 4))
                top.addLine(to: CGPoint(x: 18, y: 4))
                top.addLine(to: CGPoint(x: 20.5, y: 9))
                top.close()
                draw(top.cgPath, filled: true)
                context.saveGState()
                context.setBlendMode(.clear)
                draw(UIBezierPath(ovalIn: CGRect(x: 9.5, y: 11, width: 9, height: 9)).cgPath, filled: true)
                context.restoreGState()
            case .attachmentVideo:
                draw(UIBezierPath(roundedRect: CGRect(x: 1, y: 6, width: 19, height: 16), cornerRadius: 1.25).cgPath, filled: true)
                let lens = UIBezierPath()
                lens.move(to: CGPoint(x: 21.5, y: 11))
                lens.addLine(to: CGPoint(x: 25.5, y: 8))
                lens.addQuadCurve(to: CGPoint(x: 27, y: 9), controlPoint: CGPoint(x: 27, y: 7))
                lens.addLine(to: CGPoint(x: 27, y: 19))
                lens.addQuadCurve(to: CGPoint(x: 25.5, y: 20), controlPoint: CGPoint(x: 27, y: 21))
                lens.addLine(to: CGPoint(x: 21.5, y: 17))
                lens.close()
                draw(lens.cgPath, filled: true)
            case .attachmentVoiceInput:
                context.saveGState()
                context.translateBy(x: 14, y: 14)
                context.rotate(by: 0.32)
                context.translateBy(x: -14, y: -14)
                draw(UIBezierPath(roundedRect: CGRect(x: 10, y: 1, width: 8, height: 16), cornerRadius: 4).cgPath, filled: true)
                let stand = UIBezierPath()
                stand.move(to: CGPoint(x: 6.5, y: 12))
                stand.addCurve(to: CGPoint(x: 21.5, y: 12), controlPoint1: CGPoint(x: 6.5, y: 26), controlPoint2: CGPoint(x: 21.5, y: 26))
                draw(stand.cgPath)
                context.move(to: CGPoint(x: 14, y: 22))
                context.addLine(to: CGPoint(x: 14, y: 27))
                context.strokePath()
                context.restoreGState()
            case .attachmentFavorite:
                for points in [
                    [CGPoint(x: 14, y: 1), CGPoint(x: 26, y: 7.5), CGPoint(x: 14, y: 14), CGPoint(x: 2, y: 7.5)],
                    [CGPoint(x: 2, y: 9.5), CGPoint(x: 13, y: 15.5), CGPoint(x: 13, y: 27), CGPoint(x: 2, y: 20.5)],
                    [CGPoint(x: 15, y: 15.5), CGPoint(x: 26, y: 9.5), CGPoint(x: 26, y: 20.5), CGPoint(x: 15, y: 27)]
                ] {
                    let face = UIBezierPath()
                    face.move(to: points[0])
                    for point in points.dropFirst() { face.addLine(to: point) }
                    face.close()
                    draw(face.cgPath, filled: true)
                }
            case .attachmentContact:
                draw(UIBezierPath(ovalIn: CGRect(x: 9, y: 2, width: 10, height: 12)).cgPath, filled: true)
                let person = UIBezierPath()
                person.move(to: CGPoint(x: 10, y: 12))
                person.addLine(to: CGPoint(x: 10, y: 16))
                person.addCurve(to: CGPoint(x: 2, y: 23), controlPoint1: CGPoint(x: 9, y: 19), controlPoint2: CGPoint(x: 2, y: 18))
                person.addLine(to: CGPoint(x: 2, y: 26))
                person.addLine(to: CGPoint(x: 26, y: 26))
                person.addLine(to: CGPoint(x: 26, y: 23))
                person.addCurve(to: CGPoint(x: 18, y: 16), controlPoint1: CGPoint(x: 26, y: 18), controlPoint2: CGPoint(x: 19, y: 19))
                person.addLine(to: CGPoint(x: 18, y: 12))
                person.close()
                draw(person.cgPath, filled: true)
            case .attachmentFile:
                let folder = UIBezierPath()
                folder.move(to: CGPoint(x: 2, y: 4))
                folder.addLine(to: CGPoint(x: 11, y: 4))
                folder.addLine(to: CGPoint(x: 14, y: 7))
                folder.addLine(to: CGPoint(x: 26, y: 7))
                folder.addLine(to: CGPoint(x: 26, y: 25))
                folder.addLine(to: CGPoint(x: 2, y: 25))
                folder.close()
                draw(folder.cgPath, filled: true)
                context.saveGState()
                context.setBlendMode(.clear)
                context.fill(CGRect(x: 5, y: 11, width: 18, height: 2.5))
                context.restoreGState()
            case .attachmentMusic:
                let beam = UIBezierPath()
                beam.move(to: CGPoint(x: 12, y: 7))
                beam.addLine(to: CGPoint(x: 26, y: 4))
                beam.addLine(to: CGPoint(x: 26, y: 9))
                beam.addLine(to: CGPoint(x: 14.5, y: 11.5))
                beam.addLine(to: CGPoint(x: 14.5, y: 23))
                beam.addLine(to: CGPoint(x: 12, y: 23))
                beam.close()
                draw(beam.cgPath, filled: true)
                context.fill(CGRect(x: 23.5, y: 7, width: 2.5, height: 15))
                draw(UIBezierPath(ovalIn: CGRect(x: 7.5, y: 20, width: 7, height: 7)).cgPath, filled: true)
                draw(UIBezierPath(ovalIn: CGRect(x: 19, y: 18.5, width: 7, height: 7)).cgPath, filled: true)
                let note = UIBezierPath()
                note.move(to: CGPoint(x: 5, y: 3))
                note.addLine(to: CGPoint(x: 10, y: 2))
                note.addLine(to: CGPoint(x: 10.5, y: 4.5))
                note.addLine(to: CGPoint(x: 7.5, y: 5))
                note.addLine(to: CGPoint(x: 8.5, y: 11))
                note.addLine(to: CGPoint(x: 6, y: 11))
                note.close()
                draw(note.cgPath, filled: true)
                draw(UIBezierPath(ovalIn: CGRect(x: 2, y: 9, width: 6.5, height: 6)).cgPath, filled: true)
            case .attachmentLocation:
                let pin = UIBezierPath()
                pin.move(to: CGPoint(x: 14, y: 27))
                pin.addCurve(to: CGPoint(x: 4, y: 11), controlPoint1: CGPoint(x: 12, y: 27), controlPoint2: CGPoint(x: 4, y: 17))
                pin.addCurve(to: CGPoint(x: 14, y: 1), controlPoint1: CGPoint(x: 4, y: 5.5), controlPoint2: CGPoint(x: 8.5, y: 1))
                pin.addCurve(to: CGPoint(x: 24, y: 11), controlPoint1: CGPoint(x: 19.5, y: 1), controlPoint2: CGPoint(x: 24, y: 5.5))
                pin.addCurve(to: CGPoint(x: 14, y: 27), controlPoint1: CGPoint(x: 24, y: 17), controlPoint2: CGPoint(x: 16, y: 27))
                pin.close()
                draw(pin.cgPath, filled: true)
                context.saveGState()
                context.setBlendMode(.clear)
                draw(UIBezierPath(ovalIn: CGRect(x: 9.5, y: 6.5, width: 9, height: 9)).cgPath, filled: true)
                context.restoreGState()
            case .moments:
                // The four 发现 glyphs are drawn on WeChat's 24pt grid: the rows show this 28pt canvas in a 24pt box,
                // which makes the grid 1:1 there.
                context.scaleBy(x: 28.0 / 24.0, y: 28.0 / 24.0)
                // A ring and eight pinwheel lines, traced from IMG_2442. Each line is a side of an octagon 3.65pt from
                // the centre: it starts at one corner and runs past the other out to the ring, and it shares its colour
                // with the 45° of ring it opens into.
                context.setLineWidth(1.2)
                let center = CGPoint(x: 12, y: 12)
                let radius: CGFloat = 9.4
                let inset: CGFloat = 3.65
                let colors: [UInt32] = [0xfa9d3b, 0xfa5151, 0x6467f0, 0x1485ee, 0x10aeff, 0x07c160, 0x91d300, 0xffc300]
                for index in 0..<8 {
                    let normal = -.pi / 2 + CGFloat(index) * .pi / 4
                    let cornerDistance = inset / cos(.pi / 8)
                    let start = CGPoint(x: center.x + cornerDistance * cos(normal + .pi / 8), y: center.y + cornerDistance * sin(normal + .pi / 8))
                    let direction = normal - .pi / 2
                    let offset = CGPoint(x: start.x - center.x, y: start.y - center.y)
                    let along = offset.x * cos(direction) + offset.y * sin(direction)
                    let length = -along + sqrt(along * along - offset.x * offset.x - offset.y * offset.y + radius * radius)
                    let end = CGPoint(x: start.x + length * cos(direction), y: start.y + length * sin(direction))
                    let endAngle = atan2(end.y - center.y, end.x - center.x)
                    let line = UIBezierPath()
                    line.move(to: start)
                    line.addLine(to: end)
                    line.addArc(withCenter: center, radius: radius, startAngle: endAngle, endAngle: endAngle + .pi / 4, clockwise: true)
                    context.setStrokeColor(UIColor(rgb: colors[index]).cgColor)
                    draw(line.cgPath)
                }
            case .scan:
                context.scaleBy(x: 28.0 / 24.0, y: 28.0 / 24.0)
                // Two hooked loops, a half turn apart about the centre: a round top, a finger pointing across the
                // middle and a tight U at the foot. Traced from IMG_2442 (ink 19pt square, 1.25pt stroke).
                context.setLineWidth(1.25)
                let loop = UIBezierPath()
                loop.move(to: CGPoint(x: -8.667, y: 0.667))
                loop.addLine(to: CGPoint(x: -8.667, y: -4.667))
                loop.addArc(withCenter: CGPoint(x: -4.333, y: -4.667), radius: 4.333, startAngle: .pi, endAngle: 0, clockwise: true)
                loop.addLine(to: CGPoint(x: 3.833, y: -4.667))
                loop.addArc(withCenter: CGPoint(x: 3.833, y: -3.583), radius: 1.083, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
                loop.addLine(to: CGPoint(x: -5.833, y: -2.5))
                loop.addLine(to: CGPoint(x: -5.833, y: 0.667))
                loop.addArc(withCenter: CGPoint(x: -7.25, y: 0.667), radius: 1.417, startAngle: 0, endAngle: .pi, clockwise: true)
                loop.close()
                for quarter in [0, 2] {
                    let path = loop.copy() as! UIBezierPath
                    path.apply(CGAffineTransform(rotationAngle: CGFloat(quarter) * .pi / 2))
                    path.apply(CGAffineTransform(translationX: 12, y: 12))
                    draw(path.cgPath)
                }
            case .navigationSearch:
                // Outline magnifier, 18pt square ink box measured from the 2026-10-23 scroll recording; the 2.2pt
                // shift puts it 40pt from the add icon (the buttons are 44pt apart).
                context.translateBy(x: 2.2, y: 0.0)
                draw(UIBezierPath(ovalIn: CGRect(x: 5.4, y: 5.4, width: 12.6, height: 12.6)).cgPath)
                context.move(to: CGPoint(x: 16.6, y: 16.6))
                context.addLine(to: CGPoint(x: 22.4, y: 22.4))
                context.strokePath()
            case .search:
                context.scaleBy(x: 28.0 / 24.0, y: 28.0 / 24.0)
                // Five flat-ended rays tapering linearly from 1.1pt wide inside to 2.34pt at the tip, corners
                // rounded 0.5pt. End points and widths measured per ray from IMG_2442 at 3x.
                let rays: [(inner: CGPoint, outer: CGPoint)] = [
                    (CGPoint(x: 10.03, y: 7.9), CGPoint(x: 12.08, y: 1.56)),
                    (CGPoint(x: 12.09, y: 9.78), CGPoint(x: 22.41, y: 9.16)),
                    (CGPoint(x: 7.05, y: 9.75), CGPoint(x: 1.42, y: 9.19)),
                    (CGPoint(x: 11.35, y: 12.41), CGPoint(x: 18.68, y: 21.49)),
                    (CGPoint(x: 8.41, y: 12.67), CGPoint(x: 5.36, y: 21.84))
                ]
                let innerHalfWidth: CGFloat = 0.55
                let outerHalfWidth: CGFloat = 1.17
                for ray in rays {
                    let length = hypot(ray.outer.x - ray.inner.x, ray.outer.y - ray.inner.y)
                    let normal = CGPoint(x: -(ray.outer.y - ray.inner.y) / length, y: (ray.outer.x - ray.inner.x) / length)
                    let corners = [
                        CGPoint(x: ray.inner.x + normal.x * innerHalfWidth, y: ray.inner.y + normal.y * innerHalfWidth),
                        CGPoint(x: ray.outer.x + normal.x * outerHalfWidth, y: ray.outer.y + normal.y * outerHalfWidth),
                        CGPoint(x: ray.outer.x - normal.x * outerHalfWidth, y: ray.outer.y - normal.y * outerHalfWidth),
                        CGPoint(x: ray.inner.x - normal.x * innerHalfWidth, y: ray.inner.y - normal.y * innerHalfWidth)
                    ]
                    let path = CGMutablePath()
                    path.move(to: CGPoint(x: (corners[3].x + corners[0].x) / 2, y: (corners[3].y + corners[0].y) / 2))
                    for i in 0 ..< corners.count {
                        path.addArc(tangent1End: corners[i], tangent2End: corners[(i + 1) % corners.count], radius: 0.5)
                    }
                    path.closeSubpath()
                    draw(path, filled: true)
                }
            case .miniPrograms:
                // Ring and S traced from IMG_2442: 20pt ring, hooks of 2.58pt radius around a 3.5pt stem, 1.2pt stroke.
                context.scaleBy(x: 28.0 / 24.0, y: 28.0 / 24.0)
                context.setLineWidth(1.2)
                draw(UIBezierPath(ovalIn: CGRect(x: 2.6, y: 2.6, width: 18.8, height: 18.8)).cgPath)
                let link = UIBezierPath()
                link.addArc(withCenter: CGPoint(x: 14.583, y: 10.25), radius: 2.583, startAngle: .pi * 50 / 180, endAngle: .pi, clockwise: false)
                link.addLine(to: CGPoint(x: 12, y: 13.75))
                link.addArc(withCenter: CGPoint(x: 9.417, y: 13.75), radius: 2.583, startAngle: 0, endAngle: .pi * 230 / 180, clockwise: true)
                draw(link.cgPath)
            case .phoneContacts:
                // 添加朋友's 手机联系人, traced from IMG_2461 at 3x on the 发现 icons' 24pt grid:
                // a 1.33pt card with sharp corners and a 9pt handset, earpiece at the top left.
                context.scaleBy(x: 28.0 / 24.0, y: 28.0 / 24.0)
                context.setLineWidth(4.0 / 3.0)
                draw(CGPath(rect: CGRect(x: 4.67, y: 2.67, width: 14.67, height: 18.67), transform: nil))
                if let handset = UIImage(systemName: "phone.fill")?.withTintColor(.black, renderingMode: .alwaysOriginal) {
                    UIGraphicsPushContext(context)
                    handset.draw(in: CGRect(x: 7.33, y: 7.0, width: 9.0, height: 8.67))
                    UIGraphicsPopContext()
                }
            case .officialAccounts:
                // 公众号: an open book seen from the spine, 1.5pt stroke (IMG_2461).
                context.scaleBy(x: 28.0 / 24.0, y: 28.0 / 24.0)
                let book = UIBezierPath()
                for side: CGFloat in [-1, 1] {
                    let x = 12 + side * 8.4
                    book.move(to: CGPoint(x: 12, y: 9.3))
                    book.addLine(to: CGPoint(x: x, y: 4.1))
                    book.addLine(to: CGPoint(x: x, y: 13.6))
                    book.addQuadCurve(to: CGPoint(x: 12, y: 19.9), controlPoint: CGPoint(x: 12 + side * 8.2, y: 17.2))
                }
                book.move(to: CGPoint(x: 12, y: 9.3))
                book.addLine(to: CGPoint(x: 12, y: 19.9))
                draw(book.cgPath)
            case .serviceAccounts:
                // 服务号: a shopping bag with a receipt tucked behind its right side, 1.33pt stroke (IMG_2461).
                context.scaleBy(x: 28.0 / 24.0, y: 28.0 / 24.0)
                context.setLineWidth(4.0 / 3.0)
                context.setLineCap(.butt)
                context.setLineJoin(.miter)
                draw(UIBezierPath(roundedRect: CGRect(x: 2.5, y: 2.5, width: 11.0, height: 14.33), cornerRadius: 0.67).cgPath)
                let handle = UIBezierPath()
                handle.move(to: CGPoint(x: 5.17, y: 5.0))
                handle.addLine(to: CGPoint(x: 5.17, y: 5.58))
                handle.addArc(withCenter: CGPoint(x: 7.92, y: 5.58), radius: 2.75, startAngle: .pi, endAngle: 0, clockwise: false)
                handle.addLine(to: CGPoint(x: 10.67, y: 5.0))
                draw(handle.cgPath)
                let receipt = UIBezierPath()
                receipt.move(to: CGPoint(x: 13.5, y: 7.0))
                receipt.addLine(to: CGPoint(x: 21.17, y: 7.0))
                receipt.addLine(to: CGPoint(x: 21.17, y: 21.17))
                receipt.addLine(to: CGPoint(x: 11.0, y: 21.17))
                receipt.addLine(to: CGPoint(x: 13.3, y: 16.83))
                receipt.move(to: CGPoint(x: 13.5, y: 11.67))
                receipt.addLine(to: CGPoint(x: 19.0, y: 11.67))
                receipt.move(to: CGPoint(x: 13.5, y: 15.17))
                receipt.addLine(to: CGPoint(x: 18.0, y: 15.17))
                draw(receipt.cgPath)
            case .chatMore:
                for x: CGFloat in [7.25, 14, 20.75] {
                    context.fillEllipse(in: CGRect(x: x - 1.75, y: 12.25, width: 3.5, height: 3.5))
                }
            case .chats:
                let rear = UIBezierPath()
                rear.move(to: CGPoint(x: 21, y: 8))
                rear.addCurve(to: CGPoint(x: 24, y: 22), controlPoint1: CGPoint(x: 29, y: 10), controlPoint2: CGPoint(x: 29, y: 18))
                rear.addLine(to: CGPoint(x: 25, y: 26))
                rear.addLine(to: CGPoint(x: 20, y: 24))
                rear.addCurve(to: CGPoint(x: 14, y: 22), controlPoint1: CGPoint(x: 17, y: 25), controlPoint2: CGPoint(x: 15, y: 24))
                draw(rear.cgPath)
                let front = UIBezierPath()
                front.move(to: CGPoint(x: 6, y: 20))
                front.addCurve(to: CGPoint(x: 2, y: 12), controlPoint1: CGPoint(x: 3, y: 18), controlPoint2: CGPoint(x: 2, y: 16))
                front.addCurve(to: CGPoint(x: 13, y: 3), controlPoint1: CGPoint(x: 2, y: 6), controlPoint2: CGPoint(x: 7, y: 3))
                front.addCurve(to: CGPoint(x: 24, y: 12), controlPoint1: CGPoint(x: 19, y: 3), controlPoint2: CGPoint(x: 24, y: 6))
                front.addCurve(to: CGPoint(x: 11, y: 21), controlPoint1: CGPoint(x: 24, y: 19), controlPoint2: CGPoint(x: 17, y: 23))
                front.addLine(to: CGPoint(x: 5, y: 25))
                front.close()
                draw(front.cgPath, filled: selected)
            case .contacts, .me, .addContact:
                if self == .addContact {
                    // IMG_2470 measures the add icon 22x18pt, about 0.77 of the tab-sized drawing, 1.8pt left of centre.
                    context.translateBy(x: 14.0 - 1.8, y: 14.0)
                    context.scaleBy(x: 0.77, y: 0.77)
                    context.translateBy(x: -14.0, y: -14.0)
                }
                let centerX: CGFloat = self == .contacts ? 11.0 : (self == .me ? 14.0 : 10.0)
                draw(UIBezierPath(ovalIn: CGRect(x: centerX - 4, y: 2, width: 8, height: 11)).cgPath, filled: selected)
                let shoulders = UIBezierPath()
                shoulders.move(to: CGPoint(x: centerX - 3, y: 12))
                shoulders.addLine(to: CGPoint(x: centerX - 3, y: 16))
                shoulders.addCurve(to: CGPoint(x: centerX - 10, y: 23), controlPoint1: CGPoint(x: centerX - 4, y: 18), controlPoint2: CGPoint(x: centerX - 10, y: 20))
                shoulders.addLine(to: CGPoint(x: centerX - 10, y: 25))
                shoulders.addLine(to: CGPoint(x: centerX + 10, y: 25))
                shoulders.addLine(to: CGPoint(x: centerX + 10, y: 23))
                shoulders.addCurve(to: CGPoint(x: centerX + 3, y: 16), controlPoint1: CGPoint(x: centerX + 10, y: 20), controlPoint2: CGPoint(x: centerX + 4, y: 18))
                shoulders.addLine(to: CGPoint(x: centerX + 3, y: 12))
                draw(shoulders.cgPath, filled: selected)
                if self == .addContact {
                    let plus = UIBezierPath()
                    plus.move(to: CGPoint(x: 20, y: 9))
                    plus.addLine(to: CGPoint(x: 27, y: 9))
                    plus.move(to: CGPoint(x: 23.5, y: 5.5))
                    plus.addLine(to: CGPoint(x: 23.5, y: 12.5))
                    draw(plus.cgPath)
                }
                if self == .contacts {
                    for y in [9.0, 13.0, 17.0] {
                        let line = UIBezierPath()
                        line.move(to: CGPoint(x: 20, y: y))
                        line.addLine(to: CGPoint(x: 27, y: y))
                        draw(line.cgPath)
                    }
                }
            case .discover:
                draw(UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 24, height: 24)).cgPath)
                let pointer = UIBezierPath()
                pointer.move(to: CGPoint(x: 20, y: 8))
                pointer.addLine(to: CGPoint(x: 16, y: 17))
                pointer.addLine(to: CGPoint(x: 8, y: 21))
                pointer.addLine(to: CGPoint(x: 11, y: 12))
                pointer.close()
                draw(pointer.cgPath, filled: selected)
            case .star:
                let star = UIBezierPath()
                for index in 0..<10 {
                    let radius: CGFloat = index.isMultiple(of: 2) ? 11.0 : 5.0
                    let angle = CGFloat(index) * .pi / 5.0 - .pi / 2.0
                    let point = CGPoint(x: 14 + cos(angle) * radius, y: 14 + sin(angle) * radius)
                    if index == 0 { star.move(to: point) } else { star.addLine(to: point) }
                }
                star.close()
                draw(star.cgPath)
            case .chatInputVoice:
                draw(UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 26, height: 26)).cgPath)
                let innerWave = UIBezierPath()
                innerWave.move(to: CGPoint(x: 8, y: 14))
                innerWave.addLine(to: CGPoint(x: 10.5, y: 10.5))
                innerWave.addLine(to: CGPoint(x: 10.5, y: 17.5))
                innerWave.close()
                draw(innerWave.cgPath, filled: true)
                for radius: CGFloat in [4, 8] {
                    draw(UIBezierPath(arcCenter: CGPoint(x: 10, y: 14), radius: radius, startAngle: -.pi / 3, endAngle: .pi / 3, clockwise: true).cgPath)
                }
            case .chatInputEmoji:
                draw(UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 26, height: 26)).cgPath)
                draw(UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 2.5, height: 2.5)).cgPath, filled: true)
                draw(UIBezierPath(ovalIn: CGRect(x: 17.5, y: 8, width: 2.5, height: 2.5)).cgPath, filled: true)
                let smile = UIBezierPath()
                smile.move(to: CGPoint(x: 7, y: 16))
                smile.addQuadCurve(to: CGPoint(x: 21, y: 16), controlPoint: CGPoint(x: 14, y: 28))
                smile.close()
                draw(smile.cgPath)
            case .chatInputKeyboard:
                draw(UIBezierPath(roundedRect: CGRect(x: 1, y: 4, width: 26, height: 20), cornerRadius: 3).cgPath)
                for y: CGFloat in [9, 14] {
                    for x: CGFloat in [6, 11, 16, 21] {
                        draw(UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 1, height: 1), cornerRadius: 0.5).cgPath, filled: true)
                    }
                }
                let space = UIBezierPath()
                space.move(to: CGPoint(x: 7, y: 20))
                space.addLine(to: CGPoint(x: 21, y: 20))
                draw(space.cgPath)
            case .plus, .chatInputMore:
                let circleRect = self == .chatInputMore ? CGRect(x: 1, y: 1, width: 26, height: 26) : CGRect(x: 3, y: 3, width: 22, height: 22)
                draw(UIBezierPath(ovalIn: circleRect).cgPath)
                let plus = UIBezierPath()
                plus.move(to: CGPoint(x: 8, y: 14))
                plus.addLine(to: CGPoint(x: 20, y: 14))
                plus.move(to: CGPoint(x: 14, y: 8))
                plus.addLine(to: CGPoint(x: 14, y: 20))
                draw(plus.cgPath)
            }
        })?.withRenderingMode(self == .moments ? .alwaysOriginal : .alwaysTemplate)
    }
}
