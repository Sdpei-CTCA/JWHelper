import WidgetKit
import SwiftUI

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), dateStr: "Today", weekStr: "第1周", scheduleText: "8-9节: 高等数学 @A101\n10-11节: 大学英语 @B202")
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> ()) {
        let entry = ScheduleEntry(date: Date(), dateStr: "Today", weekStr: "第1周", scheduleText: "8-9节: 高等数学 @A101\n10-11节: 大学英语 @B202")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.edu.sdpei.JWSystem.widget")
        let dateStr = userDefaults?.string(forKey: "today_date") ?? "Today"
        let weekStr = userDefaults?.string(forKey: "current_week") ?? ""
        let jsonString = userDefaults?.string(forKey: "today_schedule") ?? "[]"
        
        var scheduleText = "今天没有课"
        
        if let data = jsonString.data(using: .utf8) {
             // Simple JSON decoding wrapper
             if let items = try? JSONDecoder().decode([ScheduleItemData].self, from: data) {
                 if !items.isEmpty {
                     scheduleText = items.map { "\($0.startUnit)-\($0.endUnit)节: \($0.name) @\($0.classroom)" }.joined(separator: "\n")
                 }
             }
        }

        let entry = ScheduleEntry(date: Date(), dateStr: dateStr, weekStr: weekStr, scheduleText: scheduleText)

        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct ScheduleItemData: Codable {
    let name: String
    let classroom: String
    let startUnit: Int
    let endUnit: Int
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let dateStr: String
    let weekStr: String
    let scheduleText: String
}

struct ScheduleWidgetEntryView : View {
    var entry: ScheduleProvider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(entry.dateStr).bold()
                Spacer()
                Text(entry.weekStr).foregroundColor(.gray).font(.caption)
            }
            Divider()
            
            // Limit shown lines for layout stability
            Text(entry.scheduleText)
                .font(.footnote)
                .lineLimit(6)
                
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.white
        }
    }
}

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日课表")
        .description("显示今天的课程安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
