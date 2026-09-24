package com.desktune.desktune

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream

class MediaSessionBridge private constructor() : EventChannel.StreamHandler {

    companion object {
        val instance = MediaSessionBridge()
    }

    private var context: Context? = null
    private var sessionManager: MediaSessionManager? = null
    private var activeController: MediaController? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var cachedArtworkBytes: ByteArray? = null
    private var cachedArtworkKey: String? = null

    // Artwork key last delivered to the Dart side. The (large) artwork bytes are
    // only attached to an update when this differs from the current key.
    private var lastEmittedArtworkKey: String? = null

    // The sessions-changed listener only needs registering once per connection.
    private var sessionsListenerRegistered = false

    // Display name of the app that owns the active session (looked up once per app).
    private var cachedLabelPackage: String? = null
    private var cachedLabel: String = ""

    private val sessionsChangedListener =
        MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            updateActiveController(controllers)
        }

    private val controllerCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            emitCurrentMedia()
        }

        override fun onMetadataChanged(metadata: MediaMetadata?) {
            emitCurrentMedia()
        }

        override fun onSessionDestroyed() {
            activeController = null
            refreshSessions()
        }
    }

    fun init(appContext: Context) {
        context = appContext
        sessionManager = appContext.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
        refreshSessions()
    }

    fun onNotificationListenerConnected() {
        refreshSessions()
    }

    fun onNotificationListenerDisconnected() {
        sessionsListenerRegistered = false
        activeController?.unregisterCallback(controllerCallback)
        activeController = null
        emitCurrentMedia()
    }

    fun refreshSessions() {
        val ctx = context ?: return
        val mgr = sessionManager ?: return

        try {
            val componentName = DeskTuneNotificationListener.getComponentName(ctx)
            val controllers = mgr.getActiveSessions(componentName)
            updateActiveController(controllers)

            if (!sessionsListenerRegistered) {
                mgr.addOnActiveSessionsChangedListener(sessionsChangedListener, componentName)
                sessionsListenerRegistered = true
            }
        } catch (_: SecurityException) {
            // Notification access not granted yet
            sessionsListenerRegistered = false
            activeController = null
            emitCurrentMedia()
        } catch (_: Exception) {
            // Other exceptions
        }
    }

    private fun updateActiveController(controllers: List<MediaController>?) {
        if (controllers.isNullOrEmpty()) {
            if (activeController != null) {
                activeController?.unregisterCallback(controllerCallback)
                activeController = null
                emitCurrentMedia()
            }
            return
        }

        // Pick the best controller: prefer currently playing, else paused/buffering, else first
        var chosen: MediaController? = null
        for (c in controllers) {
            val state = c.playbackState?.state
            if (state == PlaybackState.STATE_PLAYING) {
                chosen = c
                break
            }
        }

        if (chosen == null) {
            for (c in controllers) {
                val state = c.playbackState?.state
                if (state == PlaybackState.STATE_PAUSED || state == PlaybackState.STATE_BUFFERING) {
                    chosen = c
                    break
                }
            }
        }

        if (chosen == null) {
            chosen = controllers.firstOrNull()
        }

        if (chosen != activeController) {
            activeController?.unregisterCallback(controllerCallback)
            activeController = chosen
            activeController?.registerCallback(controllerCallback)
            emitCurrentMedia()
        } else {
            emitCurrentMedia()
        }
    }

    /**
     * [knownArtworkKey] is the artwork the caller already holds; the artwork
     * bytes are left out when they haven't changed since.
     */
    fun getCurrentMediaData(knownArtworkKey: String? = null): Map<String, Any?> {
        val controller = activeController ?: return emptyMap()
        val metadata = controller.metadata
        val state = controller.playbackState

        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata?.description?.title?.toString()
            ?: ""

        val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.description?.subtitle?.toString()
            ?: ""

        val album = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM)
            ?: metadata?.description?.description?.toString()
            ?: ""

        val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val rawPosition = state?.position ?: 0L
        val lastUpdateElapsed = state?.lastPositionUpdateTime ?: 0L
        val playbackSpeed = state?.playbackSpeed ?: 1.0f
        val isPlaying = state?.state == PlaybackState.STATE_PLAYING

        val nowElapsed = android.os.SystemClock.elapsedRealtime()
        val timeDelta = if (isPlaying && lastUpdateElapsed > 0L && lastUpdateElapsed <= nowElapsed) {
            ((nowElapsed - lastUpdateElapsed) * playbackSpeed).toLong()
        } else {
            0L
        }
        val currentPosition = (rawPosition + timeDelta).coerceAtLeast(0L)
        val finalPosition = if (duration > 0L) currentPosition.coerceAtMost(duration) else currentPosition

        val actions = state?.actions ?: 0L

        val canPlay = (actions and PlaybackState.ACTION_PLAY != 0L) ||
                (actions and PlaybackState.ACTION_PLAY_PAUSE != 0L)
        val canPause = (actions and PlaybackState.ACTION_PAUSE != 0L) ||
                (actions and PlaybackState.ACTION_PLAY_PAUSE != 0L)
        val canNext = (actions and PlaybackState.ACTION_SKIP_TO_NEXT != 0L)
        val canPrevious = (actions and PlaybackState.ACTION_SKIP_TO_PREVIOUS != 0L)
        val canSeek = (actions and PlaybackState.ACTION_SEEK_TO != 0L)

        // Resolve Artwork
        val artworkBytes = resolveArtworkBytes(metadata, title, artist)
        val artworkKey = if (artworkBytes != null) cachedArtworkKey else null

        return mapOf(
            "hasActiveSession" to true,
            "packageName" to controller.packageName,
            "appName" to appLabelFor(controller.packageName),
            "title" to title,
            "artist" to artist,
            "album" to album,
            "duration" to duration,
            "position" to finalPosition,
            "lastUpdateTime" to System.currentTimeMillis(),
            "playbackSpeed" to playbackSpeed.toDouble(),
            "isPlaying" to isPlaying,
            "playbackStateCode" to (state?.state ?: PlaybackState.STATE_NONE),
            "canPlay" to canPlay,
            "canPause" to canPause,
            "canNext" to canNext,
            "canPrevious" to canPrevious,
            "canSeek" to canSeek,
            "artworkKey" to artworkKey,
            "artwork" to if (artworkKey != null && artworkKey != knownArtworkKey) artworkBytes else null
        )
    }

    /** The player's user-facing name (e.g. "Amazon Music"), or "" if unavailable. */
    @Suppress("DEPRECATION")
    private fun appLabelFor(packageName: String): String {
        if (packageName == cachedLabelPackage) return cachedLabel
        val label = try {
            val pm = context?.packageManager
            if (pm == null) "" else pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (_: Exception) {
            ""
        }
        cachedLabelPackage = packageName
        cachedLabel = label
        return label
    }

    /**
     * The app's launcher icon as a square PNG, or null if Android can't supply it
     * (the UI then shows a default). Adaptive icons are drawn with the system's
     * shape mask, so the result matches what the launcher shows.
     */
    fun appIconPng(packageName: String, sizePx: Int = 128): ByteArray? {
        return try {
            val drawable = context?.packageManager?.getApplicationIcon(packageName) ?: return null
            val bitmap = drawableToBitmap(drawable, sizePx)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable, sizePx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, sizePx, sizePx)
        drawable.draw(canvas)
        return bitmap
    }

    /**
     * Opens the app that owns the active session. Prefers the screen the player
     * registered for itself (its now-playing screen) and falls back to launching
     * the app. Returns false if there is nothing to open.
     */
    fun openPlayerApp(): Boolean {
        val ctx = context ?: return false
        val controller = activeController ?: return false

        val sessionActivity: PendingIntent? = controller.sessionActivity
        if (sessionActivity != null) {
            try {
                sessionActivity.send(ctx, 0, null, null, null, null, foregroundLaunchOptions())
                return true
            } catch (_: PendingIntent.CanceledException) {
                // Fall through to the launcher intent.
            }
        }

        val launch = ctx.packageManager.getLaunchIntentForPackage(controller.packageName)
            ?: return false
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            ctx.startActivity(launch)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Android 14+ silently blocks a PendingIntent that opens another app's screen
     * unless the sender explicitly opts in. DeskTune is in the foreground when the
     * user taps, so it is allowed to; older versions need no options.
     */
    private fun foregroundLaunchOptions(): android.os.Bundle? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return null
        return ActivityOptions.makeBasic()
            .setPendingIntentBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            )
            .toBundle()
    }

    private fun resolveArtworkBytes(metadata: MediaMetadata?, title: String, artist: String): ByteArray? {
        if (metadata == null) return null

        val currentKey = "$title::$artist::${metadata.getLong(MediaMetadata.METADATA_KEY_DURATION)}"
        if (currentKey == cachedArtworkKey && cachedArtworkBytes != null) {
            return cachedArtworkBytes
        }

        var bitmap: Bitmap? = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: metadata.description.iconBitmap

        if (bitmap == null) {
            val uriStr = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
                ?: metadata.getString(MediaMetadata.METADATA_KEY_ART_URI)
                ?: metadata.description.iconUri?.toString()

            if (!uriStr.isNullOrEmpty() && context != null) {
                try {
                    val uri = Uri.parse(uriStr)
                    val inputStream: InputStream? = context?.contentResolver?.openInputStream(uri)
                    if (inputStream != null) {
                        bitmap = BitmapFactory.decodeStream(inputStream)
                        inputStream.close()
                    }
                } catch (_: Exception) {}
            }
        }

        if (bitmap != null) {
            try {
                val stream = ByteArrayOutputStream()
                val targetSize = 800
                val scaled = if (bitmap.width > targetSize || bitmap.height > targetSize) {
                    val ratio = bitmap.width.toFloat() / bitmap.height.toFloat()
                    val targetWidth = if (ratio >= 1) targetSize else (targetSize * ratio).toInt()
                    val targetHeight = if (ratio >= 1) (targetSize / ratio).toInt() else targetSize
                    Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
                } else {
                    bitmap
                }
                scaled.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                val bytes = stream.toByteArray()
                cachedArtworkBytes = bytes
                cachedArtworkKey = currentKey
                return bytes
            } catch (_: Exception) {}
        }

        cachedArtworkBytes = null
        cachedArtworkKey = currentKey
        return null
    }

    private fun emitCurrentMedia() {
        // Nobody is listening (app in the background): skip building the payload.
        if (eventSink == null) return

        val data = getCurrentMediaData(lastEmittedArtworkKey)
        mainHandler.post {
            val sink = eventSink ?: return@post
            lastEmittedArtworkKey = data["artworkKey"] as String?
            sink.success(data)
        }
    }

    // Transport controls
    fun togglePlayPause() {
        val controls = activeController?.transportControls ?: return
        if (activeController?.playbackState?.state == PlaybackState.STATE_PLAYING) {
            controls.pause()
        } else {
            controls.play()
        }
    }

    fun skipToNext() {
        activeController?.transportControls?.skipToNext()
    }

    fun skipToPrevious() {
        activeController?.transportControls?.skipToPrevious()
    }

    fun seekTo(positionMs: Long) {
        activeController?.transportControls?.seekTo(positionMs)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        lastEmittedArtworkKey = null
        refreshSessions()
        emitCurrentMedia()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        lastEmittedArtworkKey = null
    }
}
