package edu.sdpei.JWSystem

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

class ScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_schedule).apply {
                val date = widgetData.getString("today_date", "Today")
                val week = widgetData.getString("current_week", "")
                val jsonString = widgetData.getString("today_schedule", "[]")
                val sb = StringBuilder()
                
                try {
                    val jsonArray = JSONArray(jsonString)
                    if (jsonArray.length() == 0) {
                        sb.append("今天没有课")
                    } else {
                        for (i in 0 until jsonArray.length()) {
                            val item = jsonArray.getJSONObject(i)
                            val name = item.optString("name")
                            val start = item.optInt("startUnit")
                            val end = item.optInt("endUnit")
                            val room = item.optString("classroom")
                            
                            // Simple formatting
                            sb.append("${start}-${end}节: $name\n📍$room\n\n")
                        }
                    }
                } catch (e: Exception) {
                    sb.append("加载课表失败")
                }

                setTextViewText(R.id.tv_date, date)
                setTextViewText(R.id.tv_week, week)
                setTextViewText(R.id.tv_schedule_text, sb.toString())
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
