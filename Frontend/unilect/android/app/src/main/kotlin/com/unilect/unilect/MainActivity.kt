package com.unilect.unilect

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FR-058: the secure viewer toggles FLAG_SECURE, which blocks screenshots and
 * screen recording of the window and hides it in the recents screen.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "unilect/screen_protection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        runOnUiThread { window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) }
                        result.success(null)
                    }
                    "disable" -> {
                        runOnUiThread { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
