package com.example.uni

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {
    private var keyEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.uni.reader/hardware_key")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    keyEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    keyEventSink = null
                }
            })
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val sink = keyEventSink
        if (sink != null && event.action == KeyEvent.ACTION_DOWN) {
            val code = event.keyCode
            // Arrow keys and page keys used by page turners / stylus pens
            if (code == KeyEvent.KEYCODE_DPAD_LEFT ||
                code == KeyEvent.KEYCODE_DPAD_RIGHT ||
                code == KeyEvent.KEYCODE_DPAD_UP ||
                code == KeyEvent.KEYCODE_DPAD_DOWN ||
                code == KeyEvent.KEYCODE_PAGE_UP ||
                code == KeyEvent.KEYCODE_PAGE_DOWN
            ) {
                sink.success(code)
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
