package com.limitless.voice_recorder

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class RecordingWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_TOGGLE_RECORDING) {
            // Launch the app with recording intent
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "toggle_recording")
            }
            context.startActivity(launchIntent)
        }
    }

    companion object {
        const val ACTION_TOGGLE_RECORDING = "com.limitless.voice_recorder.TOGGLE_RECORDING"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.recording_widget)

            // Create intent for tap action
            val intent = Intent(context, RecordingWidgetProvider::class.java).apply {
                action = ACTION_TOGGLE_RECORDING
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_mic_icon, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_status, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_duration, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
