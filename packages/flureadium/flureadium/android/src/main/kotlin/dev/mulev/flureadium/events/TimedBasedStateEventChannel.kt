package dev.mulev.flureadium.events

import dev.mulev.flureadium.jsonEncode
import dev.mulev.flureadium.models.ReadiumTimebasedState
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.launch

/**
 * Event channel for sending time-based state updates to Flutter.
 */
class TimedBasedStateEventChannel(messenger: BinaryMessenger) :
    EventChannelWrapper<ReadiumTimebasedState>(messenger, "dev.mulev.flureadium/timebased-state") {
    override fun sendEvent(data: ReadiumTimebasedState) {
        mainScope.launch {
            eventSink?.success(jsonEncode(data.toJSON()))
        }
    }
}
