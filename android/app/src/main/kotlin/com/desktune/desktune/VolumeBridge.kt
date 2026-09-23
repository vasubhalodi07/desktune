package com.desktune.desktune

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

class VolumeBridge(private val context: Context) : EventChannel.StreamHandler {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var eventSink: EventChannel.EventSink? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun getCurrentVolumeRatio(): Double {
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
        } else {
            0
        }
        val range = (max - min).coerceAtLeast(1)
        return (current - min).toDouble() / range.toDouble()
    }

    fun setVolumeRatio(ratio: Double) {
        val clampedRatio = ratio.coerceIn(0.0, 1.0)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
        } else {
            0
        }
        val target = min + Math.round((max - min) * clampedRatio).toInt()
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        if (target != current) {
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
            notifyVolumeChanged()
        }
    }

    private fun notifyVolumeChanged() {
        val ratio = getCurrentVolumeRatio()
        mainHandler.post {
            eventSink?.success(mapOf(
                "volumeRatio" to ratio,
                "currentVolume" to audioManager.getStreamVolume(AudioManager.STREAM_MUSIC),
                "maxVolume" to audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            ))
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Send initial volume
        notifyVolumeChanged()

        if (volumeReceiver == null) {
            volumeReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                        val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                        if (streamType == AudioManager.STREAM_MUSIC || streamType == -1) {
                            notifyVolumeChanged()
                        }
                    }
                }
            }
            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            context.registerReceiver(volumeReceiver, filter)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        if (volumeReceiver != null) {
            try {
                context.unregisterReceiver(volumeReceiver)
            } catch (_: Exception) {}
            volumeReceiver = null
        }
    }

    fun dispose() {
        onCancel(null)
    }
}
