package edu.sdpei.JWSystem

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

object ScheduleWidgetAlarmScheduler {
    private fun actionRefresh(context: Context): String =
        "${context.packageName}.action.SCHEDULE_WIDGET_REFRESH"
    private const val REQUEST_CODE_BASE = 9100
    private const val MAX_ALARMS = 24

    fun schedule(context: Context, prefs: SharedPreferences) {
        cancelAll(context)

        if ((prefs.getString("widget_display_mode", "schedule") ?: "schedule") != "schedule") {
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val campus = prefs.getString("widget_campus", "济南") ?: "济南"
        val now = System.currentTimeMillis()
        val refreshTimes = linkedSetOf<Long>()

        for (period in 1..12) {
            val triggerAt = ScheduleWidgetTimeTable.periodEndMillisToday(period, campus) ?: continue
            if (triggerAt > now + 1_000L) {
                refreshTimes.add(triggerAt)
            }
        }

        refreshTimes.add(ScheduleWidgetTimeTable.nextMidnightMillis())

        refreshTimes.sorted().take(MAX_ALARMS).forEachIndexed { index, triggerAt ->
            val pendingIntent = refreshPendingIntent(context, REQUEST_CODE_BASE + index)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                }
            } catch (_: SecurityException) {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        for (index in 0 until MAX_ALARMS) {
            val pendingIntent = refreshPendingIntent(context, REQUEST_CODE_BASE + index)
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun refreshPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, ScheduleWidgetRefreshReceiver::class.java).apply {
            action = actionRefresh(context)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }
}
