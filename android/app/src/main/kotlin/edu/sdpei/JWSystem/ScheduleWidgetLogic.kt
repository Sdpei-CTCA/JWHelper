package edu.sdpei.JWSystem

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * 桌面课程表小组件使用的纯时间逻辑。
 *
 * 从 [ScheduleWidgetProvider] 中抽取，不依赖任何 Android 框架类，
 * 因此可以直接在 JVM 单元测试中验证（见 `src/test` 下的 ScheduleWidgetLogicTest）。
 *
 * 作息时间表由 Flutter 侧（`lib/core/constants/class_schedule.dart`）统一维护，
 * 解析结果（`timeRange` / `endTime` 字段）随 `today_schedule` payload 一并下发；
 * 原生端不再保留本地时间表，保证 Android / iOS / 应用内三端时间边界一致。
 */
internal object ScheduleWidgetLogic {

    /**
     * 判断以 [endTime]（`HH:mm`）结束的课程在 [now] 时刻是否已经下课。
     *
     * 缺少或无法解析 [endTime] 时返回 `false`：宁可让课程多显示一会儿，
     * 也不要把课程误判为“已上完”而将其隐藏（例如旧缓存或数据异常）。
     */
    fun isClassPassed(endTime: String?, now: Calendar = Calendar.getInstance()): Boolean {
        val endMinutes = parseMinutes(endTime) ?: return false
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        return nowMinutes >= endMinutes
    }

    /**
     * 将 `HH:mm` 解析为“零点起的分钟数”；输入为空或格式非法时返回 null。
     * 仅接受 24 小时制，小时 0..23、分钟 0..59。
     */
    fun parseMinutes(time: String?): Int? {
        val parts = time?.trim()?.split(":") ?: return null
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return hour * 60 + minute
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
