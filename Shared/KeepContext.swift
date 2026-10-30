import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

// MARK: - What else a keep remembers
//
// docs/noticing-and-writing-sessions-plan.md §8, "richer captures". Each kept
// Page already carries the time, the place, the sky, the body and the calendar
// load. These are the rest of the moment: how the reader wrote it, how they
// were holding the Book, the sea and the air, more of the body, and more of
// the photograph. Numbers and categories only: never deleted words, never
// sound, never a camera frame. Every field is optional, so a reading that
// wasn't available is simply absent, and every older Page still opens.

/// How the words got onto the page. Counts only; deleted text is never kept.
struct WritingProcess: Codable, Equatable, Hashable {
    /// From the first keystroke to the keep.
    var secondsWriting: Double? = nil
    /// Characters taken back out.
    var charactersDeleted: Int? = nil
    /// Pauses of half a minute or more while writing.
    var pauses: Int? = nil
    /// Chunks of words that arrived all at once: dictation or a paste.
    var spokenOrPastedChunks: Int? = nil
    /// Final length, so "deleted more than kept" can be said.
    var charactersKept: Int? = nil
}

/// How the reader was holding the Book when they kept the page.
struct HoldingSnapshot: Codable, Equatable, Hashable {
    enum Posture: String, Codable, Equatable, Hashable {
        /// Screen facing up and level: on a table, or lying on their back.
        case flat
        /// Held upright, as when sitting or standing.
        case upright
        /// On its side: lying on one side in bed, or propped.
        case sideways
        /// Tipped back past upright, held overhead.
        case overhead
    }

    var posture: Posture? = nil
    /// The phone was moving: walking, a bus, a hand that wouldn't keep still.
    var moving: Bool? = nil
    var batteryPercent: Int? = nil
    var charging: Bool? = nil
    var lowPowerMode: Bool? = nil
    /// 0 to 1. A dark room turns it down.
    var screenBrightness: Double? = nil
    var headphones: Bool? = nil
}

/// The sea at the keep, from Open-Meteo's marine forecast. Absent inland.
struct SeaReading: Codable, Equatable, Hashable {
    /// Metres above mean sea level: the tide.
    var seaLevelMeters: Double? = nil
    /// Whether the tide is coming in over the next hour.
    var rising: Bool? = nil
    var waveHeightMeters: Double? = nil
}

/// The air at the keep, from Open-Meteo's air-quality forecast. Pollen is only
/// published for Europe, so it is absent elsewhere.
struct AirReading: Codable, Equatable, Hashable {
    var usAQI: Double? = nil
    var grassPollen: Double? = nil
    var birchPollen: Double? = nil
    var ragweedPollen: Double? = nil
}

/// More of the body, from HealthKit types the reader can grant alongside the
/// ones the Body page already reads.
struct BodyExtras: Codable, Equatable, Hashable {
    /// Minutes in daylight today (Apple Watch).
    var daylightMinutes: Double? = nil
    /// The most recent workout and how long before the keep it ended.
    var lastWorkout: String? = nil
    var minutesSinceWorkout: Int? = nil
    var mindfulMinutes: Double? = nil
    /// The mood the reader logged in Health, -1 to 1, if they did.
    var loggedValence: Double? = nil
    /// The day's average sound level around them, in decibels.
    var environmentDecibels: Double? = nil
    var flightsClimbed: Int? = nil
}

// MARK: - The photograph's own details

/// What the camera wrote into the file, beyond the picture: when it was taken
/// (`PhotoTakenAt`), which camera, whether it zoomed, used the flash, or was a
/// screenshot, and where it was taken. All on device, all optional.
enum PhotoDetails {
    static let cameraKey = "attentionCamera"
    static let zoomedKey = "attentionZoomed"
    static let flashKey = "attentionFlash"
    static let latitudeKey = "attentionTakenLatitude"
    static let longitudeKey = "attentionTakenLongitude"

