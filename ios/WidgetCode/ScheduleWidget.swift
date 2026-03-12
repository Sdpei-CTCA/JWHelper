import WidgetKit
import SwiftUI

// Time helper
struct TimeHelper {
    static let map: [Int: String] = [
        1 : "08:00-08:45",
        2 : "08:55-09:40",
        3 : "10:00-10:45",
        4 : "10:55-11:40",
        5 : "13:30-14:15",
        6 : "14:25-15:10",
        7 : "15:20-16:05",
        8 : "16:25-17:10",
        9 : "17:20-18:05",
        10 : "18:30-19:15",
        11 : "19:25-20:10",
        12 : "20:20-21:05"
    ]
    
    static func getTimeRange(start: Int, end: Int) -> String {
        let startStr = map[start]?.components(separatedBy: "-")[0] ?? "00:00"
        let endStr = map[end]?.components(separatedBy: "-")[1] ?? "00:00"
        return "\(startStr) - \(endStr)"
    }
}

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), displayDate: Date(), items: [
            ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
            ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
        ], isTomorrow: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> ()) {
        let entry = ScheduleEntry(date: Date(), displayDate: Date(), items: [
            ScheduleItemData(name: "高等数学", teacher: "小洁", classroom: "东教楼123", startUnit: 1, endUnit: 2),
            ScheduleItemData(name: "数据库原理", teacher: "小越", classroom: "文成楼125", startUnit: 3, endUnit: 4)
        ], isTomorrow: false)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.jwhelper.shared")
        let todayJsonString = userDefaults?.string(forKey: "today_schedule") ?? "[]"
        let tomorrowJsonString = userDefaults?.string(forKey: "tomorrow_schedule") ?? "[]"
        
        func parseItems(_ jsonString: String) -> [ScheduleItemData] {
            guard let data = jsonString.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([ScheduleItemData].self, from: data) else {
                return []
            }
            return decoded.sorted(by: { $0.startUnit < $1.startUnit })
        }

        let todayItems = parseItems(todayJsonString)
        let tomorrowItems = parseItems(tomorrowJsonString)

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let nowMinutes = hour * 60 + minute
        
        let validTodayItems = todayItems.filter { item in
            let endRange = TimeHelper.map[item.endUnit] ?? "23:59-23:59"
            let endTimeStr = endRange.components(separatedBy: "-")[1]
            let parts = endTimeStr.split(separator: ":").map { Int($0) ?? 0 }
            let endMinutes = parts[0] * 60 + parts[1]
            return endMinutes > nowMinutes
        }

        // If all today's classes are done, fall back to tomorrow's schedule
        let isTomorrow = validTodayItems.isEmpty
        let displayItems = isTomorrow ? tomorrowItems : validTodayItems
        let displayDate = isTomorrow ? (calendar.date(byAdding: .day, value: 1, to: now) ?? now) : now

        let entry = ScheduleEntry(date: now, displayDate: displayDate, items: displayItems, isTomorrow: isTomorrow)

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
    let displayDate: Date
    let items: [ScheduleItemData]
    let isTomorrow: Bool
}

struct ScheduleWidgetEntryView : View {
    var entry: ScheduleProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .bottom) {
                Text(formatDate(entry.displayDate)).font(.system(size: 16, weight: .bold))
                Text(Config.weekday(entry.displayDate))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 245/255, green: 108/255, blue: 108/255))
                if entry.isTomorrow {
                    Text("明日")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                }
                Spacer()
            }
            
            HStack(alignment: .top, spacing: 0) {
                // Left: Current/First class
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.isTomorrow ? "第一节" : "当前").font(.system(size: 10)).foregroundColor(.gray)
                    if let cur = entry.items.first {
                        ClassView(item: cur, color: Color(red: 245/255, green: 108/255, blue: 108/255))
                    } else {
                         Text("无课程").font(.subheadline).bold().foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider().frame(height: 60).padding(.horizontal, 8)
                
                // Right: Next/Second class
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.isTomorrow ? "第二节" : "接下来").font(.system(size: 10)).foregroundColor(.gray)
                    if entry.items.count > 1 {
                        ClassView(item: entry.items[1], color: Color(red: 64/255, green: 158/255, blue: 255/255))
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
                
                Text(TimeHelper.getTimeRange(start: item.startUnit, end: item.endUnit))
                    .font(.system(size: 11))
            }
        }
    }
}

struct Config {
    static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE" // 周几
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
        .supportedFamilies([.systemMedium]) // Only support Medium for this layout
    }
}
