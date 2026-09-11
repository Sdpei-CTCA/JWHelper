import WidgetKit
import SwiftUI

// Time helper
struct TimeHelper {
    // Official class-period timetable (40-minute periods).
    // Periods 1-9 are identical on both campuses; the campuses only differ at periods 10-12,
    // and Jinan campus has no period 10.
    static let jinanMap: [Int: String] = [
        1: "08:00-08:40",
        2: "08:45-09:25",
        3: "09:45-10:25",
        4: "10:30-11:10",
        5: "11:15-11:55",
        6: "14:00-14:40",
        7: "14:45-15:25",
        8: "15:45-16:25",
        9: "16:30-17:10",
        11: "18:30-19:10",
        12: "19:15-19:55"
    ]

    static let rizhaoMap: [Int: String] = [
        1: "08:00-08:40",
        2: "08:45-09:25",
        3: "09:45-10:25",
        4: "10:30-11:10",
        5: "11:15-11:55",
        6: "14:00-14:40",
        7: "14:45-15:25",
        8: "15:45-16:25",
        9: "16:30-17:10",
        10: "17:15-17:55",
        11: "19:00-19:40",
        12: "19:45-20:25"
    ]

    static func map(for campus: String) -> [Int: String] {
        campus == "日照" ? rizhaoMap : jinanMap
    }

    /// Returns an empty string when the period does not exist on the campus.
    static func getTimeRange(start: Int, end: Int, campus: String) -> String {
        let table = map(for: campus)
        guard let startStr = table[start]?.components(separatedBy: "-").first,
              let endStr = table[end]?.components(separatedBy: "-").last else {
            return ""
        }
        return "\(startStr) - \(endStr)"
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
            lastUpdated: Date(),
            debugEnabled: false,
            campus: "济南"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> ()) {
        let entry = ScheduleEntry(
            date: Date(),
            items: [
                ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
                ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
            ],
            lastUpdated: Date(),
            debugEnabled: false,
            campus: "济南"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> ()) {
        let items = WidgetStore.scheduleItems()
        let now = Date()
        let displayDate = WidgetStore.scheduleDate() ?? now
        let isDisplayToday = Calendar.current.isDate(displayDate, inSameDayAs: now)
        let campus = WidgetStore.campus()

        let validItems = isDisplayToday
            ? ScheduleFilter.filterUpcoming(items: items, now: now, campus: campus)
            : items
        let entry = ScheduleEntry(
            date: displayDate,
            items: validItems.isEmpty && !items.isEmpty ? [] : validItems,
            lastUpdated: WidgetStore.date(WidgetKeys.lastUpdated),
            debugEnabled: WidgetStore.debugEnabled(),
            campus: campus
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
    let lastUpdated: Date?
    let debugEnabled: Bool
    let campus: String
}

struct ScheduleWidgetEntryView: View {
    var entry: ScheduleProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if entry.items.isEmpty {
                emptyState
            } else {
                ScheduleTwoColumn(items: entry.items, campus: entry.campus)
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
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(formatDate(entry.date))
                .font(.system(size: 18, weight: .bold))
            Text(Config.weekday(entry.date))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(WidgetColors.accent)
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

                Text(TimeHelper.getTimeRange(start: item.startUnit, end: item.endUnit, campus: campus))
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

struct ScheduleTwoColumn: View {
    let items: [ScheduleItemData]
    let campus: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ScheduleColumn(title: "第一节", item: items.first, accent: WidgetColors.accent, campus: campus)

            Divider()
                .frame(maxHeight: 90)

            ScheduleColumn(
                title: "第二节",
                item: items.count > 1 ? items[1] : nil,
                accent: WidgetColors.primary,
                campus: campus
            )
        }
    }
}

struct ScheduleColumn: View {
    let title: String
    let item: ScheduleItemData?
    let accent: Color
    let campus: String

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

                        Text(TimeHelper.getTimeRange(start: item.startUnit, end: item.endUnit, campus: campus))
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
    static func filterUpcoming(items: [ScheduleItemData], now: Date, campus: String) -> [ScheduleItemData] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let nowMinutes = hour * 60 + minute

        let table = TimeHelper.map(for: campus)
        let validItems = items.filter { item in
            let endRange = table[item.endUnit] ?? "23:59-23:59"
            let endTimeStr = endRange.components(separatedBy: "-").last ?? "23:59"
            let parts = endTimeStr.split(separator: ":").map { Int($0) ?? 0 }
            guard parts.count == 2 else { return true }
            let endMinutes = parts[0] * 60 + parts[1]
            return endMinutes > nowMinutes
        }

        return validItems
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
