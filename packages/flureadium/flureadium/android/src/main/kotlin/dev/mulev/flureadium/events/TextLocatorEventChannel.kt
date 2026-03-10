package dev.mulev.flureadium.events

import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.launch

/**
 * Event channel for sending text locator updates to Flutter.
 */
class TextLocatorEventChannel(messenger: BinaryMessenger) :
    EventChannelWrapper<Map<String, Any?>>(messenger, "dev.mulev.flureadium/text-locator") {
    override fun sendEvent(data: Map<String, Any?>) {
        mainScope.launch {
            eventSink?.success(data)
        }
    }
}
