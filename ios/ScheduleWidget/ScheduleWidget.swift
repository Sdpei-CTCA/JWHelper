import WidgetKit
import SwiftUI

// 课节时间（timeRange）与下课时间（endTime）由 Flutter 侧解析后随
// today_schedule payload 下发；小组件只做读取与渲染，不再持有本地作息表。

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(
            date: Date(),
            items: [
                ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
                ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
            ],
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
            lastUpdated: Date(),
            debugEnabled: false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> ()) {
        let items = WidgetStore.scheduleItems()
        let now = Date()
        let displayDate = WidgetStore.scheduleDate() ?? now
        let isDisplayToday = Calendar.current.isDate(displayDate, inSameDayAs: now)

        let validItems = isDisplayToday
            ? ScheduleFilter.filterUpcoming(items: items, now: now)
            : items
        let entry = ScheduleEntry(
            date: displayDate,
            items: validItems.isEmpty && !items.isEmpty ? [] : validItems,
            lastUpdated: WidgetStore.date(WidgetKeys.lastUpdated),
            debugEnabled: WidgetStore.debugEnabled()
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
    /// 显示用时间区间（如 "08:00 - 09:25"），由 Flutter 下发；缺失时为空字符串。
    let timeRange: String? = nil
    /// 下课时间（如 "09:25"），用于“是否已下课”判定；缺失时为 nil。
    let endTime: String? = nil
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let items: [ScheduleItemData]
    let lastUpdated: Date?
    let debugEnabled: Bool
}

struct ScheduleWidgetEntryView: View {
    var entry: ScheduleProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if entry.items.isEmpty {
                emptyState
            } else {
                ScheduleTwoColumn(items: entry.items)
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

                Text(item.timeRange ?? "")
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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ScheduleColumn(title: "第一节", item: items.first, accent: WidgetColors.accent)

            Divider()
                .frame(maxHeight: 90)

            ScheduleColumn(
                title: "第二节",
                item: items.count > 1 ? items[1] : nil,
                accent: WidgetColors.primary
            )
        }
    }
}

struct ScheduleColumn: View {
    let title: String
    let item: ScheduleItemData?
    let accent: Color
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

                        Text(item.timeRange ?? "")
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
    /// 过滤出“尚未下课”的课程。`endTime` 缺失或非法时返回 true（保持课程可见），
    /// 与 Dart / Android 侧“宁可多显示，不可误隐藏”的策略保持一致。
    static func filterUpcoming(items: [ScheduleItemData], now: Date) -> [ScheduleItemData] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let nowMinutes = hour * 60 + minute

        return items.filter { item in
            guard let endMinutes = minutes(from: item.endTime) else { return true }
            return endMinutes > nowMinutes
        }
    }

    /// 将 "HH:mm" 解析为“当天已过分钟数”；格式非法时返回 nil。
    private static func minutes(from time: String?) -> Int? {
        guard let time = time else { return nil }
        let parts = time.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
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
