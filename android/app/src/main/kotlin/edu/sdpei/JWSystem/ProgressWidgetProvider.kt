package edu.sdpei.JWSystem

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.net.Uri
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ProgressWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_progress).apply {
                setTextViewText(R.id.tv_gpa, widgetData.getString("gpa", "--"))
                setTextViewText(R.id.tv_major_extra, widgetData.getString("major_extra_credits", "--"))
                setTextViewText(R.id.tv_earned, widgetData.getString("earned_credits", "--"))
                setTextViewText(R.id.tv_required, widgetData.getString("required_credits", "--"))

                // Click Intent
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("jwhelper://progress")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(android.R.id.background, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
