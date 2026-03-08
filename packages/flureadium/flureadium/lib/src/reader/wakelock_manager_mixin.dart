import 'dart:async';
import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mixin for managing wakelock functionality in reader widgets.
///
/// Enables wakelock to prevent screen from sleeping during reading sessions.
/// Automatically disables wakelock after 30 minutes of inactivity.
mixin WakelockManagerMixin {
  static const _wakelockTimerDuration = Duration(minutes: 30);

  Timer? _wakelockTimer;

  /// Enables wakelock and starts inactivity timer.
  ///
  /// Should be called on user interaction to keep screen awake during reading.
  /// Timer resets on each call - wakelock will disable after 30 minutes of no interaction.
  Future<void> enableWakelock() async {
    R2Log.d('Ensure wakelock /w timer');

    WakelockPlus.enable();

    // Disable wakelock after 30 minutes of inactivity (no interaction with reader).
    _wakelockTimer?.cancel();
    _wakelockTimer = Timer(_wakelockTimerDuration, disableWakelock);
  }

  /// Disables wakelock and cancels timer.
  ///
  /// Should be called when widget is disposed or when reading session ends.
  void disableWakelock() {
    R2Log.d('Disable wakelock');

    WakelockPlus.disable();
    _wakelockTimer?.cancel();
  }
}
