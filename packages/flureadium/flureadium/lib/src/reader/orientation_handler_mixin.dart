import 'dart:async';
import 'package:flutter/material.dart' as mq show Orientation;
import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';

import '../../reader_channel.dart';

/// Mixin for handling orientation changes in reader widgets.
///
/// Works around an issue where orientation changes can leave the reader
/// on a fractional page (e.g., page 5.5). Re-navigates to current locator
/// after orientation change to ensure proper page alignment.
mixin OrientationHandlerMixin {
  mq.Orientation? _lastOrientation;

  /// Gets the last known orientation.
  mq.Orientation? get lastOrientation => _lastOrientation;

  /// Sets the last known orientation.
  set lastOrientation(mq.Orientation? value) => _lastOrientation = value;

  /// Handles orientation change workaround.
  ///
  /// TODO: Remove this workaround if the underlying issue is completely fixed in Readium.
  ///
  /// If orientation changes, fix page alignment so it doesn't stay on a weird-looking page 5½.
  void handleOrientationChange({
    required mq.Orientation currentOrientation,
    required bool isReady,
    required Locator? currentLocator,
    required ReadiumReaderChannel? channel,
  }) async {
    if (_lastOrientation == null) {
      _lastOrientation = currentOrientation;
      return;
    }

    if (!isReady) {
      return;
    }

    if (currentOrientation != _lastOrientation) {
      // Remove domRange/cssSelector, so it navigates to a progression, which will always
      // trigger scrolling to the nearest page.
      if (_lastOrientation != null && currentLocator != null) {
        Future.delayed(const Duration(milliseconds: 500)).then((final value) {
          R2Log.d(
            'Orientation changed. Re-navigating to current locator to re-align page.',
          );
          R2Log.d('locator = $currentLocator');
          channel?.go(
            currentLocator,
            animated: false,
            isAudioBookWithText:
                false, // TODO: isAudioBookWithText - we don't know atm.
          );
        });
      }

      _lastOrientation = currentOrientation;
    }
  }
}
