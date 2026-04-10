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
import java.util.Locale
import java.text.SimpleDateFormat

class ScheduleWidgetProvider : HomeWidgetProvider() {

    // Simple time mapping for periods 1-10
    private val timeMap = mapOf(
        1 to "08:00-08:45",
        2 to "08:45-09:30",
        3 to "10:00-10:45",
        4 to "10:45-11:30",
        5 to "13:30-14:15",
        6 to "14:15-15:00",
        7 to "15:30-16:15",
        8 to "16:15-17:00",
        9 to "19:00-19:45",
        10 to "19:45-20:30"
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

    private fun parseIsoDate(raw: String?): Calendar? {
        if (raw.isNullOrBlank()) return null
        return try {
            val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            formatter.isLenient = false
            val date = formatter.parse(raw) ?: return null
            Calendar.getInstance().apply { time = date }
        } catch (_: Exception) {
            null
        }
    }

    private fun isSameDay(left: Calendar, right: Calendar): Boolean {
        return left.get(Calendar.YEAR) == right.get(Calendar.YEAR) &&
            left.get(Calendar.DAY_OF_YEAR) == right.get(Calendar.DAY_OF_YEAR)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_schedule).apply {
                val nowCal = Calendar.getInstance()
                val scheduleCal = parseIsoDate(widgetData.getString("schedule_date_iso", null)) ?: nowCal
                val date = widgetData.getString(
                    "today_date",
                    "${scheduleCal.get(Calendar.MONTH) + 1}月${scheduleCal.get(Calendar.DAY_OF_MONTH)}日"
                ) ?: "1月1日"
                val week = widgetData.getString("current_week", "") ?: "" // No longer used in main layout, but maybe debug
                val jsonString = widgetData.getString("today_schedule", "[]")
                val isDisplayToday = isSameDay(scheduleCal, nowCal)
                
                // Parse Date "X月X日" -> "X.X"
                val dateNum = date.replace("月", ".").replace("日", "")
                
                // Get Weekday (Android Calendar) for "周X"
                // Actually Flutter passes "today_date" static string.
                // It's better to compute weekday here.
                val weekDayMap = arrayOf("", "周日", "周一", "周二", "周三", "周四", "周五", "周六")
                val weekDayStr = weekDayMap[scheduleCal.get(Calendar.DAY_OF_WEEK)]

                setTextViewText(R.id.tv_date_num, dateNum)
                setTextViewText(R.id.tv_weekday, weekDayStr)

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
                    val jsonArray = JSONArray(jsonString)
                    val allItems = ArrayList<JSONObject>()
                    for (i in 0 until jsonArray.length()) {
                        allItems.add(jsonArray.getJSONObject(i))
                    }

                    // Sort by startUnit just in case
                    allItems.sortBy { it.optInt("startUnit") }
                    
                    // Filter: Find first item that is NOT passed
                    var currentIdx = -1
                    if (isDisplayToday) {
                        for (i in allItems.indices) {
                             if (!isClassPassed(allItems[i].optInt("endUnit"))) {
                                 currentIdx = i
                                 break
                             }
                        }
                    } else if (allItems.isNotEmpty()) {
                        currentIdx = 0
                    }
                    
                    // If all passed, maybe show nothing or just the last one?
                    // Design: Current (Left), Next (Right)
                    
                    // Current Item
                    if (currentIdx != -1) {
                         val curr = allItems[currentIdx]
                         setTextViewText(R.id.tv_cur_name, curr.optString("name"))
                         setTextViewText(R.id.tv_cur_info, "${curr.optString("classroom")} ${curr.optString("teacher")}")
                         setTextViewText(R.id.tv_cur_time, getTimeRange(curr.optInt("startUnit"), curr.optInt("endUnit")))
                         
                         // Next Item
                         if (currentIdx + 1 < allItems.size) {
                             val next = allItems[currentIdx + 1]
                             setTextViewText(R.id.tv_next_name, next.optString("name"))
                             setTextViewText(R.id.tv_next_info, "${next.optString("classroom")} ${next.optString("teacher")}")
                             setTextViewText(R.id.tv_next_time, getTimeRange(next.optInt("startUnit"), next.optInt("endUnit")))
                         } else {
                             setTextViewText(R.id.tv_next_name, "无课程")
                             setTextViewText(R.id.tv_next_info, "")
                             setTextViewText(R.id.tv_next_time, "")
                         }
                    } else if (allItems.isNotEmpty()) {
                        // All classes passed for today
                        setTextViewText(R.id.tv_cur_name, "今日课程已结束")
                        setTextViewText(R.id.tv_cur_info, "")
                        setTextViewText(R.id.tv_cur_time, "")
                        
                        setTextViewText(R.id.tv_next_name, "")
                        setTextViewText(R.id.tv_next_info, "")
                        setTextViewText(R.id.tv_next_time, "")
                    } else {
                        // No classes today
                         setTextViewText(R.id.tv_cur_name, if (isDisplayToday) "今天没有课" else "无课程")
                         setTextViewText(R.id.tv_cur_info, if (isDisplayToday) "好好休息吧" else "下一天暂无课程")
                         setTextViewText(R.id.tv_cur_time, "")
                         
                         setTextViewText(R.id.tv_next_name, "")
                         setTextViewText(R.id.tv_next_info, "")
                         setTextViewText(R.id.tv_next_time, "")
                    }

                } catch (e: Exception) {
                    setTextViewText(R.id.tv_cur_name, "加载失败")
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
