package com.jolinx.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val FONT_CHANNEL = "com.jolinx.app/system_font"
    private val INSTALLER_CHANNEL = "com.jolinx.app/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FONT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFontScale" -> {
                        result.success(getFontScale())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("filePath")
                        if (path == null) {
                            result.error("INVALID_PATH", "File path cannot be null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = java.io.File(path)
                            if (!file.exists()) {
                                result.error("FILE_NOT_FOUND", "APK file does not exist at $path", null)
                                return@setMethodCallHandler
                            }

                            val apkUri = androidx.core.content.FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileProvider",
                                file
                            )

                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                    "canRequestPackageInstalls" -> {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            result.success(packageManager.canRequestPackageInstalls())
                        } else {
                            result.success(true)
                        }
                    }
                    "openInstallPermissionSettings" -> {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            try {
                                val intent = android.content.Intent(
                                    android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    android.net.Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SETTINGS_ERROR", e.localizedMessage, null)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    "getAppVersion" -> {
                        try {
                            val pInfo = packageManager.getPackageInfo(packageName, 0)
                            val versionName = pInfo.versionName ?: "1.0.0"
                            val versionCode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                                pInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                pInfo.versionCode.toLong()
                            }
                            result.success(mapOf("versionName" to versionName, "versionCode" to versionCode))
                        } catch (e: Exception) {
                            result.error("VERSION_ERROR", e.localizedMessage, null)
                        }
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
