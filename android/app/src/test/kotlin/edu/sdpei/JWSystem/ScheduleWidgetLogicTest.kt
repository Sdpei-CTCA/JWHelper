package edu.sdpei.JWSystem

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * [ScheduleWidgetLogic] 的 JVM 单元测试（无需设备/模拟器）。
 *
 * 覆盖：`HH:mm` 解析（含非法输入）、基于 Flutter 下发 `endTime` 的下课判定边界
 * （分钟相等即已下课、缺时间信息不隐藏课程）、ISO 日期解析与同日判断。
 *
 * 运行方式：`./gradlew :app:testDebugUnitTest`
 */
class ScheduleWidgetLogicTest {

    companion object {
        @BeforeClass
        @JvmStatic
        fun pinLocaleAndTimeZone() {
            // 固定区域/时区，保证日期断言在任意开发机与 CI 环境下结果一致。
            Locale.setDefault(Locale.US)
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"))
        }
    }

    private fun calendarAt(year: Int, month: Int, day: Int, hour: Int, minute: Int): Calendar =
        Calendar.getInstance().apply {
            set(year, month, day, hour, minute, 0)
            set(Calendar.MILLISECOND, 0)
        }

    // ------------------------------------------ 时间解析与下课判定（endTime 由 Flutter 下发）

    @Test
    fun parseMinutes_parsesValidTimes() {
        assertEquals(480, ScheduleWidgetLogic.parseMinutes("08:00"))
        assertEquals(625, ScheduleWidgetLogic.parseMinutes("10:25"))
        assertEquals(0, ScheduleWidgetLogic.parseMinutes("00:00"))
        assertEquals(1439, ScheduleWidgetLogic.parseMinutes("23:59"))
    }

    @Test
    fun parseMinutes_returnsNullForNullOrBlank() {
        assertNull(ScheduleWidgetLogic.parseMinutes(null))
        assertNull(ScheduleWidgetLogic.parseMinutes(""))
        assertNull(ScheduleWidgetLogic.parseMinutes("   "))
    }

    @Test
    fun parseMinutes_returnsNullForMalformedInput() {
        assertNull(ScheduleWidgetLogic.parseMinutes("abc"))
        assertNull(ScheduleWidgetLogic.parseMinutes("8"))
        assertNull(ScheduleWidgetLogic.parseMinutes("08:00:00"))
        assertNull(ScheduleWidgetLogic.parseMinutes("24:00"))
        assertNull(ScheduleWidgetLogic.parseMinutes("08:60"))
    }

    @Test
    fun isClassPassed_falseBeforeEndTime() {
        // 济南第 3 节结束时间 10:25 → 10:24 仍未下课。
        assertFalse(
            ScheduleWidgetLogic.isClassPassed(
                "10:25", calendarAt(2026, Calendar.MARCH, 5, 10, 24)
            )
        )
    }

    @Test
    fun isClassPassed_trueAtExactEndTime() {
        // 边界：分钟相等即视为已下课。
        assertTrue(
            ScheduleWidgetLogic.isClassPassed(
                "10:25", calendarAt(2026, Calendar.MARCH, 5, 10, 25)
            )
        )
    }

    @Test
    fun isClassPassed_trueAfterEndTime() {
        assertTrue(
            ScheduleWidgetLogic.isClassPassed(
                "10:25", calendarAt(2026, Calendar.MARCH, 5, 10, 26)
            )
        )
    }

    @Test
    fun isClassPassed_falseOnMissingOrInvalidEndTime() {
        // 缺时间信息时保持课程可见（宁可多显示，不可误隐藏）。
        val now = calendarAt(2026, Calendar.MARCH, 5, 23, 59)
        assertFalse(ScheduleWidgetLogic.isClassPassed(null, now))
        assertFalse(ScheduleWidgetLogic.isClassPassed("", now))
        assertFalse(ScheduleWidgetLogic.isClassPassed("abc", now))
    }

    @Test
    fun isClassPassed_campusDifferenceReflectedByEndTime() {
        // 17:30：日照第 10 节（17:15-17:55，endTime 17:55）仍在进行；
        // 济南第 10 节无时间信息（endTime 为空）→ 同样保持可见。
        val now = calendarAt(2026, Calendar.MARCH, 5, 17, 30)
        assertFalse(ScheduleWidgetLogic.isClassPassed("17:55", now))
        assertFalse(ScheduleWidgetLogic.isClassPassed("", now))
        // 18:00：日照第 10 节已下课（endTime 17:55 → true）。
        assertTrue(
            ScheduleWidgetLogic.isClassPassed(
                "17:55", calendarAt(2026, Calendar.MARCH, 5, 18, 0)
            )
        )
    }

    // ---------------------------------------------------------- 日期解析

    @Test
    fun parseIsoDate_parsesValidDate() {
        val date = ScheduleWidgetLogic.parseIsoDate("2026-03-05")
        assertEquals(2026, date?.get(Calendar.YEAR))
        assertEquals(Calendar.MARCH, date?.get(Calendar.MONTH))
        assertEquals(5, date?.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun parseIsoDate_returnsNullForNullAndBlank() {
        assertNull(ScheduleWidgetLogic.parseIsoDate(null))
        assertNull(ScheduleWidgetLogic.parseIsoDate(""))
        assertNull(ScheduleWidgetLogic.parseIsoDate("   "))
    }

    @Test
    fun parseIsoDate_returnsNullForMalformedInput() {
        assertNull(ScheduleWidgetLogic.parseIsoDate("not-a-date"))
        assertNull(ScheduleWidgetLogic.parseIsoDate("2026/03/05"))
    }

    @Test
    fun parseIsoDate_rejectsOutOfRangeMonth() {
        // 非宽松模式（isLenient = false）必须拒绝非法月份。
        assertNull(ScheduleWidgetLogic.parseIsoDate("2026-13-01"))
    }

    // ---------------------------------------------------------- 同日判断

    @Test
    fun isSameDay_trueForSameDateDifferentTimes() {
        assertTrue(
            ScheduleWidgetLogic.isSameDay(
                calendarAt(2026, Calendar.MARCH, 5, 0, 0),
                calendarAt(2026, Calendar.MARCH, 5, 23, 59)
            )
        )
    }

    @Test
    fun isSameDay_falseForDifferentDays() {
        assertFalse(
            ScheduleWidgetLogic.isSameDay(
                calendarAt(2026, Calendar.MARCH, 5, 12, 0),
                calendarAt(2026, Calendar.MARCH, 6, 12, 0)
            )
        )
    }

    @Test
    fun isSameDay_falseForSameDayDifferentYear() {
        assertFalse(
            ScheduleWidgetLogic.isSameDay(
                calendarAt(2025, Calendar.MARCH, 5, 12, 0),
                calendarAt(2026, Calendar.MARCH, 5, 12, 0)
            )
        )
    }
}