    static func metadata(from data: Data) -> [String: String] {
        var metadata = PhotoTakenAt.metadata(from: data)
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return metadata }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let lens = (exif[kCGImagePropertyExifLensModel] as? String)?.lowercased() ?? ""
        let make = (tiff[kCGImagePropertyTIFFMake] as? String) ?? ""
        let userComment = (exif[kCGImagePropertyExifUserComment] as? String)?.lowercased() ?? ""
        if userComment.contains("screenshot") || (make.isEmpty && exif.isEmpty) {
            metadata[cameraKey] = "screenshot"
        } else if lens.contains("front") {
            metadata[cameraKey] = "front"
        } else if !make.isEmpty {
            metadata[cameraKey] = "back"
        }
        if let equivalent = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double ?? (exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int).map(Double.init) {
            // The main lens is about 26mm; past twice that, they leaned in.
            metadata[zoomedKey] = equivalent >= 52 ? "true" : "false"
        }
        if let flash = exif[kCGImagePropertyExifFlash] as? Int {
            metadata[flashKey] = flash & 1 == 1 ? "true" : "false"
        }
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
           let longitude = gps[kCGImagePropertyGPSLongitude] as? Double {
            let north = (gps[kCGImagePropertyGPSLatitudeRef] as? String) != "S"
            let east = (gps[kCGImagePropertyGPSLongitudeRef] as? String) != "W"
            metadata[latitudeKey] = String(format: "%.4f", north ? latitude : -latitude)
            metadata[longitudeKey] = String(format: "%.4f", east ? longitude : -longitude)
        }
        #endif
        return metadata
    }

    /// Kilometres between where a photo was taken and where it was kept.
    static func carriedKilometres(_ asset: BookPageMediaAsset, keptAt context: BookPageContextSnapshot?) -> Double? {
        guard let latitude = asset.metadata[latitudeKey].flatMap(Double.init),
              let longitude = asset.metadata[longitudeKey].flatMap(Double.init),
              let keptLatitude = context?.latitude, let keptLongitude = context?.longitude else { return nil }
        return distanceKilometres(latitude, longitude, keptLatitude, keptLongitude)
    }

    static func distanceKilometres(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radians = Double.pi / 180
        let dLat = (lat2 - lat1) * radians, dLon = (lon2 - lon1) * radians
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * radians) * cos(lat2 * radians) * sin(dLon / 2) * sin(dLon / 2)
        return 6_371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

// MARK: - The sun's height

enum SunHeight {
    /// Degrees above the horizon at a moment and place. Negative is below.
    /// Good to about a degree, which is all "golden hour" needs.
    static func degrees(at date: Date, latitude: Double, longitude: Double) -> Double {
        let day = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let meanLongitude = (280.460 + 0.9856474 * day).truncatingRemainder(dividingBy: 360)
        let anomaly = (357.528 + 0.9856003 * day).truncatingRemainder(dividingBy: 360) * .pi / 180
        let eclipticLongitude = (meanLongitude + 1.915 * sin(anomaly) + 0.020 * sin(2 * anomaly)) * .pi / 180
        let obliquity = (23.439 - 0.0000004 * day) * .pi / 180
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
        let siderealHours = (18.697374558 + 24.06570982441908 * day).truncatingRemainder(dividingBy: 24)
        let hourAngle = (siderealHours * 15 + longitude) * .pi / 180 - rightAscension
        let latitudeRadians = latitude * .pi / 180
        let altitude = asin(sin(latitudeRadians) * sin(declination) + cos(latitudeRadians) * cos(declination) * cos(hourAngle))
        return altitude * 180 / .pi
    }

    /// The light a photographer would name.
    static func light(degrees: Double) -> String {
        switch degrees {
        case ..<(-6): return "dark"
        case ..<0: return "blue hour"
        case ..<8: return "golden hour"
        default: return "daylight"
        }
    }
}
