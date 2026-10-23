import UIKit
import Display

public enum WegramMessageDateTextLayout {
    private static let heights = NSCache<UIFont, NSNumber>()

    public static func labelHeight(font: UIFont) -> CGFloat {
        if let height = self.heights.object(forKey: font) { return CGFloat(height.doubleValue) }
        // TextNode's line metrics differ from UIFont.lineHeight at larger sizes.
        let text = NSAttributedString(string: "昨天 星期三 2025年10月10日 00:08", font: font, textColor: .gray)
        let (layout, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 10000, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: .zero))
        self.heights.setObject(NSNumber(value: Double(layout.size.height)), forKey: font)
        return layout.size.height
    }
}
