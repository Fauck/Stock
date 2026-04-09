import Foundation
import Observation

@Observable
final class CalendarViewModel {
    // MARK: - State
    var selectedDate: Date = Date()
    var currentMonth: Date = Date()
    var showingAddSheet: Bool = false

    // MARK: - Constants
    let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    private let calendar = Calendar.current

    // MARK: - Data (bridged from @Query)
    var investments: [Investment] = []
    var closedInvestments: [Investment] = []

    // MARK: - Calendar Navigation

    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func generateDaysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingSpaces = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingSpaces)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    // MARK: - Date Formatting

    func monthYearString(from date: Date) -> String {
        AppDateFormatter.monthYear.string(from: date)
    }

    func dateString(from date: Date) -> String {
        AppDateFormatter.dayFull.string(from: date)
    }

    // MARK: - Record Queries

    /// 該日期的買入紀錄
    func buyRecordsOnDate(_ date: Date) -> [Investment] {
        investments.filter { calendar.isDate($0.buyDate, inSameDayAs: date) }
    }

    /// 該日期的賣出紀錄（從所有已平倉紀錄中篩選，包含部分賣出拆分紀錄）
    func sellRecordsOnDate(_ date: Date) -> [Investment] {
        closedInvestments.filter { inv in
            guard let sellDate = inv.sellDate else { return false }
            return calendar.isDate(sellDate, inSameDayAs: date)
        }
    }

    // MARK: - Date Comparison Helpers

    func isDateInSameDay(_ date1: Date, _ date2: Date) -> Bool {
        calendar.isDate(date1, inSameDayAs: date2)
    }

    func isDateToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func dayComponent(from date: Date) -> Int {
        calendar.component(.day, from: date)
    }
}
