import WidgetKit
import SwiftUI

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
        ScheduleEntry(date: Date(), items: [
            ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
            ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> ()) {
        let entry = ScheduleEntry(date: Date(), items: [
            ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
            ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
        ])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.jwhelper.shared")
        let jsonString = userDefaults?.string(forKey: "today_schedule") ?? "[]"
        let campus = userDefaults?.string(forKey: "widget_campus") ?? "济南"
        let displayDate = WidgetStore.scheduleDate() ?? Date()

        var items: [ScheduleItemData] = []

        if let data = jsonString.data(using: .utf8) {
             if let decoded = try? JSONDecoder().decode([ScheduleItemData].self, from: data) {
                 items = decoded.sorted(by: { $0.startUnit < $1.startUnit })
             }
        }

        let now = Date()
        let validItems = ScheduleFilter.filterUpcoming(items: items, at: now, campus: campus)
        let entry = ScheduleEntry(
            date: displayDate,
            items: validItems.isEmpty && !items.isEmpty ? [] : validItems
        )
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct ScheduleItemData: Codable {
    let name: String
    let teacher: String
    let classroom: String
    let startUnit: Int
    let endUnit: Int
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let items: [ScheduleItemData]
}

struct ScheduleWidgetEntryView : View {
    var entry: ScheduleProvider.Entry
    private var campus: String {
        WidgetStore.campus()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text(formatDate(entry.date)).font(.system(size: 16, weight: .bold))
                Text(Config.weekday(entry.date))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 245/255, green: 108/255, blue: 108/255))
                Spacer()
            }

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前").font(.system(size: 10)).foregroundColor(.gray)
                    if let cur = entry.items.first {
                        ClassView(item: cur, color: Color(red: 245/255, green: 108/255, blue: 108/255), campus: campus, displayDate: entry.date)
                    } else {
                         Text("无课程").font(.subheadline).bold().foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 60).padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("接下来").font(.system(size: 10)).foregroundColor(.gray)
                    if entry.items.count > 1 {
                        ClassView(item: entry.items[1], color: Color(red: 64/255, green: 158/255, blue: 255/255), campus: campus, displayDate: entry.date)
                    } else {
                        Text("无课程").font(.subheadline).bold().foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.white
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: date)
    }
}

struct ClassView: View {
    let item: ScheduleItemData
    let color: Color
    let campus: String
    let displayDate: Date

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.classroom)
                    Text(item.teacher)
                }
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .lineLimit(1)

                Text(TimeHelper.getTimeRange(
                    start: item.startUnit,
                    end: item.endUnit,
                    campus: campus,
                    date: displayDate
                ))
                    .font(.system(size: 11))
            }
        }
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
        .description("显示当前和接下来的课程")
        .supportedFamilies([.systemMedium])
    }
}

enum ScheduleFilter {
    static func filterUpcoming(items: [ScheduleItemData], at date: Date, campus: String) -> [ScheduleItemData] {
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
