//
//  FlutterNavigationConfig.swift
//  flureadium
//
//  Navigation UX configuration for Flutter Readium.
//  Maps to ReaderNavigationConfig in Flutter's reader_navigation_config.dart.
//

import Foundation

/// Navigation UX configuration for Flutter Readium.
/// Contains settings that control gesture behavior and navigation UX,
/// sent via the setNavigationConfig channel method (separate from Readium
/// reader preferences).
public struct FlutterNavigationConfig {

    /// Whether edge tap navigation is enabled.
    var enableEdgeTapNavigation: Bool?

    /// Whether swipe gesture navigation is enabled.
    var enableSwipeNavigation: Bool?

    /// Edge tap area in absolute points (44–120).
    var edgeTapAreaPoints: Double?

    /// Whether to disable the built-in double-tap-to-zoom gesture (iOS only).
    var disableDoubleTapZoom: Bool?

    /// Whether to disable text selection gestures (iOS only).
    var disableTextSelection: Bool?

    /// Whether to disable drag gestures (iOS only).
    var disableDragGestures: Bool?

    /// Whether to disable double-tap word selection in PDF text (iOS only).
    var disableDoubleTapTextSelection: Bool?

    init(
        enableEdgeTapNavigation: Bool? = nil,
        enableSwipeNavigation: Bool? = nil,
        edgeTapAreaPoints: Double? = nil,
        disableDoubleTapZoom: Bool? = nil,
        disableTextSelection: Bool? = nil,
        disableDragGestures: Bool? = nil,
        disableDoubleTapTextSelection: Bool? = nil
    ) {
        self.enableEdgeTapNavigation = enableEdgeTapNavigation
        self.enableSwipeNavigation = enableSwipeNavigation
        self.edgeTapAreaPoints = edgeTapAreaPoints
        self.disableDoubleTapZoom = disableDoubleTapZoom
        self.disableTextSelection = disableTextSelection
        self.disableDragGestures = disableDragGestures
        self.disableDoubleTapTextSelection = disableDoubleTapTextSelection
    }

    /// Creates FlutterNavigationConfig from a Flutter dictionary.
    /// Values are typed: booleans as Bool, doubles as Double.
    init(fromMap map: [String: Any]?) {
        guard let map = map else {
            self.init()
            return
        }
        self.init(
            enableEdgeTapNavigation: map["enableEdgeTapNavigation"] as? Bool,
            enableSwipeNavigation: map["enableSwipeNavigation"] as? Bool,
            edgeTapAreaPoints: map["edgeTapAreaPoints"] as? Double,
            disableDoubleTapZoom: map["disableDoubleTapZoom"] as? Bool,
            disableTextSelection: map["disableTextSelection"] as? Bool,
            disableDragGestures: map["disableDragGestures"] as? Bool,
            disableDoubleTapTextSelection: map["disableDoubleTapTextSelection"] as? Bool
        )
    }
}
