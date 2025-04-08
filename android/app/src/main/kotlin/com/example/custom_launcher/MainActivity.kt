package com.test.custom_launcher

import android.app.WallpaperManager
import android.app.role.RoleManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "wallpaper_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWallpaper" -> handleGetWallpaper(result)
                    "requestLauncherRole" -> requestLauncherRole(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleGetWallpaper(result: MethodChannel.Result) {
        try {
            // Runtime permission check for Android 13+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(android.Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED
            ) {
                result.error("PERMISSION_DENIED", "READ_MEDIA_IMAGES not granted", null)
                return
            }

            val wallpaperDrawable = WallpaperManager.getInstance(applicationContext).drawable

            if (wallpaperDrawable is BitmapDrawable) {
                val bitmap: Bitmap = wallpaperDrawable.bitmap
                val outputStream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                result.success(outputStream.toByteArray())
            } else {
                result.error("INVALID_TYPE", "Wallpaper is not a bitmap", null)
            }

        } catch (e: Exception) {
            result.error("UNEXPECTED_ERROR", "Error retrieving wallpaper: ${e.localizedMessage}", null)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun requestLauncherRole(result: MethodChannel.Result) {
        val roleManager = getSystemService(RoleManager::class.java)
        if (roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
            startActivity(intent) // the user needs to grant this manually
            result.success(true)
        } else {
            result.error("ROLE_NOT_AVAILABLE", "ROLE_HOME is not available", null)
        }
    }
}
