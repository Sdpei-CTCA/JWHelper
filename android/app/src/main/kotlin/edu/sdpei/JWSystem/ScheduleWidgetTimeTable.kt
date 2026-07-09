package edu.sdpei.JWSystem

import java.util.Calendar
import java.util.Locale

object ScheduleWidgetTimeTable {
    private val jinanStartMinutes = mapOf(
        1 to 8 * 60,
        2 to 8 * 60 + 45,
        3 to 10 * 60,
        4 to 10 * 60 + 45,
        5 to 13 * 60 + 30,
        6 to 14 * 60 + 15,
        7 to 15 * 60 + 30,
        8 to 16 * 60 + 15,
        9 to 19 * 60,
        10 to 19 * 60 + 45,
        11 to 20 * 60 + 30,
        12 to 21 * 60 + 15,
    )

    private val jinanEndMinutes = mapOf(
        1 to 8 * 60 + 45,
        2 to 9 * 60 + 30,
        3 to 10 * 60 + 45,
        4 to 11 * 60 + 30,
        5 to 14 * 60 + 15,
        6 to 15 * 60,
        7 to 16 * 60 + 15,
        8 to 17 * 60,
        9 to 19 * 60 + 45,
        10 to 20 * 60 + 30,
        11 to 21 * 60 + 15,
        12 to 22 * 60,
    )

    fun isSummer(date: Calendar): Boolean {
        val month = date.get(Calendar.MONTH) + 1
        return when {
            month > 5 && month < 10 -> true
            month == 5 -> true
            else -> false
        }
    }

    fun periodStartMinutes(period: Int, campus: String, date: Calendar): Int? {
        if (campus != "日照") {
            return jinanStartMinutes[period]
        }

        if (period <= 4) {
            return jinanStartMinutes[period]
        }

        val summer = isSummer(date)
        return when (period) {
            5 -> if (summer) 14 * 60 + 30 else 14 * 60
            6 -> if (summer) 15 * 60 + 20 else 14 * 60 + 50
            7 -> if (summer) 16 * 60 + 30 else 16 * 60
            8 -> if (summer) 17 * 60 + 20 else 16 * 60 + 50
            9 -> 19 * 60
            10 -> 19 * 60 + 50
            11 -> 20 * 60 + 40
            12 -> 21 * 60 + 30
            else -> null
        }
    }

    fun periodEndMinutes(period: Int, campus: String, date: Calendar): Int? {
        if (campus != "日照") {
            return jinanEndMinutes[period]
        }

        if (period <= 4) {
            return jinanEndMinutes[period]
        }

        val summer = isSummer(date)
        return when (period) {
            5 -> if (summer) 15 * 60 + 10 else 14 * 60 + 40
            6 -> if (summer) 16 * 60 else 15 * 60 + 30
            7 -> if (summer) 17 * 60 + 10 else 16 * 60 + 40
            8 -> if (summer) 18 * 60 else 17 * 60 + 30
            9 -> 20 * 60 + 30
            10 -> 21 * 60 + 20
            11 -> 22 * 60 + 10
            12 -> 23 * 60
            else -> null
        }
    }

    fun endMinutesForUnit(endUnit: Int, campus: String, date: Calendar): Int {
        return periodEndMinutes(endUnit, campus, date) ?: (23 * 60 + 59)
    }

    fun formatMinutes(minutes: Int): String {
        val hour = minutes / 60
        val minute = minutes % 60
        return String.format(Locale.getDefault(), "%02d:%02d", hour, minute)
    }

    fun formatTimeRange(startPeriod: Int, endPeriod: Int, campus: String, date: Calendar): String {
        val start = periodStartMinutes(startPeriod, campus, date) ?: 0
        val end = periodEndMinutes(endPeriod, campus, date) ?: 0
        return "${formatMinutes(start)} - ${formatMinutes(end)}"
    }

    fun periodEndMillisToday(period: Int, campus: String, now: Calendar = Calendar.getInstance()): Long? {
        val endMinutes = periodEndMinutes(period, campus, now) ?: return null
        val trigger = now.clone() as Calendar
        trigger.set(Calendar.HOUR_OF_DAY, endMinutes / 60)
        trigger.set(Calendar.MINUTE, endMinutes % 60)
        trigger.set(Calendar.SECOND, 5)
        trigger.set(Calendar.MILLISECOND, 0)
        return trigger.timeInMillis
    }

    fun nextMidnightMillis(now: Calendar = Calendar.getInstance()): Long {
        val midnight = now.clone() as Calendar
        midnight.add(Calendar.DAY_OF_YEAR, 1)
        midnight.set(Calendar.HOUR_OF_DAY, 0)
        midnight.set(Calendar.MINUTE, 1)
        midnight.set(Calendar.SECOND, 0)
        midnight.set(Calendar.MILLISECOND, 0)
        return midnight.timeInMillis
    }
}
