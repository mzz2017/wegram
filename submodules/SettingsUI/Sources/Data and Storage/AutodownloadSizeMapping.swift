import Foundation
import CoreGraphics

private let autodownloadSizeValues: [(CGFloat, Int64)] = [
    (0.000, 512 * 1024),
    (0.257, 1024 * 1024),
    (0.520, 10 * 1024 * 1024),
    (0.763, 100 * 1024 * 1024),
    (1.000, 1536 * 1024 * 1024)
]

func autodownloadSizeSliderValue(for size: Int64) -> CGFloat {
    for i in 1 ..< autodownloadSizeValues.count {
        let (previousValue, previousValueSize) = autodownloadSizeValues[i - 1]
        let (value, valueSize) = autodownloadSizeValues[i]
        if valueSize > size {
            return previousValue + CGFloat(size - previousValueSize) / CGFloat(valueSize - previousValueSize) * (value - previousValue)
        } else if previousValueSize == size {
            return previousValue
        } else if valueSize == size || i == autodownloadSizeValues.count - 1 {
            return value
        }
    }
    return 0.0
}

func autodownloadSizeForSliderValue(for sliderValue: CGFloat) -> Int64 {
    for i in 1 ..< autodownloadSizeValues.count {
        let (previousValue, previousValueSize) = autodownloadSizeValues[i - 1]
        let (value, valueSize) = autodownloadSizeValues[i]
        if value > sliderValue {
            let delta = (sliderValue - previousValue) / (value - previousValue) * CGFloat(valueSize - previousValueSize)
            return previousValueSize + Int64(delta)
        } else if previousValue == sliderValue {
            return previousValueSize
        } else if value == sliderValue || i == autodownloadSizeValues.count - 1 {
            return valueSize
        }
    }
    return 0
}

