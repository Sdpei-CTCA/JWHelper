package edu.sdpei.JWSystem

import java.util.Calendar
import java.util.Locale

/**
 * 各校区教学作息时间表（官方《教学作息时间安排表》的正本）。
 *
 * 与 Dart 侧 `lib/core/constants/period_time_table.dart` 逐行对应，两者必须同时更新。
 *
 * * 每节 40 分钟。第 1-9 节两校区完全一致，仅第 10-12 节不同。
 * * 济南校区没有第 10 节（官方表中该行为 `/`），故其映射中不含 10。
 * * 官方表格不分夏令时/冬令时，全天候使用同一张表。
 */
object ScheduleWidgetTimeTable {
    /** 济南：第 1-9 节与日照相同，第 10 节不存在，第 11-12 节早于日照。 */
    private val jinanStartMinutes = mapOf(
        1 to 8 * 60,
        2 to 8 * 60 + 45,
        3 to 9 * 60 + 45,
        4 to 10 * 60 + 30,
        5 to 11 * 60 + 15,
        6 to 14 * 60,
        7 to 14 * 60 + 45,
        8 to 15 * 60 + 45,
        9 to 16 * 60 + 30,
        11 to 18 * 60 + 30,
        12 to 19 * 60 + 15,
    )

    private val jinanEndMinutes = mapOf(
        1 to 8 * 60 + 40,
        2 to 9 * 60 + 25,
        3 to 10 * 60 + 25,
        4 to 11 * 60 + 10,
        5 to 11 * 60 + 55,
        6 to 14 * 60 + 40,
        7 to 15 * 60 + 25,
        8 to 16 * 60 + 25,
        9 to 17 * 60 + 10,
        11 to 19 * 60 + 10,
        12 to 19 * 60 + 55,
    )

    private val rizhaoStartMinutes = mapOf(
        1 to 8 * 60,
        2 to 8 * 60 + 45,
        3 to 9 * 60 + 45,
        4 to 10 * 60 + 30,
        5 to 11 * 60 + 15,
        6 to 14 * 60,
        7 to 14 * 60 + 45,
        8 to 15 * 60 + 45,
        9 to 16 * 60 + 30,
        10 to 17 * 60 + 15,
        11 to 19 * 60,
        12 to 19 * 60 + 45,
    )

    private val rizhaoEndMinutes = mapOf(
        1 to 8 * 60 + 40,
        2 to 9 * 60 + 25,
        3 to 10 * 60 + 25,
        4 to 11 * 60 + 10,
        5 to 11 * 60 + 55,
        6 to 14 * 60 + 40,
        7 to 15 * 60 + 25,
        8 to 16 * 60 + 25,
        9 to 17 * 60 + 10,
        10 to 17 * 60 + 55,
        11 to 19 * 60 + 40,
        12 to 20 * 60 + 25,
    )

    fun periodStartMinutes(period: Int, campus: String): Int? =
        if (campus == "日照") rizhaoStartMinutes[period] else jinanStartMinutes[period]

    fun periodEndMinutes(period: Int, campus: String): Int? =
        if (campus == "日照") rizhaoEndMinutes[period] else jinanEndMinutes[period]

    /**
     * 该校区该节次的下课时间（零点起的分钟数）。
     *
     * 节次不存在时（例如济南的第 10 节）返回当天最后一分钟，使调用方的
     * “是否已下课”判定退化为“保持可见”，不会把课程误判为已结束而隐藏。
     */
    fun endMinutesForUnit(endUnit: Int, campus: String): Int =
        periodEndMinutes(endUnit, campus) ?: (23 * 60 + 59)

    fun formatMinutes(minutes: Int): String {
        val hour = minutes / 60
        val minute = minutes % 60
        return String.format(Locale.getDefault(), "%02d:%02d", hour, minute)
    }

    fun formatTimeRange(startPeriod: Int, endPeriod: Int, campus: String): String {
        val start = periodStartMinutes(startPeriod, campus) ?: 0
        val end = periodEndMinutes(endPeriod, campus) ?: 0
        return "${formatMinutes(start)} - ${formatMinutes(end)}"
    }

    fun periodEndMillisToday(period: Int, campus: String, now: Calendar = Calendar.getInstance()): Long? {
        val endMinutes = periodEndMinutes(period, campus) ?: return null
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
