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
            guard let endMinutes = WidgetTimeTable.periodEndMinutes(period: period, campus: campus, date: now) else {
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
    private static let jinanStartMinutes: [Int: Int] = [
        1: 8 * 60,
        2: 8 * 60 + 45,
        3: 10 * 60,
        4: 10 * 60 + 45,
        5: 13 * 60 + 30,
        6: 14 * 60 + 15,
        7: 15 * 60 + 30,
        8: 16 * 60 + 15,
        9: 19 * 60,
        10: 19 * 60 + 45,
        11: 20 * 60 + 30,
        12: 21 * 60 + 15,
    ]

    private static let jinanEndMinutes: [Int: Int] = [
        1: 8 * 60 + 45,
        2: 9 * 60 + 30,
        3: 10 * 60 + 45,
        4: 11 * 60 + 30,
        5: 14 * 60 + 15,
        6: 15 * 60,
        7: 16 * 60 + 15,
        8: 17 * 60,
        9: 19 * 60 + 45,
        10: 20 * 60 + 30,
        11: 21 * 60 + 15,
        12: 22 * 60,
    ]

    static func isSummer(_ date: Date) -> Bool {
        let month = Calendar.current.component(.month, from: date)
        if month > 5 && month < 10 { return true }
        if month == 5 { return true }
        return false
    }

    static func periodStartMinutes(period: Int, campus: String, date: Date) -> Int? {
        if campus != "日照" {
            return jinanStartMinutes[period]
        }
        if period <= 4 {
            return jinanStartMinutes[period]
        }

        let summer = isSummer(date)
        switch period {
        case 5: return summer ? 14 * 60 + 30 : 14 * 60
        case 6: return summer ? 15 * 60 + 20 : 14 * 60 + 50
        case 7: return summer ? 16 * 60 + 30 : 16 * 60
        case 8: return summer ? 17 * 60 + 20 : 16 * 60 + 50
        case 9: return 19 * 60
        case 10: return 19 * 60 + 50
        case 11: return 20 * 60 + 40
        case 12: return 21 * 60 + 30
        default: return nil
        }
    }

    static func periodEndMinutes(period: Int, campus: String, date: Date) -> Int? {
        if campus != "日照" {
            return jinanEndMinutes[period]
        }
        if period <= 4 {
            return jinanEndMinutes[period]
        }

        let summer = isSummer(date)
        switch period {
        case 5: return summer ? 15 * 60 + 10 : 14 * 60 + 40
        case 6: return summer ? 16 * 60 : 15 * 60 + 30
        case 7: return summer ? 17 * 60 + 10 : 16 * 60 + 40
        case 8: return summer ? 18 * 60 : 17 * 60 + 30
        case 9: return 20 * 60 + 30
        case 10: return 21 * 60 + 20
        case 11: return 22 * 60 + 10
        case 12: return 23 * 60
        default: return nil
        }
    }

    static func endMinutesForUnit(_ endUnit: Int, campus: String, date: Date) -> Int {
        periodEndMinutes(period: endUnit, campus: campus, date: date) ?? (23 * 60 + 59)
    }

    static func formatMinutes(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    static func formatTimeRange(startPeriod: Int, endPeriod: Int, campus: String, date: Date) -> String {
        let start = periodStartMinutes(period: startPeriod, campus: campus, date: date) ?? 0
        let end = periodEndMinutes(period: endPeriod, campus: campus, date: date) ?? 0
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
