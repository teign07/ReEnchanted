import XCTest
@testable import InsideCoverCore

/// Phase 0 of `docs/correspondences-plan.md` made the archive permissive: a
/// page may now remember where it was kept, because the archive stays on the
/// device and belongs to the reader. These guard the two things that being
/// permissive must not cost — a coordinate that is half-present, and a
/// coordinate that is not a coordinate.
final class PageContextCoordinateTests: XCTestCase {

    func testCoordinatesTravelWithThePage() {
        let snapshot = BookPageContextSnapshot(
            latitude: 44.31,
            longitude: -69.78,
            horizontalAccuracyMeters: 100
        )
        XCTAssertEqual(snapshot.latitude, 44.31)
        XCTAssertEqual(snapshot.longitude, -69.78)
        XCTAssertEqual(snapshot.horizontalAccuracyMeters, 100)
    }

    /// Half a coordinate is not a place. A latitude on its own would put the
    /// page on a line of longitude running pole to pole.
    func testHalfACoordinateIsNoCoordinate() {
        let onlyLatitude = BookPageContextSnapshot(latitude: 44.31)
        XCTAssertNil(onlyLatitude.latitude)
        XCTAssertNil(onlyLatitude.longitude)

        let onlyLongitude = BookPageContextSnapshot(longitude: -69.78)
        XCTAssertNil(onlyLongitude.latitude)
        XCTAssertNil(onlyLongitude.longitude)
    }

    /// The house rule for every other reading in this struct: an absurd value
    /// is a missing value, not a clamped one.
    func testOutOfRangeReadingsAreMissingReadings() {
        for (latitude, longitude) in [(91.0, 0.0), (-91.0, 0.0), (0.0, 181.0), (0.0, -181.0)] {
            let snapshot = BookPageContextSnapshot(latitude: latitude, longitude: longitude)
            XCTAssertNil(snapshot.latitude, "latitude \(latitude) should not survive")
            XCTAssertNil(snapshot.longitude, "longitude \(longitude) should not survive")
        }
    }

    /// Accuracy without a fix is noise, and it must not outlive the pair it
    /// describes.
    func testAccuracyDoesNotSurviveWithoutAFix() {
        let snapshot = BookPageContextSnapshot(latitude: 91, longitude: 0, horizontalAccuracyMeters: 10)
        XCTAssertNil(snapshot.horizontalAccuracyMeters)

        let unmeasured = BookPageContextSnapshot(latitude: 44.31, longitude: -69.78, horizontalAccuracyMeters: -1)
        XCTAssertNil(unmeasured.horizontalAccuracyMeters, "a negative accuracy is Core Location saying it does not know")
        XCTAssertEqual(unmeasured.latitude, 44.31, "an unknown accuracy must not discard a good fix")
    }

    func testCoordinatesSurviveARoundTrip() throws {
        let original = BookPageContextSnapshot(
            weatherTags: ["rain"],
            latitude: 44.31,
            longitude: -69.78,
            horizontalAccuracyMeters: 65
        )
        let decoded = try JSONDecoder().decode(
            BookPageContextSnapshot.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded, original)
    }

    /// Every archive written before Phase 0 decodes without these keys, and
    /// must still open.
    func testArchivesWrittenBeforeCoordinatesStillOpen() throws {
        let legacy = """
        {"timeZoneIdentifier":"America/New_York","utcOffsetSeconds":-14400,\
        "dayPart":"evening","weatherTags":["rain"],"nearbyAnchorID":"anchor-7"}
        """
        let decoded = try JSONDecoder().decode(
            BookPageContextSnapshot.self,
            from: Data(legacy.utf8)
        )
        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
        XCTAssertNil(decoded.horizontalAccuracyMeters)
        XCTAssertEqual(decoded.nearbyAnchorID, "anchor-7")
        XCTAssertEqual(decoded.weatherTags, ["rain"])
    }

    /// A hand-edited or corrupted archive must not be able to smuggle in half
    /// a coordinate that the initialiser would have refused.
    func testDecodingHoldsTheSameInvariantAsTheInitialiser() throws {
        let halfWritten = """
        {"timeZoneIdentifier":"America/New_York","utcOffsetSeconds":-14400,\
        "dayPart":"night","weatherTags":[],"latitude":44.31,"horizontalAccuracyMeters":10}
        """
        let decoded = try JSONDecoder().decode(
            BookPageContextSnapshot.self,
            from: Data(halfWritten.utf8)
        )
        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
        XCTAssertNil(decoded.horizontalAccuracyMeters)

        let outOfRange = """
        {"timeZoneIdentifier":"America/New_York","utcOffsetSeconds":-14400,\
        "dayPart":"night","weatherTags":[],"latitude":991.0,"longitude":-69.78}
        """
        let rejected = try JSONDecoder().decode(
            BookPageContextSnapshot.self,
            from: Data(outOfRange.utf8)
        )
        XCTAssertNil(rejected.latitude)
        XCTAssertNil(rejected.longitude)
    }
}
