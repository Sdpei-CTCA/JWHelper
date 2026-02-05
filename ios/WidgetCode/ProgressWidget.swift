import WidgetKit
import SwiftUI

struct ProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), gpa: "3.8", majorExtra: "100", earned: "120", required: "150")
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> ()) {
        let entry = ProgressEntry(date: Date(), gpa: "3.8", majorExtra: "100", earned: "120", required: "150")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> ()) {
        // Fetch from UserDefaults
        // NOTE: Make sure App Groups is enabled in Xcode and matches this suite name
        let userDefaults = UserDefaults(suiteName: "group.com.jwhelper.shared")
        let gpa = userDefaults?.string(forKey: "gpa") ?? "--"
        let majorExtra = userDefaults?.string(forKey: "major_extra_credits") ?? "--"
        let earned = userDefaults?.string(forKey: "earned_credits") ?? "--"
        let required = userDefaults?.string(forKey: "required_credits") ?? "--"
        
        let entry = ProgressEntry(date: Date(), gpa: gpa, majorExtra: majorExtra, earned: earned, required: required)

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
}

struct ProgressWidgetEntryView : View {
    var entry: ProgressProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("学位课程绩点").font(.caption).foregroundColor(.gray)
            Text(entry.gpa).font(.largeTitle).bold()
            
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("主修+方案").font(.system(size: 10)).foregroundColor(.gray)
                    Text(entry.majorExtra).bold()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("已获得").font(.system(size: 10)).foregroundColor(.gray)
                    Text(entry.earned).bold()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("最低要求").font(.system(size: 10)).foregroundColor(.gray)
                    Text(entry.required).bold()
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.white
        }
    }
}

struct ProgressWidget: Widget {
    let kind: String = "ProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            ProgressWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("学业进度")
        .description("显示GPA和学分进度")
        .supportedFamilies([.systemSmall, .systemMedium])
        // .contentMarginsDisabled() // For iOS 17 style if needed
    }
}
