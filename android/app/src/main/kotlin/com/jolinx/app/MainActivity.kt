package com.jolinx.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.jolinx.app/system_font"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFontScale" -> {
                        result.success(getFontScale())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getFontScale(): Float {
        return try {
            @Suppress("DEPRECATION")
            resources.configuration.fontScale
        } catch (_: Exception) {
            1.0f
        }
    }
}
