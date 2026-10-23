import UIKit
import Display

func chatListSeparatorFrame(params: ListViewItemLayoutParams, contentInset: CGFloat, y: CGFloat, height: CGFloat, fullWidth: Bool, isWegram: Bool) -> CGRect {
    let left = isWegram || !fullWidth ? contentInset : params.leftInset
    let right = isWegram ? params.rightInset : (fullWidth && params.rightInset.isZero ? 0 : params.rightInset + 16)
    return CGRect(x: left, y: y, width: max(0, params.width - left - right), height: height)
}
