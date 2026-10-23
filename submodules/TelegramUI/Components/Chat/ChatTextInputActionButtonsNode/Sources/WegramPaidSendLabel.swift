import UIKit
import Display
import AnimatedCountLabelNode

func layoutWegramPaidSendLabel(_ node: ImmediateAnimatedCountLabelNode, maximumWidth: CGFloat, height: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
    // Measuring within the button would discard later digits before we can scale them.
    let textSize = node.updateLayout(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 100), animated: transition.isAnimated)
    let width = min(max(58, textSize.width + 28), max(58, maximumWidth))
    let scale = min(1, max(1, width - 16) / max(1, textSize.width))
    transition.updateBounds(node: node, bounds: CGRect(origin: .zero, size: textSize))
    transition.updatePosition(node: node, position: CGPoint(x: width / 2, y: height / 2))
    transition.updateTransformScale(node: node, scale: scale)
    return CGSize(width: width, height: height)
}
