import WidgetKit
import SwiftUI

// Time helper
struct TimeHelper {
    static func getTimeRange(start: Int, end: Int, campus: String, date: Date) -> String {
        WidgetTimeTable.formatTimeRange(
            startPeriod: start,
            endPeriod: end,
            campus: campus,
            date: date
        )
    }
}

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(
            date: Date(),
            items: [
                ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
                ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
            ],
            exams: [],
            displayMode: "schedule",
            lastUpdated: Date(),
            debugEnabled: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> ()) {
        let entry = ScheduleEntry(
            date: Date(),
            items: [
                ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
                ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
            ],
            exams: [],
            displayMode: "schedule",
            lastUpdated: Date(),
            debugEnabled: false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> ()) {
        WidgetStore.refreshTodayScheduleIfNeeded()

        let displayMode = WidgetStore.displayMode()
        let exams = WidgetStore.upcomingExams()
        let campus = WidgetStore.campus()
        let now = Date()
        let displayDate = WidgetStore.scheduleDate() ?? now
        let allItems = WidgetStore.scheduleItems()
        let lastUpdated = WidgetStore.date(WidgetKeys.lastUpdated)
        let debugEnabled = WidgetStore.debugEnabled()

        if displayMode == "exam" {
            let entry = ScheduleEntry(
                date: now,
                items: [],
                exams: exams,
                displayMode: displayMode,
                lastUpdated: lastUpdated,
                debugEnabled: debugEnabled
            )
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(1800))))
            return
        }

        let refreshDates = WidgetRefreshTimes.upcomingRefreshDates(
            items: allItems,
            campus: campus,
            now: now
        )

        let entries: [ScheduleEntry] = refreshDates.map { entryDate in
            let resolved = ScheduleTimelineResolver.resolve(
                refreshDate: entryDate,
                storedItems: allItems,
                displayDate: displayDate,
                campus: campus
            )
            return ScheduleEntry(
                date: resolved.headerDate,
                items: resolved.items,
                exams: exams,
                displayMode: displayMode,
                lastUpdated: lastUpdated,
                debugEnabled: debugEnabled
            )
        }

        let policyDate = refreshDates.last?.addingTimeInterval(60) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: entries, policy: .after(policyDate)))
    }
}

struct ScheduleItemData: Codable {
    let name: String
    let teacher: String
    let classroom: String
    let dayIndex: Int
    let startUnit: Int
    let endUnit: Int
    let weekStart: Int
    let weekEnd: Int

    init(
        name: String,
        teacher: String,
        classroom: String,
        dayIndex: Int = 0,
        startUnit: Int,
        endUnit: Int,
        weekStart: Int = 0,
        weekEnd: Int = 0
    ) {
        self.name = name
        self.teacher = teacher
        self.classroom = classroom
        self.dayIndex = dayIndex
        self.startUnit = startUnit
        self.endUnit = endUnit
        self.weekStart = weekStart
        self.weekEnd = weekEnd
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        teacher = try container.decode(String.self, forKey: .teacher)
        classroom = try container.decode(String.self, forKey: .classroom)
        dayIndex = try container.decodeIfPresent(Int.self, forKey: .dayIndex) ?? 0
        startUnit = try container.decodeIfPresent(Int.self, forKey: .startUnit) ?? 0
        endUnit = try container.decodeIfPresent(Int.self, forKey: .endUnit) ?? 0
        weekStart = try container.decodeIfPresent(Int.self, forKey: .weekStart) ?? 0
        weekEnd = try container.decodeIfPresent(Int.self, forKey: .weekEnd) ?? 0
    }
}

struct ExamItemData: Codable {
    let courseName: String
    let time: String
    let location: String
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let items: [ScheduleItemData]
    let exams: [ExamItemData]
    let displayMode: String
    let lastUpdated: Date?
    let debugEnabled: Bool
}

struct ScheduleWidgetEntryView: View {
    var entry: ScheduleProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if entry.displayMode == "exam" && !entry.exams.isEmpty {
                ExamTwoColumn(exams: entry.exams)
            } else if entry.items.isEmpty {
                emptyState
            } else {
                ScheduleTwoColumn(
                    items: entry.items,
                    campus: WidgetStore.campus(),
                    displayDate: entry.date
                )
            }

            if entry.debugEnabled {
                DebugBlock(lines: [
                    "Debug: ON",
                    "AppGroup: \(WidgetAppGroup.id)",
                    "Items: \(entry.items.count)",
                    "Updated: \(entry.lastUpdated != nil ? "yes" : "no")"
                ])
            }

