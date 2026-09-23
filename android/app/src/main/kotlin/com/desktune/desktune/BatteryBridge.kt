package com.desktune.desktune

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

class BatteryBridge(private val context: Context) : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var batteryReceiver: BroadcastReceiver? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun getBatteryData(): Map<String, Any> {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val directCap = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1

        var batteryPct = if (directCap in 0..100) directCap else -1
        var isCharging = false

        try {
            val intentFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus: Intent? = context.registerReceiver(null, intentFilter)
            if (batteryPct < 0 && batteryStatus != null) {
                val level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (level >= 0 && scale > 0) {
                    batteryPct = (level * 100) / scale
                }
            }

            if (batteryStatus != null) {
                val status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                val plugged = batteryStatus.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
                isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL ||
                        plugged > 0
            }
        } catch (_: Exception) {}

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M && bm != null) {
            isCharging = isCharging || bm.isCharging
        }

        if (batteryPct < 0) {
            batteryPct = 100
        }

        return mapOf(
            "level" to batteryPct,
            "isCharging" to isCharging
        )
    }

    private fun sendBatteryUpdate() {
        val data = getBatteryData()
        mainHandler.post {
            eventSink?.success(data)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        sendBatteryUpdate()

        if (batteryReceiver == null) {
            batteryReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    sendBatteryUpdate()
                }
            }
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_BATTERY_CHANGED)
                addAction(Intent.ACTION_POWER_CONNECTED)
                addAction(Intent.ACTION_POWER_DISCONNECTED)
            }
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    context.registerReceiver(batteryReceiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    context.registerReceiver(batteryReceiver, filter)
                }
            } catch (_: Exception) {
                try {
                    context.registerReceiver(batteryReceiver, filter)
                } catch (_: Exception) {}
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        if (batteryReceiver != null) {
            try {
                context.unregisterReceiver(batteryReceiver)
            } catch (_: Exception) {}
            batteryReceiver = null
        }
    }

    fun dispose() {
        onCancel(null)
    }
}
