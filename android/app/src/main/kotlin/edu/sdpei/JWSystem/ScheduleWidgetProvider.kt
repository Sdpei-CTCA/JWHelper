package edu.sdpei.JWSystem

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.text.SimpleDateFormat

class ScheduleWidgetProvider : HomeWidgetProvider() {

    private data class ExamItem(
        val courseName: String,
        val time: String,
        val location: String,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        ScheduleWidgetDayResolver.refreshIfNeeded(context, widgetData)
        updateWidgets(context, appWidgetManager, appWidgetIds, widgetData)
        ScheduleWidgetAlarmScheduler.schedule(context, widgetData)
    }

    override fun onEnabled(context: Context) {
        val prefs = ScheduleWidgetDayResolver.prefs(context)
        ScheduleWidgetAlarmScheduler.schedule(context, prefs)
    }

    override fun onDisabled(context: Context) {
        ScheduleWidgetAlarmScheduler.cancelAll(context)
    }

    companion object {
        fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            widgetData: SharedPreferences,
        ) {
            appWidgetIds.forEach { widgetId ->
                val views = buildRemoteViews(context, widgetData)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildRemoteViews(context: Context, widgetData: SharedPreferences): RemoteViews {
            val campus = widgetData.getString("widget_campus", "济南") ?: "济南"
            return RemoteViews(context.packageName, R.layout.widget_schedule).apply {
                val displayMode = widgetData.getString("widget_display_mode", "schedule") ?: "schedule"
                val exams = parseUpcomingExams(widgetData.getString("upcoming_exams", "[]"))

                if (displayMode == "exam" && exams.isNotEmpty()) {
                    setTextViewText(R.id.tv_date_num, "考试周")
                    setTextViewText(R.id.tv_weekday, "")
                    setTextViewText(R.id.tv_cur_label, "考试科目")
                    setTextViewText(R.id.tv_next_label, "下一场")
                    bindExamColumn(this, exams.getOrNull(0), R.id.tv_cur_name, R.id.tv_cur_info, R.id.tv_cur_time, "无考试")
                    bindExamColumn(this, exams.getOrNull(1), R.id.tv_next_name, R.id.tv_next_info, R.id.tv_next_time, "无更多考试")
                    setDeepLink(this, context, "exam")
                    return@apply
                }

                val nowCal = Calendar.getInstance()
                val scheduleCal = parseIsoDate(widgetData.getString("schedule_date_iso", null)) ?: nowCal
                val date = widgetData.getString(
                    "today_date",
                    "${scheduleCal.get(Calendar.MONTH) + 1}月${scheduleCal.get(Calendar.DAY_OF_MONTH)}日",
                ) ?: "1月1日"
                val jsonString = widgetData.getString("today_schedule", "[]")
                val isDisplayToday = isSameDay(scheduleCal, nowCal)

                val dateNum = date.replace("月", ".").replace("日", "")
                val weekDayMap = arrayOf("", "周日", "周一", "周二", "周三", "周四", "周五", "周六")
                val weekDayStr = weekDayMap[scheduleCal.get(Calendar.DAY_OF_WEEK)]

                setTextViewText(R.id.tv_date_num, dateNum)
                setTextViewText(R.id.tv_weekday, weekDayStr)
                setTextViewText(R.id.tv_cur_label, "当前")
                setTextViewText(R.id.tv_next_label, "接下来")
                setDeepLink(this, context, "schedule")

                try {
                    val jsonArray = JSONArray(jsonString)
                    val allItems = ArrayList<JSONObject>()
                    for (i in 0 until jsonArray.length()) {
                        allItems.add(jsonArray.getJSONObject(i))
                    }
                    allItems.sortBy { it.optInt("startUnit") }

                    var currentIdx = -1
                    if (isDisplayToday) {
                        for (i in allItems.indices) {
                            if (!isClassPassed(allItems[i].optInt("endUnit"), campus, nowCal)) {
                                currentIdx = i
                                break
                            }
                        }
                    } else if (allItems.isNotEmpty()) {
                        currentIdx = 0
                    }

                    if (currentIdx != -1) {
                        val curr = allItems[currentIdx]
                        setTextViewText(R.id.tv_cur_name, curr.optString("name"))
                        setTextViewText(R.id.tv_cur_info, "${curr.optString("classroom")} ${curr.optString("teacher")}")
                         setTextViewText(R.id.tv_cur_time, getTimeRange(curr.optInt("startUnit"), curr.optInt("endUnit"), campus, nowCal))

                        if (currentIdx + 1 < allItems.size) {
                            val next = allItems[currentIdx + 1]
                            setTextViewText(R.id.tv_next_name, next.optString("name"))
                            setTextViewText(R.id.tv_next_info, "${next.optString("classroom")} ${next.optString("teacher")}")
                             setTextViewText(R.id.tv_next_time, getTimeRange(next.optInt("startUnit"), next.optInt("endUnit"), campus, nowCal))
                        } else {
                            setTextViewText(R.id.tv_next_name, "无课程")
                            setTextViewText(R.id.tv_next_info, "")
                            setTextViewText(R.id.tv_next_time, "")
                        }
                    } else if (allItems.isNotEmpty()) {
                        setTextViewText(R.id.tv_cur_name, "今日课程已结束")
                        setTextViewText(R.id.tv_cur_info, "")
                        setTextViewText(R.id.tv_cur_time, "")
                        setTextViewText(R.id.tv_next_name, "")
                        setTextViewText(R.id.tv_next_info, "")
                        setTextViewText(R.id.tv_next_time, "")
                    } else {
                        setTextViewText(R.id.tv_cur_name, if (isDisplayToday) "今天没有课" else "无课程")
                        setTextViewText(R.id.tv_cur_info, if (isDisplayToday) "好好休息吧" else "下一天暂无课程")
                        setTextViewText(R.id.tv_cur_time, "")
                        setTextViewText(R.id.tv_next_name, "")
                        setTextViewText(R.id.tv_next_info, "")
                        setTextViewText(R.id.tv_next_time, "")
                    }
                } catch (_: Exception) {
                    setTextViewText(R.id.tv_cur_name, "加载失败")
                }
            }
        }

        private fun getTimeRange(start: Int, end: Int, campus: String, date: Calendar): String {
            return ScheduleWidgetTimeTable.formatTimeRange(start, end, campus, date)
        }

        private fun isClassPassed(end: Int, campus: String, now: Calendar): Boolean {
            val endMinutes = ScheduleWidgetTimeTable.endMinutesForUnit(end, campus, now)
            val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            return currentMinutes >= endMinutes
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

        private fun parseUpcomingExams(jsonString: String?): List<ExamItem> {
            if (jsonString.isNullOrBlank()) return emptyList()
            return try {
                val jsonArray = JSONArray(jsonString)
                val result = ArrayList<ExamItem>()
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    result.add(
                        ExamItem(
                            courseName = obj.optString("courseName"),
                            time = obj.optString("time"),
                            location = obj.optString("location"),
                        ),
                    )
                }
                result
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun bindExamColumn(
            views: RemoteViews,
            exam: ExamItem?,
            nameId: Int,
            infoId: Int,
            timeId: Int,
            emptyName: String,
        ) {
            if (exam != null) {
                views.setTextViewText(nameId, exam.courseName)
                views.setTextViewText(infoId, exam.location)
                views.setTextViewText(timeId, exam.time)
            } else {
                views.setTextViewText(nameId, emptyName)
                views.setTextViewText(infoId, "")
                views.setTextViewText(timeId, "")
            }
        }

        private fun setDeepLink(views: RemoteViews, context: Context, host: String) {
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("jwhelper://$host?homeWidget=1"),
            )
            views.setOnClickPendingIntent(android.R.id.background, pendingIntent)
        }
    }
}
