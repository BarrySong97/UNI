package dev.mulev.flureadium.events

import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.launch

/**
 * Event channel for notifying Flutter that the EPUB is ready.
 */
class EpubIsReadyEventChannel(messenger: BinaryMessenger) :
    EventChannelWrapper<Boolean>(messenger, "dev.mulev.flureadium/is-ready") {
    override fun sendEvent(data: Boolean) {
        mainScope.launch {
            eventSink?.success(null)
        }
    }
}
