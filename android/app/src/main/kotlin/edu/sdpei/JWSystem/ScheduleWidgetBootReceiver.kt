package edu.sdpei.JWSystem

import android.content.Context
import android.content.Intent

class ScheduleWidgetBootReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = ScheduleWidgetDayResolver.prefs(context)
        ScheduleWidgetAlarmScheduler.schedule(context, prefs)
    }
}
