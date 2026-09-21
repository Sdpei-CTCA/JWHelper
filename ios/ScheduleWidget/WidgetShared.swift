import SwiftUI
import WidgetKit

enum WidgetAppGroup {
    // New App Group ID (ensure it is enabled for both app + widget targets in Xcode)
    static var id: String {
        #if DEBUG
        return "group.com.jwhelper.shared.dev"
        #else
        return "group.com.jwhelper.shared"
        #endif
    }
}

enum WidgetKeys {
    static let gpa = "gpa"
    static let majorExtra = "major_extra_credits"
    static let earned = "earned_credits"
    static let required = "required_credits"
    static let todaySchedule = "today_schedule"
    static let weekSchedule = "week_schedule"
    static let scheduleDateIso = "schedule_date_iso"
    static let widgetCurrentWeek = "widget_current_week"
    static let widgetWeekAnchorDate = "widget_week_anchor_date"
    static let scheduleStartDay = "schedule_start_day"
    static let widgetCampus = "widget_campus"
    static let lastUpdated = "widget_last_updated"
    static let debugEnabled = "widget_debug_enabled"
    static let displayMode = "widget_display_mode"
    static let upcomingExams = "upcoming_exams"
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

    static func scheduleDate() -> Date? {
        guard let raw = defaults?.string(forKey: WidgetKeys.scheduleDateIso) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    static func debugEnabled() -> Bool {
        defaults?.bool(forKey: WidgetKeys.debugEnabled) ?? false
    }

    static func displayMode() -> String {
        defaults?.string(forKey: WidgetKeys.displayMode) ?? "schedule"
    }

    static func upcomingExams() -> [ExamItemData] {
        let jsonString = defaults?.string(forKey: WidgetKeys.upcomingExams) ?? "[]"
        guard let data = jsonString.data(using: .utf8) else { return [] }
        guard let decoded = try? JSONDecoder().decode([ExamItemData].self, from: data) else { return [] }
        return decoded
    }

    static func campus() -> String {
        defaults?.string(forKey: WidgetKeys.widgetCampus) ?? "济南"
    }

    static func currentWeekValue() -> Int {
        Int(defaults?.string(forKey: WidgetKeys.widgetCurrentWeek) ?? "0") ?? 0
    }

    static func weekAnchorDate() -> Date? {
        guard let raw = defaults?.string(forKey: WidgetKeys.widgetWeekAnchorDate) else {
            return scheduleDate()
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    static func scheduleStartDay() -> String? {
        let raw = defaults?.string(forKey: WidgetKeys.scheduleStartDay) ?? ""
        return raw.isEmpty ? nil : raw
    }

    static func weekScheduleItems() -> [ScheduleItemData] {
        let jsonString = defaults?.string(forKey: WidgetKeys.weekSchedule) ?? "[]"
        guard let data = jsonString.data(using: .utf8) else { return [] }
        guard let decoded = try? JSONDecoder().decode([ScheduleItemData].self, from: data) else { return [] }
        return decoded
    }

    static func refreshTodayScheduleIfNeeded(now: Date = Date()) {
        guard displayMode() == "schedule" else { return }
        guard let savedDate = scheduleDate() else { return }
        let calendar = Calendar.current
        if calendar.isDate(savedDate, inSameDayAs: now) {
            return
        }
        guard !weekScheduleItems().isEmpty else { return }

        let resolved = WidgetDayResolver.resolveTodayFromCache(
            allItems: weekScheduleItems(),
            anchorWeek: currentWeekValue(),
            anchorDate: weekAnchorDate() ?? savedDate,
            startDay: scheduleStartDay(),
            now: now
        )

        let encoder = JSONEncoder()
        guard let itemsData = try? encoder.encode(resolved.displayItems),
              let itemsJson = String(data: itemsData, encoding: .utf8) else {
            return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"

        defaults?.set(itemsJson, forKey: WidgetKeys.todaySchedule)
        defaults?.set(formatter.string(from: resolved.displayDate), forKey: WidgetKeys.scheduleDateIso)
        defaults?.set("\(calendar.component(.month, from: resolved.displayDate))月\(calendar.component(.day, from: resolved.displayDate))日", forKey: "today_date")
        defaults?.set(String(resolved.displayWeek), forKey: WidgetKeys.widgetCurrentWeek)
        defaults?.set("第\(resolved.displayWeek)周", forKey: "current_week")
        defaults?.set(formatter.string(from: resolved.displayDate), forKey: WidgetKeys.widgetWeekAnchorDate)
    }
}

enum WidgetDayResolver {
    static func calendarDayIndex(_ date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? 6 : weekday - 2
    }

    static func resolveTodayFromCache(
        allItems: [ScheduleItemData],
        anchorWeek: Int,
        anchorDate: Date,
        startDay: String?,
        now: Date
    ) -> ResolvedWidgetDay {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let week = resolveWeek(
            targetDate: today,
            anchorWeek: anchorWeek,
            anchorDate: anchorDate,
            startDay: startDay
        )
        let dayIndex = calendarDayIndex(now)
        let items = itemsForDay(allItems: allItems, dayIndex: dayIndex, currentWeek: week)
        return ResolvedWidgetDay(displayDate: today, displayWeek: week, displayItems: items)
    }

    static func resolveWeek(
        targetDate: Date,
        anchorWeek: Int,
        anchorDate: Date,
        startDay: String?
    ) -> Int {
        if let week = weekFromStartDay(startDay, targetDate: targetDate) {
            return week
        }
        return resolveWeekForDate(
            anchorWeek: anchorWeek,
            anchorDate: anchorDate,
            targetDate: targetDate
        )
    }

    static func weekFromStartDay(_ startDay: String?, targetDate: Date) -> Int? {
        guard let startDay, !startDay.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDay) else { return nil }

        let calendar = Calendar.current
        let startDayOnly = calendar.startOfDay(for: start)
        let targetDay = calendar.startOfDay(for: targetDate)
        let daysBetween = calendar.dateComponents([.day], from: startDayOnly, to: targetDay).day ?? 0
        if daysBetween < 0 { return 1 }
        return daysBetween / 7 + 1
    }

    static func resolveWeekForDate(anchorWeek: Int, anchorDate: Date, targetDate: Date) -> Int {
        if anchorWeek <= 0 { return anchorWeek }
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let targetDay = calendar.startOfDay(for: targetDate)
        if targetDay <= anchorDay { return anchorWeek }

        let daysBetween = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
        return anchorWeek + daysBetween / 7
    }

    static func itemsForDay(allItems: [ScheduleItemData], dayIndex: Int, currentWeek: Int) -> [ScheduleItemData] {
        allItems.filter { item in
            item.dayIndex == dayIndex && isInCurrentWeek(item, currentWeek: currentWeek)
        }
        .sorted(by: { $0.startUnit < $1.startUnit })
    }

    static func isInCurrentWeek(_ item: ScheduleItemData, currentWeek: Int) -> Bool {
        if currentWeek <= 0 { return true }
        if item.weekStart > 0 && item.weekEnd > 0 {
            return currentWeek >= item.weekStart && currentWeek <= item.weekEnd
        }
        return true
    }
}

struct ResolvedWidgetDay {
    let displayDate: Date
    let displayWeek: Int
    let displayItems: [ScheduleItemData]
}

enum WidgetRefreshTimes {
    static func upcomingRefreshDates(
        items: [ScheduleItemData],
        campus: String,
        now: Date = Date()
    ) -> [Date] {
        var dates = Set<Date>()
        dates.insert(now)

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)

        for period in 1...12 {
            guard let endMinutes = WidgetTimeTable.periodEndMinutes(period: period, campus: campus) else {
                continue
            }
            var components = calendar.dateComponents([.year, .month, .day], from: startOfDay)
            components.hour = endMinutes / 60
            components.minute = endMinutes % 60
            components.second = 5
            if let date = calendar.date(from: components), date > now.addingTimeInterval(1) {
                dates.insert(date)
            }
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) {
            var midnight = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            midnight.hour = 0
            midnight.minute = 1
            midnight.second = 0
            if let date = calendar.date(from: midnight) {
                dates.insert(date)
            }
        }

        return dates.sorted()
    }
}

enum WidgetTimeTable {
    /// 济南：第 1-9 节与日照相同，第 10 节不存在，第 11-12 节早于日照。
    private static let jinanStartMinutes: [Int: Int] = [
        1: 8 * 60,
        2: 8 * 60 + 45,
        3: 9 * 60 + 45,
        4: 10 * 60 + 30,
        5: 11 * 60 + 15,
        6: 14 * 60,
        7: 14 * 60 + 45,
        8: 15 * 60 + 45,
        9: 16 * 60 + 30,
        11: 18 * 60 + 30,
        12: 19 * 60 + 15,
    ]

    private static let jinanEndMinutes: [Int: Int] = [
        1: 8 * 60 + 40,
        2: 9 * 60 + 25,
        3: 10 * 60 + 25,
        4: 11 * 60 + 10,
        5: 11 * 60 + 55,
        6: 14 * 60 + 40,
        7: 15 * 60 + 25,
        8: 16 * 60 + 25,
        9: 17 * 60 + 10,
        11: 19 * 60 + 10,
        12: 19 * 60 + 55,
    ]

    private static let rizhaoStartMinutes: [Int: Int] = [
        1: 8 * 60,
        2: 8 * 60 + 45,
        3: 9 * 60 + 45,
        4: 10 * 60 + 30,
        5: 11 * 60 + 15,
        6: 14 * 60,
        7: 14 * 60 + 45,
        8: 15 * 60 + 45,
        9: 16 * 60 + 30,
        10: 17 * 60 + 15,
        11: 19 * 60,
        12: 19 * 60 + 45,
    ]

    private static let rizhaoEndMinutes: [Int: Int] = [
        1: 8 * 60 + 40,
        2: 9 * 60 + 25,
        3: 10 * 60 + 25,
        4: 11 * 60 + 10,
        5: 11 * 60 + 55,
        6: 14 * 60 + 40,
        7: 15 * 60 + 25,
        8: 16 * 60 + 25,
        9: 17 * 60 + 10,
        10: 17 * 60 + 55,
        11: 19 * 60 + 40,
        12: 20 * 60 + 25,
    ]

    static func periodStartMinutes(period: Int, campus: String) -> Int? {
        campus == "日照" ? rizhaoStartMinutes[period] : jinanStartMinutes[period]
    }

    static func periodEndMinutes(period: Int, campus: String) -> Int? {
        campus == "日照" ? rizhaoEndMinutes[period] : jinanEndMinutes[period]
    }

    /// 该校区该节次的下课时间（零点起的分钟数）。
    ///
    /// 节次不存在时（例如济南的第 10 节）返回当天最后一分钟，使调用方的
    /// “是否已下课”判定退化为“保持可见”，不会把课程误判为已结束而隐藏。
    static func endMinutesForUnit(_ endUnit: Int, campus: String) -> Int {
        periodEndMinutes(period: endUnit, campus: campus) ?? (23 * 60 + 59)
    }

    static func formatMinutes(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    static func formatTimeRange(startPeriod: Int, endPeriod: Int, campus: String) -> String {
        let start = periodStartMinutes(period: startPeriod, campus: campus) ?? 0
        let end = periodEndMinutes(period: endPeriod, campus: campus) ?? 0
        return "\(formatMinutes(start)) - \(formatMinutes(end))"
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