            Spacer(minLength: 0)
        }
        .padding()
        .widgetBackground(WidgetColors.background)
        .widgetURL(URL(string: entry.displayMode == "exam" ? "jwhelper://exam?homeWidget=1" : "jwhelper://schedule?homeWidget=1"))
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            if entry.displayMode == "exam" {
                Text("考试周")
                    .font(.system(size: 18, weight: .bold))
            } else {
                Text(formatDate(entry.date))
                    .font(.system(size: 18, weight: .bold))
                Text(Config.weekday(entry.date))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(WidgetColors.accent)
            }
            Spacer()
            if let time = entry.lastUpdated {
                Text("更新 \(timeString(time))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日无课")
                .font(.headline)
            Text("去 APP 同步后自动刷新")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: date)
    }

    func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

struct ScheduleRow: View {
    let item: ScheduleItemData
    let index: Int
    let campus: String
    let displayDate: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(index == 0 ? WidgetColors.accent : WidgetColors.primary)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                Text("\(item.classroom) · \(item.teacher)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(TimeHelper.getTimeRange(
                    start: item.startUnit,
                    end: item.endUnit,
                    campus: campus,
                    date: displayDate
                ))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(WidgetColors.cardBackground)
        .cornerRadius(10)
    }
}

struct ExamTwoColumn: View {
    let exams: [ExamItemData]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ExamColumn(title: "考试科目", exam: exams.first, accent: WidgetColors.accent)
            Divider()
                .frame(maxHeight: 90)
            ExamColumn(
                title: "下一场",
                exam: exams.count > 1 ? exams[1] : nil,
                accent: WidgetColors.primary,
                emptyText: "无更多考试"
            )
        }
    }
}

struct ExamColumn: View {
    let title: String
    let exam: ExamItemData?
    let accent: Color
    var emptyText: String = "无考试"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            if let exam {
                HStack(alignment: .top, spacing: 8) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(exam.courseName)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Text(exam.location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(exam.time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(WidgetColors.cardBackground)
                .cornerRadius(10)
            } else {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ScheduleTwoColumn: View {
    let items: [ScheduleItemData]
    let campus: String
    let displayDate: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ScheduleColumn(
                title: "第一节",
                item: items.first,
                accent: WidgetColors.accent,
                campus: campus,
                displayDate: displayDate
            )

            Divider()
                .frame(maxHeight: 90)

            ScheduleColumn(
                title: "第二节",
                item: items.count > 1 ? items[1] : nil,
                accent: WidgetColors.primary,
                campus: campus,
                displayDate: displayDate
            )
        }
    }
}

struct ScheduleColumn: View {
    let title: String
    let item: ScheduleItemData?
    let accent: Color
    let campus: String
    let displayDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            if let item {
                HStack(alignment: .top, spacing: 8) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)

                        Text("\(item.classroom) · \(item.teacher)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Text(TimeHelper.getTimeRange(
                            start: item.startUnit,
                            end: item.endUnit,
                            campus: campus,
                            date: displayDate
                        ))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(WidgetColors.cardBackground)
                .cornerRadius(10)
            } else {
                Text("无课程")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ScheduleFilter {
    static func filterUpcoming(
        items: [ScheduleItemData],
        at date: Date,
        campus: String
    ) -> [ScheduleItemData] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let nowMinutes = hour * 60 + minute

        return items.filter { item in
            let endMinutes = WidgetTimeTable.endMinutesForUnit(item.endUnit, campus: campus, date: date)
            return endMinutes > nowMinutes
        }
    }
}

enum ScheduleTimelineResolver {
    static func resolve(
        refreshDate: Date,
        storedItems: [ScheduleItemData],
        displayDate: Date,
        campus: String
    ) -> (headerDate: Date, items: [ScheduleItemData]) {
        let calendar = Calendar.current
        let weekItems = WidgetStore.weekScheduleItems()
        let savedDate = WidgetStore.scheduleDate() ?? displayDate

        let dayItems: [ScheduleItemData]
        let headerDate: Date

        if calendar.isDate(refreshDate, inSameDayAs: displayDate) {
            dayItems = storedItems
            headerDate = displayDate
        } else if !weekItems.isEmpty {
            let resolved = WidgetDayResolver.resolveTodayFromCache(
                allItems: weekItems,
                storedWeek: WidgetStore.currentWeekValue(),
                savedDate: savedDate,
                now: refreshDate
            )
            dayItems = resolved.displayItems
            headerDate = resolved.displayDate
        } else {
            dayItems = storedItems
            headerDate = displayDate
        }

        let filtered = ScheduleFilter.filterUpcoming(
            items: dayItems,
            at: refreshDate,
            campus: campus
        )
        let items = filtered.isEmpty && !dayItems.isEmpty ? [] : filtered
        return (headerDate, items)
    }
}

struct Config {
    static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日课表")
        .description("展示今天的课程安排")
        .supportedFamilies([.systemMedium])
    }
}
