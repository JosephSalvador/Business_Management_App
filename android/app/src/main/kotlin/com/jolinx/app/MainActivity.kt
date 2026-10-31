package com.jolinx.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val FONT_CHANNEL = "com.jolinx.app/system_font"
    private val INSTALLER_CHANNEL = "com.jolinx.app/installer"
    private val MEDIA_PICKER_CHANNEL = "com.jolinx.app/media_picker"
    private val PICK_IMAGE_REQUEST = 9401
    private var pendingImageResult: MethodChannel.Result? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_PICKER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImageBase64" -> {
                        if (pendingImageResult != null) {
                            result.error("BUSY", "Another image picker request is already active.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            pendingImageResult = result
                            val intent = android.content.Intent(android.content.Intent.ACTION_GET_CONTENT).apply {
                                type = "image/*"
                                addCategory(android.content.Intent.CATEGORY_OPENABLE)
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(
                                android.content.Intent.createChooser(intent, "Select Business Logo"),
                                PICK_IMAGE_REQUEST
                            )
                        } catch (e: Exception) {
                            pendingImageResult = null
                            result.error("PICKER_ERROR", e.localizedMessage, null)
                        }
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

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            val callback = pendingImageResult
            pendingImageResult = null
            if (callback == null) return
            if (resultCode != android.app.Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            try {
                val uri = data.data!!
                val inputStream = contentResolver.openInputStream(uri)
                val original = android.graphics.BitmapFactory.decodeStream(inputStream)
                inputStream?.close()
                if (original == null) {
                    callback.error("DECODE_ERROR", "Could not decode selected image.", null)
                    return
                }
                val maxDim = 420
                val width = original.width
                val height = original.height
                val scaled = if (width > maxDim || height > maxDim) {
                    val ratio = maxDim.toFloat() / maxOf(width, height).toFloat()
                    val newW = (width * ratio).toInt().coerceAtLeast(1)
                    val newH = (height * ratio).toInt().coerceAtLeast(1)
                    android.graphics.Bitmap.createScaledBitmap(original, newW, newH, true)
                } else {
                    original
                }
                val output = java.io.ByteArrayOutputStream()
                scaled.compress(android.graphics.Bitmap.CompressFormat.PNG, 90, output)
                val base64 = android.util.Base64.encodeToString(output.toByteArray(), android.util.Base64.NO_WRAP)
                callback.success(base64)
            } catch (e: Exception) {
                callback.error("READ_ERROR", e.localizedMessage, null)
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
