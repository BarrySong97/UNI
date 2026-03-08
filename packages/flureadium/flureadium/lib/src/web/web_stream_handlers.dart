import 'dart:async';
import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';

/// Manages stream controllers for web platform events.
///
/// Provides broadcast streams for:
/// - Text locator changes (reading position)
/// - Time-based state changes (playback state for audiobooks/TTS)
/// - Reader status changes
class WebStreamHandlers {
  static final StreamController<Locator> _locatorTextController =
      StreamController<Locator>.broadcast();
  static final StreamController<ReadiumTimebasedState>
  _timebasedStateController =
      StreamController<ReadiumTimebasedState>.broadcast();
  static final StreamController<ReadiumReaderStatus> _readerStatusController =
      StreamController<ReadiumReaderStatus>.broadcast();

  /// Adds a text locator update to the stream.
  static void addTextLocatorUpdate(Locator locator) {
    _locatorTextController.add(locator);
  }

  /// Adds a time-based state update to the stream.
  static void addTimeBasedStateUpdate(ReadiumTimebasedState timebasedState) {
    _timebasedStateController.add(timebasedState);
  }

  /// Adds a reader status update to the stream.
  static void addReaderStatusUpdate(ReadiumReaderStatus status) {
    _readerStatusController.add(status);
  }

  /// Stream of text locator changes.
  static Stream<Locator> get onTextLocatorChanged {
    return _locatorTextController.stream;
  }

  /// Stream of time-based player state changes.
  static Stream<ReadiumTimebasedState> get onTimebasedPlayerStateChanged {
    return _timebasedStateController.stream;
  }

  /// Stream of reader status changes.
  static Stream<ReadiumReaderStatus> get onReaderStatusChanged {
    return _readerStatusController.stream;
  }
}
