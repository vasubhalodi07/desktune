package com.desktune.desktune

import android.content.ComponentName
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class DeskTuneNotificationListener : NotificationListenerService() {

    companion object {
        var isConnected: Boolean = false
            private set

        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context, DeskTuneNotificationListener::class.java)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        MediaSessionBridge.instance.onNotificationListenerConnected(this)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
        MediaSessionBridge.instance.onNotificationListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        // Whenever notifications are posted, media sessions might have updated
        MediaSessionBridge.instance.refreshSessions()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        MediaSessionBridge.instance.refreshSessions()
    }
}
