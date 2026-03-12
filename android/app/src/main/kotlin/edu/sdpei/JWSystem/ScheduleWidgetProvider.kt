package edu.sdpei.JWSystem

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.net.Uri
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class ScheduleWidgetProvider : HomeWidgetProvider() {

    // Simple time mapping for periods 1-12
    private val timeMap = mapOf(
        1 to "08:00-08:45",
        2 to "08:55-09:40",
        3 to "10:00-10:45",
        4 to "10:55-11:40",
        5 to "13:30-14:15",
        6 to "14:25-15:10",
        7 to "15:20-16:05",
        8 to "16:25-17:10",
        9 to "17:20-18:05",
        10 to "18:30-19:15",
        11 to "19:25-20:10",
        12 to "20:20-21:05"
    )

    // Helper to get time range string
    private fun getTimeRange(start: Int, end: Int): String {
        val startStr = timeMap[start]?.split("-")?.get(0) ?: "00:00"
        val endStr = timeMap[end]?.split("-")?.get(1) ?: "00:00"
        return "$startStr - $endStr"
    }
    
    // Helper to check if a class is "passed" based on current time
    // Returning true if the class end time is before now
    private fun isClassPassed(end: Int): Boolean {
        val now = Calendar.getInstance()
        val currentHour = now.get(Calendar.HOUR_OF_DAY)
        val currentMinute = now.get(Calendar.MINUTE)
        val endStr = timeMap[end]?.split("-")?.get(1) ?: return true
        val parts = endStr.split(":")
        if (parts.size != 2) return true
        
        val endH = parts[0].toInt()
        val endM = parts[1].toInt()
        
        if (currentHour > endH) return true
        if (currentHour == endH && currentMinute >= endM) return true
        return false
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_schedule).apply {
                val todayJsonString = widgetData.getString("today_schedule", "[]")
                val tomorrowJsonString = widgetData.getString("tomorrow_schedule", "[]")

                // Click Intent
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("jwhelper://schedule")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(android.R.id.background, pendingIntent)

                try {
                    val todayArray = JSONArray(todayJsonString)
                    val allTodayItems = ArrayList<JSONObject>()
                    for (i in 0 until todayArray.length()) {
                        allTodayItems.add(todayArray.getJSONObject(i))
                    }
                    allTodayItems.sortBy { it.optInt("startUnit") }

                    // Find first today's item that is NOT passed
                    val currentIdx = allTodayItems.indexOfFirst { !isClassPassed(it.optInt("endUnit")) }

                    val cal = Calendar.getInstance()
                    val weekDayMap = arrayOf("", "周日", "周一", "周二", "周三", "周四", "周五", "周六")

                    if (currentIdx != -1) {
                        // Show today's schedule (current + next class)
                        val dateNum = "${cal.get(Calendar.MONTH) + 1}.${cal.get(Calendar.DAY_OF_MONTH)}"
                        val weekDayStr = weekDayMap[cal.get(Calendar.DAY_OF_WEEK)]
                        setTextViewText(R.id.tv_date_num, dateNum)
                        setTextViewText(R.id.tv_weekday, weekDayStr)

                        val curr = allTodayItems[currentIdx]
                        setTextViewText(R.id.tv_cur_name, curr.optString("name"))
                        setTextViewText(R.id.tv_cur_info, "${curr.optString("classroom")} ${curr.optString("teacher")}")
                        setTextViewText(R.id.tv_cur_time, getTimeRange(curr.optInt("startUnit"), curr.optInt("endUnit")))

                        if (currentIdx + 1 < allTodayItems.size) {
                            val next = allTodayItems[currentIdx + 1]
                            setTextViewText(R.id.tv_next_name, next.optString("name"))
                            setTextViewText(R.id.tv_next_info, "${next.optString("classroom")} ${next.optString("teacher")}")
                            setTextViewText(R.id.tv_next_time, getTimeRange(next.optInt("startUnit"), next.optInt("endUnit")))
                        } else {
                            setTextViewText(R.id.tv_next_name, "无课程")
                            setTextViewText(R.id.tv_next_info, "")
                            setTextViewText(R.id.tv_next_time, "")
                        }
                    } else {
                        // All today's classes are done (or no classes today) — show tomorrow's schedule
                        val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, 1) }
                        val tomorrowDateNum = "${tomorrowCal.get(Calendar.MONTH) + 1}.${tomorrowCal.get(Calendar.DAY_OF_MONTH)}"
                        val tomorrowWeekDayStr = weekDayMap[tomorrowCal.get(Calendar.DAY_OF_WEEK)]
                        setTextViewText(R.id.tv_date_num, tomorrowDateNum)
                        setTextViewText(R.id.tv_weekday, "$tomorrowWeekDayStr 明日")

                        val tomorrowArray = JSONArray(tomorrowJsonString)
                        val tomorrowItems = ArrayList<JSONObject>()
                        for (i in 0 until tomorrowArray.length()) {
                            tomorrowItems.add(tomorrowArray.getJSONObject(i))
                        }
                        tomorrowItems.sortBy { it.optInt("startUnit") }

                        if (tomorrowItems.isNotEmpty()) {
                            val first = tomorrowItems[0]
                            setTextViewText(R.id.tv_cur_name, first.optString("name"))
                            setTextViewText(R.id.tv_cur_info, "${first.optString("classroom")} ${first.optString("teacher")}")
                            setTextViewText(R.id.tv_cur_time, getTimeRange(first.optInt("startUnit"), first.optInt("endUnit")))

                            if (tomorrowItems.size > 1) {
                                val second = tomorrowItems[1]
                                setTextViewText(R.id.tv_next_name, second.optString("name"))
                                setTextViewText(R.id.tv_next_info, "${second.optString("classroom")} ${second.optString("teacher")}")
                                setTextViewText(R.id.tv_next_time, getTimeRange(second.optInt("startUnit"), second.optInt("endUnit")))
                            } else {
                                setTextViewText(R.id.tv_next_name, "无课程")
                                setTextViewText(R.id.tv_next_info, "")
                                setTextViewText(R.id.tv_next_time, "")
                            }
                        } else {
                            // Tomorrow also has no classes
                            setTextViewText(R.id.tv_cur_name, "明日无课")
                            setTextViewText(R.id.tv_cur_info, "好好休息吧")
                            setTextViewText(R.id.tv_cur_time, "")
                            setTextViewText(R.id.tv_next_name, "")
                            setTextViewText(R.id.tv_next_info, "")
                            setTextViewText(R.id.tv_next_time, "")
                        }
                    }

                } catch (e: Exception) {
                    setTextViewText(R.id.tv_cur_name, "加载失败")
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
