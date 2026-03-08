import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';

/// Mixin for managing reader widget lifecycle.
///
/// Handles registration and cleanup of the reader widget with the platform instance.
mixin ReaderLifecycleMixin {
  /// Gets the platform instance.
  FlureadiumPlatform get readium => FlureadiumPlatform.instance;

  /// Sets this widget as the current reader in the platform instance.
  ///
  /// Should be called during widget initialization.
  void setCurrentWidgetInterface(ReadiumReaderWidgetInterface widget) {
    R2Log.d('Set current reader in plugin');
    readium.currentReaderWidget = widget;
  }

  /// Cleans up reader widget registration.
  ///
  /// Should be called during widget disposal.
  void cleanupWidgetInterface(String? channelName) {
    R2Log.d('cleanup $channelName!');
    readium.currentReaderWidget = null;
  }
}
