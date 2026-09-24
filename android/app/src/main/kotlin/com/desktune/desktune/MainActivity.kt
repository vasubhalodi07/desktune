package com.desktune.desktune

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.desktune.app/media"
        private const val MEDIA_EVENTS_CHANNEL = "com.desktune.app/media_events"
        private const val VOLUME_EVENTS_CHANNEL = "com.desktune.app/volume_events"
        private const val BATTERY_EVENTS_CHANNEL = "com.desktune.app/battery_events"
        private val FILE_INSTALLERS = setOf(
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.miui.packageinstaller"
        )
    }

    private var methodChannel: MethodChannel? = null
    private var mediaEventChannel: EventChannel? = null
    private var volumeEventChannel: EventChannel? = null
    private var volumeBridge: VolumeBridge? = null
    private var batteryEventChannel: EventChannel? = null
    private var batteryBridge: BatteryBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MediaSessionBridge.instance.init(applicationContext)
        volumeBridge = VolumeBridge(applicationContext)
        batteryBridge = BatteryBridge(applicationContext)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler(this)

        mediaEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_EVENTS_CHANNEL)
        mediaEventChannel?.setStreamHandler(MediaSessionBridge.instance)

        volumeEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_EVENTS_CHANNEL)
        volumeEventChannel?.setStreamHandler(volumeBridge)

        batteryEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_EVENTS_CHANNEL)
        batteryEventChannel?.setStreamHandler(batteryBridge)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Default to keeping screen on in Desk Mode
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Restore saved brightness
        val prefs = getSharedPreferences("desktune_prefs", MODE_PRIVATE)
        val savedBrightness = prefs.getFloat("desk_brightness", 0.7f)
        val layoutParams = window.attributes
        layoutParams.screenBrightness = savedBrightness.coerceIn(0.01f, 1.0f)
        window.attributes = layoutParams
    }

    override fun onResume() {
        super.onResume()
        MediaSessionBridge.instance.refreshSessions()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> {
                result.success(isNotificationListenerGranted())
            }
            "openNotificationSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SETTINGS_ERROR", e.localizedMessage, null)
                }
            }
            "isRestrictedSettingsLikely" -> {
                result.success(isRestrictedSettingsLikely())
            }
            "openAppInfo" -> {
                try {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("APP_INFO_ERROR", e.localizedMessage, null)
                }
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName")
                result.success(
                    if (packageName == null) null
                    else MediaSessionBridge.instance.appIconPng(packageName)
                )
            }
            "openPlayerApp" -> {
                result.success(MediaSessionBridge.instance.openPlayerApp())
            }
            "getCurrentMedia" -> {
                result.success(
                    MediaSessionBridge.instance.getCurrentMediaData(
                        call.argument<String>("knownArtworkKey")
                    )
                )
            }
            "togglePlayPause" -> {
                MediaSessionBridge.instance.togglePlayPause()
                result.success(true)
            }
            "next" -> {
                MediaSessionBridge.instance.skipToNext()
                result.success(true)
            }
            "previous" -> {
                MediaSessionBridge.instance.skipToPrevious()
                result.success(true)
            }
            "seekTo" -> {
                val position = (call.argument<Number>("position"))?.toLong() ?: 0L
                MediaSessionBridge.instance.seekTo(position)
                result.success(true)
            }
            "getVolume" -> {
                result.success(volumeBridge?.getCurrentVolumeRatio() ?: 0.5)
            }
            "setVolume" -> {
                val volume = (call.argument<Number>("volume"))?.toDouble() ?: 0.5
                volumeBridge?.setVolumeRatio(volume)
                result.success(true)
            }
            "getBrightness" -> {
                val cur = window.attributes.screenBrightness
                if (cur in 0.01f..1.0f) {
                    result.success(cur.toDouble())
                } else {
                    val prefs = getSharedPreferences("desktune_prefs", MODE_PRIVATE)
                    val saved = prefs.getFloat("desk_brightness", 0.7f)
                    result.success(saved.toDouble())
                }
            }
            "setBrightness" -> {
                val brightness = (call.argument<Number>("brightness"))?.toFloat() ?: 0.7f
                val clamped = brightness.coerceIn(0.01f, 1.0f)
                runOnUiThread {
                    val layoutParams = window.attributes
                    layoutParams.screenBrightness = clamped
                    window.attributes = layoutParams
                }
                val prefs = getSharedPreferences("desktune_prefs", MODE_PRIVATE).edit()
                prefs.putFloat("desk_brightness", clamped)
                prefs.apply()
                result.success(true)
            }
            "getBatteryStatus" -> {
                result.success(batteryBridge?.getBatteryData() ?: mapOf("level" to -1, "isCharging" to false))
            }
            "setKeepScreenOn" -> {
                val keepOn = call.argument<Boolean>("keepOn") ?: true
                if (keepOn) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(true)
            }
            "getSystemTimeFormat24" -> {
                result.success(android.text.format.DateFormat.is24HourFormat(this))
            }
            "getSettings" -> {
                val prefs = getSharedPreferences("desktune_prefs", MODE_PRIVATE)
                result.success(mapOf(
                    "followSystemTimeFormat" to prefs.getBoolean("followSystemTimeFormat", true),
                    "is24HourFormat" to prefs.getBoolean("is24HourFormat", false),
                    "showSeconds" to prefs.getBoolean("showSeconds", false),
                    "showDate" to prefs.getBoolean("showDate", true),
                    "autoHideControls" to prefs.getBoolean("autoHideControls", true),
                    "autoHideDelaySeconds" to prefs.getInt("autoHideDelaySeconds", 5),
                    "keepScreenAwake" to prefs.getBoolean("keepScreenAwake", true)
                ))
            }
            "saveSettings" -> {
                val prefs = getSharedPreferences("desktune_prefs", MODE_PRIVATE).edit()
                call.argument<Boolean>("followSystemTimeFormat")?.let { prefs.putBoolean("followSystemTimeFormat", it) }
                call.argument<Boolean>("is24HourFormat")?.let { prefs.putBoolean("is24HourFormat", it) }
                call.argument<Boolean>("showSeconds")?.let { prefs.putBoolean("showSeconds", it) }
                call.argument<Boolean>("showDate")?.let { prefs.putBoolean("showDate", it) }
                call.argument<Boolean>("autoHideControls")?.let { prefs.putBoolean("autoHideControls", it) }
                call.argument<Int>("autoHideDelaySeconds")?.let { prefs.putInt("autoHideDelaySeconds", it) }
                call.argument<Boolean>("keepScreenAwake")?.let { prefs.putBoolean("keepScreenAwake", it) }
                prefs.apply()
                result.success(true)
            }
            "refreshSessions" -> {
                MediaSessionBridge.instance.refreshSessions()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Android 13+ greys out Notification access ("Restricted setting") for apps installed
     * from a file until the user allows it in App info. Apps are not permitted to read
     * that app-op themselves (SecurityException), so infer it from the install source.
     */
    private fun isRestrictedSettingsLikely(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        return isInstalledFromFile() && !isNotificationListenerGranted()
    }

    /** True when installed through a file installer (not a store, not adb). */
    private fun isInstalledFromFile(): Boolean {
        return try {
            val installer = packageManager.getInstallSourceInfo(packageName).installingPackageName
            installer in FILE_INSTALLERS
        } catch (_: Exception) {
            false
        }
    }

    private fun isNotificationListenerGranted(): Boolean {
        try {
            val enabledListeners = NotificationManagerCompat.getEnabledListenerPackages(this)
            if (enabledListeners.contains(packageName)) {
                return true
            }
        } catch (_: Exception) {}

        try {
            val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            if (!flat.isNullOrEmpty()) {
                val names = flat.split(":")
                for (name in names) {
                    val cn = ComponentName.unflattenFromString(name)
                    if (cn != null && cn.packageName == packageName) {
                        return true
                    }
                }
            }
        } catch (_: Exception) {}

        return false
    }

    override fun onDestroy() {
        methodChannel?.setMethodCallHandler(null)
        mediaEventChannel?.setStreamHandler(null)
        volumeEventChannel?.setStreamHandler(null)
        batteryEventChannel?.setStreamHandler(null)
        volumeBridge?.dispose()
        batteryBridge?.dispose()
        super.onDestroy()
    }
}
