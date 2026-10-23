import XCTest
import UIKit
import CoreImage
import Display
import QrCode

final class WegramQrHostedTests: XCTestCase {
    func testOriginalGeneratorAndAvatarCutoutDecodeInAnApplicationHost() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "app.wegram.qrtesthost", "This check requires the actual UIKit application host")
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        for link in ["https://t.me/Wegram_QA_fixture", "https://t.me/contact/fixture-token-not-valid"] {
            for side: CGFloat in [216, 280] {
                let filter = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
                filter.setValue(link.data(using: .isoLatin1), forKey: "inputMessage")
                filter.setValue("Q", forKey: "inputCorrectionLevel")
                let output = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 10, y: 10))
                let control = try XCTUnwrap(CIContext().createCGImage(output, from: output.extent), "The independent Core Image control must render; this hosted check never skips")
                XCTAssertEqual(detector.features(in: CIImage(cgImage: control)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }, [link])
                var code: UIImage?
                var matrixSize = 0
                let ready = self.expectation(description: "Original QR generator")
                let disposable = qrCode(string: link, color: .black, backgroundColor: nil, icon: .cutout, ecl: "Q").start(next: { size, generator in
                    matrixSize = size
                    code = generator(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: side, height: side), boundingSize: CGSize(width: side, height: side), intrinsicInsets: .zero, scale: 3))?.generateImage()
                    ready.fulfill()
                })
                self.wait(for: [ready], timeout: 5)
                disposable.dispose()
                let generated = try XCTUnwrap(code)
                let (_, cutout, _) = qrCodeCutout(size: matrixSize, dimensions: generated.size, scale: 3)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 3
                let composed = UIGraphicsImageRenderer(size: generated.size, format: format).image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: generated.size))
                    generated.draw(at: .zero)
                    UIColor.systemGreen.setFill()
                    context.fill(cutout.insetBy(dx: 2, dy: 2))
                }
                let cgImage = try XCTUnwrap(composed.cgImage)
                XCTAssertEqual(detector.features(in: CIImage(cgImage: cgImage)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }, [link], "The original generator with the avatar cutout must retain the exact link at \(side)pt")
                let name = link.contains("contact/") ? "temporary-fixture" : "public-fixture"
                if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    try composed.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("qr-hosted-\(name)-\(Int(side)).png"))
                }
                if side == 280 {
                    let card = WegramQrCardView()
                    card.update(name: "Alice 陈", address: "Wegram_QA_fixture", chinese: true, fontSize: 17, temporary: link.contains("contact/"))
                    let height = card.layoutCard(width: 360)
                    card.frame = CGRect(x: 0, y: 0, width: 360, height: height)
                    let image = UIGraphicsImageRenderer(size: card.bounds.size).image { context in
                        card.layer.render(in: context.cgContext)
                        composed.draw(in: card.codeFrame)
                        UIColor.systemGreen.setFill()
                        context.fill(card.avatarFrame)
                    }
                    let data = try XCTUnwrap(image.pngData())
                    let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)
                    XCTAssertEqual(detector.features(in: CIImage(cgImage: decoded)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }, [link], "The final card PNG must retain the exact link")
                    if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        try data.write(to: URL(fileURLWithPath: output).appendingPathComponent("qr-hosted-card-\(name).png"))
                    }
                }
            }
        }
    }
}
