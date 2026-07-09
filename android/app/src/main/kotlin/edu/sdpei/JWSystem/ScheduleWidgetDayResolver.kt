package edu.sdpei.JWSystem

import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object ScheduleWidgetDayResolver {
    private val isoFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).apply {
        isLenient = false
    }

    fun refreshIfNeeded(context: Context, prefs: SharedPreferences): Boolean {
        if ((prefs.getString("widget_display_mode", "schedule") ?: "schedule") != "schedule") {
            return false
        }

        val now = Calendar.getInstance()
        val savedDate = parseIsoDate(prefs.getString("schedule_date_iso", null)) ?: return false
        if (isSameDay(savedDate, now)) {
            return false
        }

        val weekJson = prefs.getString("week_schedule", null) ?: return false
        val anchorWeek = prefs.getString("widget_current_week", "0")?.toIntOrNull() ?: 0
        val anchorDate = parseIsoDate(prefs.getString("widget_week_anchor_date", null)) ?: savedDate
        val startDay = prefs.getString("schedule_start_day", null)
        val resolved = resolveTodayFromCache(
            weekJson = weekJson,
            anchorWeek = anchorWeek,
            anchorDate = anchorDate,
            startDay = startDay,
            now = now,
        ) ?: return false

        val editor = prefs.edit()
        val array = JSONArray()
        resolved.items.forEach { array.put(it) }
        editor.putString("today_schedule", array.toString())
        editor.putString(
            "today_date",
            "${resolved.displayDate.get(Calendar.MONTH) + 1}月${resolved.displayDate.get(Calendar.DAY_OF_MONTH)}日",
        )
        editor.putString("schedule_date_iso", isoFormatter.format(resolved.displayDate.time))
        editor.putString("widget_current_week", resolved.week.toString())
        editor.putString("current_week", "第${resolved.week}周")
        editor.putString("widget_week_anchor_date", isoFormatter.format(resolved.displayDate.time))
        editor.apply()
        return true
    }

    private data class ResolvedDay(
        val displayDate: Calendar,
        val week: Int,
        val items: List<JSONObject>,
    )

    private fun resolveTodayFromCache(
        weekJson: String,
        anchorWeek: Int,
        anchorDate: Calendar,
        startDay: String?,
        now: Calendar,
    ): ResolvedDay? {
        val allItems = parseItems(weekJson)
        if (allItems.isEmpty()) return null

        val week = resolveWeek(
            targetDate = now,
            anchorWeek = anchorWeek,
            anchorDate = anchorDate,
            startDay = startDay,
        )
        val dayIndex = calendarToDayIndex(now)
        val items = itemsForDay(allItems, dayIndex, week)
        val displayDate = now.clone() as Calendar
        displayDate.set(Calendar.HOUR_OF_DAY, 0)
        displayDate.set(Calendar.MINUTE, 0)
        displayDate.set(Calendar.SECOND, 0)
        displayDate.set(Calendar.MILLISECOND, 0)
        return ResolvedDay(displayDate = displayDate, week = week, items = items)
    }

    private fun parseItems(weekJson: String): List<JSONObject> {
        return try {
            val array = JSONArray(weekJson)
            buildList {
                for (i in 0 until array.length()) {
                    add(array.getJSONObject(i))
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun itemsForDay(
        allItems: List<JSONObject>,
        dayIndex: Int,
        currentWeek: Int,
    ): List<JSONObject> {
        return allItems.filter { item ->
            item.optInt("dayIndex") == dayIndex && isInCurrentWeek(item, currentWeek)
        }.sortedBy { it.optInt("startUnit") }
    }

    private fun isInCurrentWeek(item: JSONObject, currentWeek: Int): Boolean {
        if (currentWeek <= 0) return true
        val weekStart = item.optInt("weekStart", 0)
        val weekEnd = item.optInt("weekEnd", 0)
        if (weekStart > 0 && weekEnd > 0) {
            return currentWeek in weekStart..weekEnd
        }
        return true
    }

    private fun resolveWeek(
        targetDate: Calendar,
        anchorWeek: Int,
        anchorDate: Calendar,
        startDay: String?,
    ): Int {
        weekFromStartDay(startDay, targetDate)?.let { return it }
        return resolveWeekForDate(anchorWeek, anchorDate, targetDate)
    }

    private fun weekFromStartDay(startDay: String?, targetDate: Calendar): Int? {
        if (startDay.isNullOrBlank()) return null
        return try {
            val start = isoFormatter.parse(startDay) ?: return null
            val startCal = Calendar.getInstance().apply { time = start }
            normalizeDay(startCal)
            val targetDay = targetDate.clone() as Calendar
            normalizeDay(targetDay)
            val diffDays = ((targetDay.timeInMillis - startCal.timeInMillis) / (24 * 60 * 60 * 1000)).toInt()
            if (diffDays < 0) 1 else diffDays / 7 + 1
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveWeekForDate(anchorWeek: Int, anchorDate: Calendar, targetDate: Calendar): Int {
        if (anchorWeek <= 0) return anchorWeek
        if (isSameDay(anchorDate, targetDate)) return anchorWeek

        val anchorDay = anchorDate.clone() as Calendar
        normalizeDay(anchorDay)
        val targetDay = targetDate.clone() as Calendar
        normalizeDay(targetDay)
        if (!targetDay.after(anchorDay)) return anchorWeek

        val daysBetween = ((targetDay.timeInMillis - anchorDay.timeInMillis) / (24 * 60 * 60 * 1000)).toInt()
        return anchorWeek + daysBetween / 7
    }

    private fun calendarToDayIndex(cal: Calendar): Int {
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SUNDAY -> 6
            else -> cal.get(Calendar.DAY_OF_WEEK) - 2
        }
    }

    private fun parseIsoDate(raw: String?): Calendar? {
        if (raw.isNullOrBlank()) return null
        return try {
            val date = isoFormatter.parse(raw) ?: return null
            Calendar.getInstance().apply { time = date }
        } catch (_: Exception) {
            null
        }
    }

    private fun isSameDay(left: Calendar, right: Calendar): Boolean {
        return left.get(Calendar.YEAR) == right.get(Calendar.YEAR) &&
            left.get(Calendar.DAY_OF_YEAR) == right.get(Calendar.DAY_OF_YEAR)
    }

    private fun normalizeDay(cal: Calendar) {
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
    }

    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)
}
