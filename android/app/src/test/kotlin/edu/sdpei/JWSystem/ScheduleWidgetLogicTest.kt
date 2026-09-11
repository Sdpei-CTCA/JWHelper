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
 * 覆盖：校区时间表差异、时间区间拼接、下课判定边界（分钟相等）、
 * ISO 日期解析与同日判断。
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

    // ---------------------------------------------------------------- 时间表

    @Test
    fun timeMapFor_rizhaoHasPeriod10() {
        assertEquals("17:15-17:55", ScheduleWidgetLogic.timeMapFor("日照")[10])
    }

    @Test
    fun timeMapFor_jinanHasNoPeriod10() {
        assertNull(ScheduleWidgetLogic.timeMapFor("济南")[10])
    }

    @Test
    fun timeMapFor_unknownCampusFallsBackToJinan() {
        assertEquals(
            ScheduleWidgetLogic.timeMapFor("济南"),
            ScheduleWidgetLogic.timeMapFor("unknown")
        )
    }

    @Test
    fun timeMapFor_periods1To9AreIdenticalOnBothCampuses() {
        for (period in 1..9) {
            assertEquals(
                "period $period should match on both campuses",
                ScheduleWidgetLogic.timeMapFor("济南")[period],
                ScheduleWidgetLogic.timeMapFor("日照")[period]
            )
        }
    }

    // -------------------------------------------------------------- 时间区间

    @Test
    fun getTimeRange_joinsStartAndEndOfRange() {
        // 跨节次课程：取第 1 节的开始时间与第 2 节的结束时间。
        assertEquals("08:00 - 09:25", ScheduleWidgetLogic.getTimeRange(1, 2, "济南"))
        // 单节次课程：同一节次的开始与结束时间。
        assertEquals("09:45 - 10:25", ScheduleWidgetLogic.getTimeRange(3, 3, "济南"))
    }

    @Test
    fun getTimeRange_rizhaoLatePeriods() {
        // 日照校区第 10-11 节：17:15 开始，19:40 结束（济南校区第 10 节不存在）。
        assertEquals("17:15 - 19:40", ScheduleWidgetLogic.getTimeRange(10, 11, "日照"))
        // 日照校区第 11-12 节。
        assertEquals("19:00 - 20:25", ScheduleWidgetLogic.getTimeRange(11, 12, "日照"))
    }

    @Test
    fun getTimeRange_emptyWhenPeriodMissingOnCampus() {
        assertEquals("", ScheduleWidgetLogic.getTimeRange(9, 10, "济南"))
    }

    // ---------------------------------------------------------- 是否已下课

    @Test
    fun isClassPassed_falseBeforeEndTime() {
        // 第 3 节结束时间为 10:25（两校区一致）。
        assertFalse(
            ScheduleWidgetLogic.isClassPassed(
                3, "济南", calendarAt(2026, Calendar.MARCH, 5, 10, 24)
            )
        )
    }

    @Test
    fun isClassPassed_trueAtExactEndTime() {
        // 边界：分钟相等即视为已下课。
        assertTrue(
            ScheduleWidgetLogic.isClassPassed(
                3, "济南", calendarAt(2026, Calendar.MARCH, 5, 10, 25)
            )
        )
    }

    @Test
    fun isClassPassed_trueAfterEndTime() {
        assertTrue(
            ScheduleWidgetLogic.isClassPassed(
                3, "济南", calendarAt(2026, Calendar.MARCH, 5, 10, 26)
            )
        )
    }

    @Test
    fun isClassPassed_trueWhenLaterHour() {
        assertTrue(
            ScheduleWidgetLogic.isClassPassed(
                5, "济南", calendarAt(2026, Calendar.MARCH, 5, 12, 0)
            )
        )
    }

    @Test
    fun isClassPassed_trueForPeriodMissingOnCampus() {
        // 济南校区没有第 10 节，因此按"已下课"处理。
        assertTrue(
            ScheduleWidgetLogic.isClassPassed(
                10, "济南", calendarAt(2026, Calendar.MARCH, 5, 8, 0)
            )
        )
    }

    @Test
    fun isClassPassed_campusDifferenceAtPeriod10() {
        // 17:30 时：日照第 10 节（17:15-17:55）仍在进行；济南无第 10 节，视为已下课。
        val now = calendarAt(2026, Calendar.MARCH, 5, 17, 30)
        assertFalse(ScheduleWidgetLogic.isClassPassed(10, "日照", now))
        assertTrue(ScheduleWidgetLogic.isClassPassed(10, "济南", now))
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
