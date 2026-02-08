import WidgetKit
import SwiftUI

struct ProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(
            date: Date(),
            gpa: "3.8",
            majorExtra: "100",
            earned: "120",
            required: "150",
            lastUpdated: Date(),
            debugEnabled: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> ()) {
        let entry = ProgressEntry(
            date: Date(),
            gpa: "3.8",
            majorExtra: "100",
            earned: "120",
            required: "150",
            lastUpdated: Date(),
            debugEnabled: false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> ()) {
        let entry = ProgressEntry(
            date: Date(),
            gpa: WidgetStore.string(WidgetKeys.gpa),
            majorExtra: WidgetStore.string(WidgetKeys.majorExtra),
            earned: WidgetStore.string(WidgetKeys.earned),
            required: WidgetStore.string(WidgetKeys.required),
            lastUpdated: WidgetStore.date(WidgetKeys.lastUpdated),
            debugEnabled: WidgetStore.debugEnabled()
        )

        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct ProgressEntry: TimelineEntry {
    let date: Date
    let gpa: String
    let majorExtra: String
    let earned: String
    let required: String
    let lastUpdated: Date?
    let debugEnabled: Bool
}

struct ProgressWidgetEntryView: View {
    var entry: ProgressProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("学业进度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let time = entry.lastUpdated {
                    Text("更新 \(timeString(time))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(entry.gpa)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(WidgetColors.primary)
                Text("GPA")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                ProgressStat(title: "主修+方案", value: entry.majorExtra)
                ProgressStat(title: "已获得", value: entry.earned)
                ProgressStat(title: "最低要求", value: entry.required)
            }

            if entry.debugEnabled {
                DebugBlock(lines: [
                    "Debug: ON",
                    "AppGroup: \(WidgetAppGroup.id)",
                    "Updated: \(entry.lastUpdated != nil ? "yes" : "no")"
                ])
            }
        }
        .padding()
        .widgetBackground(WidgetColors.background)
    }

    func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

struct ProgressStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WidgetColors.cardBackground)
        .cornerRadius(10)
    }
}

struct ProgressWidget: Widget {
    let kind: String = "ProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            ProgressWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("绩点与学分")
        .description("展示绩点与学分进度")
        .supportedFamilies([.systemMedium])
    }
}
