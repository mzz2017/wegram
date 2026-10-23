import XCTest
import UIKit
import CoreLocation
import TelegramCore

final class WegramLocationPickerSelectionTests: XCTestCase {
    func testVenueSelectionKeepsActualObjectAndInlineQueryMetadataUntilConfirmation() throws {
        var selection = WegramLocationPickerSelection()
        XCTAssertFalse(selection.canConfirm)
        let map = TelegramMediaMap(latitude: 31.2, longitude: 121.4, heading: 90, accuracyRadius: 20, venue: MapVenue(title: "巨鹿路", address: "上海", provider: "test", id: "42", type: "street"))
        selection.update(.venue(map, 123456, "result-42"))
        XCTAssertTrue(selection.canConfirm)
        guard case let .venue(actual, queryId, resultId) = try XCTUnwrap(selection.confirm()) else { return XCTFail("The selected venue must stay a venue") }
        XCTAssertTrue(actual === map)
        XCTAssertEqual(queryId, 123456)
        XCTAssertEqual(resultId, "result-42")
        XCTAssertFalse(selection.canConfirm)
        XCTAssertNil(selection.confirm())
        selection.update(.venue(map, nil, nil))
        XCTAssertFalse(selection.canConfirm, "Late search or location updates must not re-enable a completed send")
    }

    func testCoordinatesPreserveNameAndGeoAddressAndInvalidateDuringSelection() throws {
        var selection = WegramLocationPickerSelection()
        let coordinate = CLLocationCoordinate2D(latitude: -31.25, longitude: 121.5)
        let address = MapGeoAddress(country: "CN", state: "上海", city: "上海", street: "巨鹿路")
        selection.update(.coordinate(coordinate, "原始名称", address))
        XCTAssertTrue(selection.canConfirm)
        selection.update(nil)
        XCTAssertFalse(selection.canConfirm)
        XCTAssertNil(selection.confirm())
        for coordinate in [CLLocationCoordinate2D(latitude: .nan, longitude: 1), CLLocationCoordinate2D(latitude: 91, longitude: 0), CLLocationCoordinate2D(latitude: 0, longitude: 181)] {
            selection.update(.coordinate(coordinate, nil, nil))
            XCTAssertFalse(selection.canConfirm)
        }
        selection.update(.coordinate(coordinate, "原始名称", address))
        guard case let .coordinate(actual, name, actualAddress) = try XCTUnwrap(selection.confirm()) else { return XCTFail("The selected coordinate must not become a venue") }
        XCTAssertEqual(actual.latitude, coordinate.latitude)
        XCTAssertEqual(actual.longitude, coordinate.longitude)
        XCTAssertEqual(name, "原始名称")
        XCTAssertTrue(actualAddress === address)
    }

    func testCancellationAndLiveCompletionBlockStaticConfirmationAndResetAllowsReuse() {
        var selection = WegramLocationPickerSelection()
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        selection.update(.coordinate(coordinate, nil, nil))
        XCTAssertTrue(selection.finish())
        XCTAssertFalse(selection.finish())
        XCTAssertNil(selection.confirm())
        selection.update(.coordinate(coordinate, "late", nil))
        XCTAssertFalse(selection.canConfirm)
        selection.reset()
        XCTAssertFalse(selection.canConfirm)
        selection.update(.coordinate(coordinate, "new", nil))
        XCTAssertNotNil(selection.confirm())
        XCTAssertFalse(selection.finish())
    }
    func testMapSearchAndResultsStaySeparateAboveKeyboardAndSafeArea() {
        let size = CGSize(width: 402, height: 874)
        let idle = WegramLocationPickerLayout(size: size, bottomInset: 34, navigationHeight: 103)
        XCTAssertEqual(idle.map.height, 559)
        XCTAssertEqual(idle.search, CGRect(x: 0, y: 559, width: 402, height: 56))
        XCTAssertEqual(idle.results, CGRect(x: 0, y: 615, width: 402, height: 225))
        let typing = WegramLocationPickerLayout(size: size, bottomInset: 346, navigationHeight: 103)
        XCTAssertEqual(typing.results.height, 76)
        XCTAssertEqual(typing.results.maxY, 874 - 346)
        XCTAssertEqual(typing.map.maxY, typing.search.minY)
        XCTAssertEqual(typing.search.maxY, typing.results.minY)
        XCTAssertGreaterThanOrEqual(typing.map.height, 103 + 16)
        XCTAssertLessThan(typing.map.height, idle.map.height)
        XCTAssertEqual(WegramLocationPickerLayout(size: size, bottomInset: 34, navigationHeight: 103).map, idle.map, "Dismissing the keyboard must restore the map without carrying a list scroll offset")
    }

    func testLandscapeAndUnavailableSpaceDoNotProduceNegativeOrOverlappingFrames() {
        for size in [CGSize(width: 874, height: 402), CGSize(width: 320, height: 180), .zero] {
            for bottom: CGFloat in [0, 34, 250, 600] {
                let layout = WegramLocationPickerLayout(size: size, bottomInset: bottom, navigationHeight: 103)
                for frame in [layout.map, layout.search, layout.results] {
                    XCTAssertGreaterThanOrEqual(frame.height, 0)
                    XCTAssertGreaterThanOrEqual(frame.width, 0)
                    XCTAssertLessThanOrEqual(frame.maxY, max(0, size.height - bottom))
                }
                XCTAssertEqual(layout.map.maxY, layout.search.minY)
                XCTAssertEqual(layout.search.maxY, layout.results.minY)
            }
        }
    }

    func testNearbyEmptyStateOnlyUsesSpaceBelowActualActionRows() throws {
        let size = CGSize(width: 402, height: 225)
        let textSize = CGSize(width: 120, height: 36)
        let frame = try XCTUnwrap(WegramLocationPickerLayout.emptyResultsFrame(size: size, textSize: textSize, occupiedHeight: 148))
        XCTAssertGreaterThanOrEqual(frame.minY, 148)
        XCTAssertLessThanOrEqual(frame.maxY, size.height)
        XCTAssertEqual(frame.midX, size.width / 2)
        XCTAssertNil(WegramLocationPickerLayout.emptyResultsFrame(size: CGSize(width: 402, height: 76), textSize: textSize, occupiedHeight: 148), "A keyboard-sized viewport must hide the empty text instead of drawing it over the selected place or live-location row")
        let scrolled = try XCTUnwrap(WegramLocationPickerLayout.emptyResultsFrame(size: size, textSize: textSize, occupiedHeight: -40))
        XCTAssertGreaterThanOrEqual(scrolled.minY, 0)
        XCTAssertLessThan(scrolled.minY, frame.minY)
        XCTAssertNil(WegramLocationPickerLayout.emptyResultsFrame(size: .zero, textSize: textSize, occupiedHeight: 0))
    }

}
