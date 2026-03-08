package dev.mulev.flureadium.events

import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.launch

class ReaderStatusEventChannel(messenger: BinaryMessenger) :
    EventChannelWrapper<String>(messenger, "dev.mulev.flureadium/reader-status") {
    override fun sendEvent(data: String) {
        mainScope.launch {
            eventSink?.success(data)
        }
    }
}
