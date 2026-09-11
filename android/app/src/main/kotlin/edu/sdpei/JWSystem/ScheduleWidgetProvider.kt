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

    // 时间表与时间判断逻辑已抽取到 ScheduleWidgetLogic（纯 JVM 逻辑，便于单元测试）。
    // 本 Provider 只保留：读取小组件数据、解析课程 JSON、渲染 RemoteViews。

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_schedule).apply {
                val nowCal = Calendar.getInstance()
                val scheduleCal = ScheduleWidgetLogic.parseIsoDate(widgetData.getString("schedule_date_iso", null)) ?: nowCal
                val date = widgetData.getString(
                    "today_date",
                    "${scheduleCal.get(Calendar.MONTH) + 1}月${scheduleCal.get(Calendar.DAY_OF_MONTH)}日"
                ) ?: "1月1日"
                val week = widgetData.getString("current_week", "") ?: "" // No longer used in main layout, but maybe debug
                val jsonString = widgetData.getString("today_schedule", "[]")
                val isDisplayToday = ScheduleWidgetLogic.isSameDay(scheduleCal, nowCal)
                // Campus is written by the Flutter side; default to Jinan when missing.
                val campus = widgetData.getString("campus", "济南") ?: "济南"
                
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
                             if (!ScheduleWidgetLogic.isClassPassed(allItems[i].optInt("endUnit"), campus)) {
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
                         setTextViewText(R.id.tv_cur_time, ScheduleWidgetLogic.getTimeRange(curr.optInt("startUnit"), curr.optInt("endUnit"), campus))
                         
                         // Next Item
                         if (currentIdx + 1 < allItems.size) {
                             val next = allItems[currentIdx + 1]
                             setTextViewText(R.id.tv_next_name, next.optString("name"))
                             setTextViewText(R.id.tv_next_info, "${next.optString("classroom")} ${next.optString("teacher")}")
                             setTextViewText(R.id.tv_next_time, ScheduleWidgetLogic.getTimeRange(next.optInt("startUnit"), next.optInt("endUnit"), campus))
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
