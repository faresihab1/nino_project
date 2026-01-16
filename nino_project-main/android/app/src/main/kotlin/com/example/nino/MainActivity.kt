package com.example.nino  // <-- make sure this matches your real package

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.timezone"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getLocalTimezone") {
                    result.success(TimeZone.getDefault().id) // e.g. "Africa/Casablanca"
                } else {
                    result.notImplemented()
                }
            }
    }
}
