package dev.mulev.flureadium.events

import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.launch

class ErrorEventChannel(messenger: BinaryMessenger) :
    EventChannelWrapper<Map<String, Any?>>(messenger, "dev.mulev.flureadium/error") {
    override fun sendEvent(data: Map<String, Any?>) {
        mainScope.launch {
            eventSink?.success(data)
        }
    }
}
