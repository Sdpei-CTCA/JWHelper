package edu.sdpei.JWSystem

import android.appwidget.AppWidgetManager
import android.content.Context
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
                val date = widgetData.getString("today_date", "1月1日") ?: "1月1日"
                val week = widgetData.getString("current_week", "") ?: "" // No longer used in main layout, but maybe debug
                val jsonString = widgetData.getString("today_schedule", "[]")
                
                // Parse Date "X月X日" -> "X.X"
                val dateNum = date.replace("月", ".").replace("日", "")
                
                // Get Weekday (Android Calendar) for "周X"
                // Actually Flutter passes "today_date" static string.
                // It's better to compute weekday here.
                val cal = Calendar.getInstance()
                val weekDayMap = arrayOf("", "周日", "周一", "周二", "周三", "周四", "周五", "周六")
                val weekDayStr = weekDayMap[cal.get(Calendar.DAY_OF_WEEK)]

                setTextViewText(R.id.tv_date_num, dateNum)
                setTextViewText(R.id.tv_weekday, weekDayStr)

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
                    for (i in allItems.indices) {
                         if (!isClassPassed(allItems[i].optInt("endUnit"))) {
                             currentIdx = i
                             break
                         }
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
                         setTextViewText(R.id.tv_cur_name, "今天没有课")
                         setTextViewText(R.id.tv_cur_info, "好好休息吧")
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
