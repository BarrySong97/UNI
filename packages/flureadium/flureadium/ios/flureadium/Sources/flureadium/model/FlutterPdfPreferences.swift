//
//  FlutterPdfPreferences.swift
//  flureadium
//
//  PDF preferences for Flutter Readium.
//  Maps to PDFPreferences in Flutter's reader_pdf_preferences.dart.
//

import Foundation
import ReadiumNavigator
import ReadiumShared

/// How a PDF page fits within the viewport.
/// Maps to PDFFit enum in Flutter.
public enum FlutterPdfFit: String {
    case width
    case contain

    /// Converts to Readium scroll mode.
    /// - width: continuous scroll mode (scroll=true)
    /// - contain: paginated mode (scroll=false)
    func toReadiumScroll() -> Bool {
        switch self {
        case .width:
            return true
        case .contain:
            return false
        }
    }

    static func fromString(_ value: String?) -> FlutterPdfFit? {
        guard let value = value else { return nil }
        return FlutterPdfFit(rawValue: value.lowercased())
    }
}

/// Scroll direction for PDF navigation.
/// Maps to PDFScrollMode enum in Flutter.
public enum FlutterPdfScrollMode: String {
    case horizontal
    case vertical

    /// Converts to Readium scroll axis.
    func toReadiumScrollAxis() -> Axis {
        switch self {
        case .horizontal:
            return .horizontal
        case .vertical:
            return .vertical
        }
    }

    static func fromString(_ value: String?) -> FlutterPdfScrollMode? {
        guard let value = value else { return nil }
        return FlutterPdfScrollMode(rawValue: value.lowercased())
    }
}

/// Page layout mode for PDF display.
/// Maps to PDFPageLayout enum in Flutter.
public enum FlutterPdfPageLayout: String {
    case single
    case double
    case automatic

    /// Converts to Readium spread mode.
    func toReadiumSpread() -> Spread {
        switch self {
        case .single:
            return .never
        case .double:
            return .always
        case .automatic:
            return .auto
        }
    }

    static func fromString(_ value: String?) -> FlutterPdfPageLayout? {
        guard let value = value else { return nil }
        return FlutterPdfPageLayout(rawValue: value.lowercased())
    }
}

/// PDF preferences for Flutter Readium.
/// Maps to PDFPreferences class in Flutter's reader_pdf_preferences.dart.
/// Navigation UX settings (gestures, edge tap, etc.) have moved to FlutterNavigationConfig.
public struct FlutterPdfPreferences {
    /// How the page fits in the viewport.
    var fit: FlutterPdfFit?

    /// Scroll orientation.
    var scrollMode: FlutterPdfScrollMode?

    /// Page layout mode.
    var pageLayout: FlutterPdfPageLayout?

    /// Whether to offset the first page in double-page spreads (for covers).
    var offsetFirstPage: Bool?

    /// Creates FlutterPdfPreferences with default values.
    init(
        fit: FlutterPdfFit? = nil,
        scrollMode: FlutterPdfScrollMode? = nil,
        pageLayout: FlutterPdfPageLayout? = nil,
        offsetFirstPage: Bool? = nil
    ) {
        self.fit = fit
        self.scrollMode = scrollMode
        self.pageLayout = pageLayout
        self.offsetFirstPage = offsetFirstPage
    }

    /// Creates FlutterPdfPreferences from a Flutter dictionary.
    init(fromMap map: [String: Any]?) {
        guard let map = map else {
            self.init()
            return
        }

        self.init(
            fit: FlutterPdfFit.fromString(map["fit"] as? String),
            scrollMode: FlutterPdfScrollMode.fromString(map["scrollMode"] as? String),
            pageLayout: FlutterPdfPageLayout.fromString(map["pageLayout"] as? String),
            offsetFirstPage: map["offsetFirstPage"] as? Bool
        )
    }

    /// Converts to Readium PDFPreferences.
    func toReadiumPreferences() -> PDFPreferences {
        var prefs = PDFPreferences()

        // Map fit to scroll mode
        if let fit = fit {
            prefs.scroll = fit.toReadiumScroll()
        }

        // Map scrollMode to scrollAxis
        if let scrollMode = scrollMode {
            prefs.scrollAxis = scrollMode.toReadiumScrollAxis()
        }

        // Map pageLayout to spread
        if let pageLayout = pageLayout {
            prefs.spread = pageLayout.toReadiumSpread()
        }

        // Direct mapping for offsetFirstPage
        if let offsetFirstPage = offsetFirstPage {
            prefs.offsetFirstPage = offsetFirstPage
        }

        return prefs
    }

    /// Converts to a dictionary for Flutter.
    func toMap() -> [String: Any] {
        var map: [String: Any] = [:]
        if let fit = fit { map["fit"] = fit.rawValue }
        if let scrollMode = scrollMode { map["scrollMode"] = scrollMode.rawValue }
        if let pageLayout = pageLayout { map["pageLayout"] = pageLayout.rawValue }
        if let offsetFirstPage = offsetFirstPage { map["offsetFirstPage"] = offsetFirstPage }
        return map
    }
}
