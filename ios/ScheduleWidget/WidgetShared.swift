import SwiftUI
import WidgetKit

enum WidgetAppGroup {
    // New App Group ID (ensure it is enabled for both app + widget targets in Xcode)
    static let id = "group.com.jwhelper.shared"
}

enum WidgetKeys {
    static let gpa = "gpa"
    static let majorExtra = "major_extra_credits"
    static let earned = "earned_credits"
    static let required = "required_credits"
    static let todaySchedule = "today_schedule"
    static let lastUpdated = "widget_last_updated"
    static let debugEnabled = "widget_debug_enabled"
}

struct WidgetStore {
    static var defaults: UserDefaults? { UserDefaults(suiteName: WidgetAppGroup.id) }

    static func string(_ key: String, defaultValue: String = "--") -> String {
        defaults?.string(forKey: key) ?? defaultValue
    }

    static func date(_ key: String) -> Date? {
        guard let raw = defaults?.string(forKey: key) else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    static func scheduleItems() -> [ScheduleItemData] {
        let jsonString = defaults?.string(forKey: WidgetKeys.todaySchedule) ?? "[]"
        guard let data = jsonString.data(using: .utf8) else { return [] }
        guard let decoded = try? JSONDecoder().decode([ScheduleItemData].self, from: data) else { return [] }
        return decoded.sorted(by: { $0.startUnit < $1.startUnit })
    }

    static func debugEnabled() -> Bool {
        defaults?.bool(forKey: WidgetKeys.debugEnabled) ?? false
    }
}

enum WidgetColors {
    static let primary = Color(red: 64/255, green: 158/255, blue: 255/255)
    static let accent = Color(red: 245/255, green: 108/255, blue: 108/255)
    static let textSecondary = Color.secondary
    static let background = Color(.systemBackground)
    static let cardBackground = Color(.secondarySystemBackground)
    static let debugBackground = Color(.tertiarySystemBackground)
}

struct DebugBlock: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .background(WidgetColors.debugBackground)
        .cornerRadius(8)
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { color }
        } else {
            self.background(color)
        }
    }
}
