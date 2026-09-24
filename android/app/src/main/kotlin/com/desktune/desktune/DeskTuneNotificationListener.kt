package com.desktune.desktune

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class DeskTuneNotificationListener : NotificationListenerService() {

    companion object {
        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context, DeskTuneNotificationListener::class.java)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        MediaSessionBridge.instance.onNotificationListenerConnected()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        MediaSessionBridge.instance.onNotificationListenerDisconnected()
    }

    // The media-session listeners already report playback changes. This service
    // is bound for the whole day, so ignore every notification that isn't a
    // media one instead of doing work for each message from every other app.
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn.isMediaNotification()) MediaSessionBridge.instance.refreshSessions()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn.isMediaNotification()) MediaSessionBridge.instance.refreshSessions()
    }

    private fun StatusBarNotification?.isMediaNotification(): Boolean {
        val notification = this?.notification ?: return false
        return notification.category == Notification.CATEGORY_TRANSPORT ||
            notification.extras?.containsKey(Notification.EXTRA_MEDIA_SESSION) == true
    }
}
