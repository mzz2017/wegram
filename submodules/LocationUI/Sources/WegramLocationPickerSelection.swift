import Foundation
import UIKit
import CoreLocation
import TelegramCore

public struct WegramLocationPickerSelection {
    public enum Payload {
        case coordinate(CLLocationCoordinate2D, String?, MapGeoAddress?)
        case venue(TelegramMediaMap, Int64?, String?)

        var coordinate: CLLocationCoordinate2D {
            switch self {
            case let .coordinate(coordinate, _, _): return coordinate
            case let .venue(map, _, _): return CLLocationCoordinate2D(latitude: map.latitude, longitude: map.longitude)
            }
        }
    }

    private var payload: Payload?
    private var confirmed = false

    public static func rowIdentity(_ map: TelegramMediaMap?, index: Int) -> String {
        let fields = [map?.venue?.provider ?? "", map?.venue?.id ?? "", map.map { String($0.latitude) } ?? "", map.map { String($0.longitude) } ?? "", String(index)]
        return fields.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public static func sameContent(_ lhs: TelegramMediaMap?, _ rhs: TelegramMediaMap?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return lhs.isEqual(to: rhs) && lhs.venue?.title == rhs.venue?.title && lhs.address == rhs.address
    }

    public static func matches(_ lhs: TelegramMediaMap, _ rhs: TelegramMediaMap) -> Bool {
        guard lhs.latitude == rhs.latitude, lhs.longitude == rhs.longitude, lhs.venue?.id == rhs.venue?.id, lhs.venue?.provider == rhs.venue?.provider else { return false }
        if let id = lhs.venue?.id, !id.isEmpty { return true }
        return lhs.venue?.title == rhs.venue?.title && lhs.venue?.address == rhs.venue?.address
    }

    public init() {}

    public var isFinished: Bool { return self.confirmed }
    public var canConfirm: Bool { return self.payload != nil && !self.confirmed }

    public mutating func update(_ payload: Payload?) {
        guard !self.confirmed else { return }
        guard let payload, CLLocationCoordinate2DIsValid(payload.coordinate), payload.coordinate.latitude.isFinite, payload.coordinate.longitude.isFinite else {
            self.payload = nil
            return
        }
        self.payload = payload
    }

    public mutating func confirm() -> Payload? {
        guard let payload = self.payload, self.finish() else { return nil }
        return payload
    }

    @discardableResult
    public mutating func finish() -> Bool {
        guard !self.confirmed else { return false }
        self.confirmed = true
        self.payload = nil
        return true
    }

    public mutating func reset() {
        self.payload = nil
        self.confirmed = false
    }
}

public struct WegramLocationPickerLayout {
    public let map: CGRect
    public let search: CGRect
    public let results: CGRect

    public static func emptyResultsFrame(size: CGSize, textSize: CGSize, occupiedHeight: CGFloat) -> CGRect? {
        let top = max(0, occupiedHeight)
        let availableHeight = max(0, size.height - top)
        guard textSize.height <= availableHeight, textSize.width <= size.width else { return nil }
        return CGRect(x: (size.width - textSize.width) / 2, y: top + floor((availableHeight - textSize.height) / 2), width: textSize.width, height: textSize.height)
    }

    public init(size: CGSize, bottomInset: CGFloat, navigationHeight: CGFloat) {
        let available = max(0, size.height - max(0, bottomInset))
        let searchHeight = min(56, available)
        let maximumMapHeight = max(0, available - searchHeight)
        let mapHeight = min(maximumMapHeight, max(min(navigationHeight + 16, maximumMapHeight), min(floor(size.height * 0.64), available - searchHeight - 76)))
        self.map = CGRect(x: 0, y: 0, width: max(0, size.width), height: mapHeight)
        self.search = CGRect(x: 0, y: mapHeight, width: max(0, size.width), height: searchHeight)
        self.results = CGRect(x: 0, y: self.search.maxY, width: max(0, size.width), height: max(0, available - self.search.maxY))
    }
}
