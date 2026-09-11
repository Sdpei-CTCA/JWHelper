package edu.sdpei.JWSystem

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * 桌面课程表小组件使用的纯时间逻辑。
 *
 * 从 [ScheduleWidgetProvider] 中抽取，不依赖任何 Android 框架类，
 * 因此可以直接在 JVM 单元测试中验证（见 `src/test` 下的 ScheduleWidgetLogicTest）。
 */
internal object ScheduleWidgetLogic {

    // Official class-period timetable (40-minute periods).
    // Periods 1-9 are identical on both campuses; the campuses only differ at periods 10-12,
    // and Jinan campus has no period 10.
    private val jinanTimeMap = mapOf(
        1 to "08:00-08:40",
        2 to "08:45-09:25",
        3 to "09:45-10:25",
        4 to "10:30-11:10",
        5 to "11:15-11:55",
        6 to "14:00-14:40",
        7 to "14:45-15:25",
        8 to "15:45-16:25",
        9 to "16:30-17:10",
        11 to "18:30-19:10",
        12 to "19:15-19:55"
    )

    private val rizhaoTimeMap = mapOf(
        1 to "08:00-08:40",
        2 to "08:45-09:25",
        3 to "09:45-10:25",
        4 to "10:30-11:10",
        5 to "11:15-11:55",
        6 to "14:00-14:40",
        7 to "14:45-15:25",
        8 to "15:45-16:25",
        9 to "16:30-17:10",
        10 to "17:15-17:55",
        11 to "19:00-19:40",
        12 to "19:45-20:25"
    )

    /** 返回校区对应的节次时间表；未知校区默认按济南处理。 */
    fun timeMapFor(campus: String): Map<Int, String> =
        if (campus == "日照") rizhaoTimeMap else jinanTimeMap

    /** 返回 "开始 - 结束" 时间区间；该校区不存在对应节次时返回空字符串。 */
    fun getTimeRange(start: Int, end: Int, campus: String): String {
        val map = timeMapFor(campus)
        val startStr = map[start]?.split("-")?.getOrNull(0)
        val endStr = map[end]?.split("-")?.getOrNull(1)
        if (startStr == null || endStr == null) return ""
        return "$startStr - $endStr"
    }

    /**
     * 判断以第 [end] 节结束的课程在 [now] 时刻是否已经下课。
     * 节次在对应校区的时间表中不存在时按"已下课"处理。
     */
    fun isClassPassed(end: Int, campus: String, now: Calendar = Calendar.getInstance()): Boolean {
        val currentHour = now.get(Calendar.HOUR_OF_DAY)
        val currentMinute = now.get(Calendar.MINUTE)
        val endStr = timeMapFor(campus)[end]?.split("-")?.getOrNull(1) ?: return true
        val parts = endStr.split(":")
        if (parts.size != 2) return true

        val endH = parts[0].toInt()
        val endM = parts[1].toInt()

        if (currentHour > endH) return true
        if (currentHour == endH && currentMinute >= endM) return true
        return false
    }

    /**
     * 解析 "yyyy-MM-dd" 日期；空白或非法输入返回 null。
     * 固定使用 [Locale.US] 解析，避免默认区域（例如佛历区域）对年份解释不一致。
     */
    fun parseIsoDate(raw: String?): Calendar? {
        if (raw.isNullOrBlank()) return null
        return try {
            val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            formatter.isLenient = false
            val date = formatter.parse(raw) ?: return null
            Calendar.getInstance().apply { time = date }
        } catch (_: Exception) {
            null
        }
    }

    /** 两个时间点是否落在同一个自然日。 */
    fun isSameDay(left: Calendar, right: Calendar): Boolean {
        return left.get(Calendar.YEAR) == right.get(Calendar.YEAR) &&
            left.get(Calendar.DAY_OF_YEAR) == right.get(Calendar.DAY_OF_YEAR)
    }
}
