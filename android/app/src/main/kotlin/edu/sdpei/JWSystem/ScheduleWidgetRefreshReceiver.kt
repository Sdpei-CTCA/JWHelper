package edu.sdpei.JWSystem

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class ScheduleWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = ScheduleWidgetDayResolver.prefs(context)
        ScheduleWidgetDayResolver.refreshIfNeeded(context, prefs)

        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, ScheduleWidgetProvider::class.java)
        val widgetIds = manager.getAppWidgetIds(component)
        if (widgetIds.isEmpty()) {
            ScheduleWidgetAlarmScheduler.cancelAll(context)
            return
        }

        ScheduleWidgetProvider.updateWidgets(context, manager, widgetIds, prefs)
        ScheduleWidgetAlarmScheduler.schedule(context, prefs)
    }
}
