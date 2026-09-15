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
    var journals: [TradeJournal] = []

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

    // MARK: - 月度統計

    struct MonthSummary {
        let buyCount: Int
        let sellCount: Int
        let totalInvested: Double
        let realizedPnL: Double
        let winCount: Int
        let winRate: Double
    }

    var currentMonthSummary: MonthSummary {
        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay)
        else {
            return MonthSummary(buyCount: 0, sellCount: 0, totalInvested: 0, realizedPnL: 0, winCount: 0, winRate: 0)
        }

        // 當月買入
        let buys = investments.filter { $0.buyDate >= firstDay && $0.buyDate < nextMonth }
        let buyCount = buys.count
        let totalInvested = buys.reduce(0.0) { $0 + $1.buyPrice * $1.originalQuantity }

        // 當月賣出
        let sells = closedInvestments.filter { inv in
            guard let sellDate = inv.sellDate else { return false }
            return sellDate >= firstDay && sellDate < nextMonth
        }
        let sellCount = sells.count
        let fees = TradingFeeSettings.load()
        let realizedPnL = sells.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) }
        let winCount = sells.filter { $0.realizedProfitLoss(fees: fees) > 0 }.count
        let winRate = sellCount > 0 ? Double(winCount) / Double(sellCount) * 100 : 0

        return MonthSummary(
            buyCount: buyCount, sellCount: sellCount,
            totalInvested: totalInvested, realizedPnL: realizedPnL,
            winCount: winCount, winRate: winRate
        )
    }

    /// 該月是否有任何交易
    var hasTradesInMonth: Bool {
        let s = currentMonthSummary
        return s.buyCount > 0 || s.sellCount > 0
    }

    // MARK: - Journal 查詢

    /// 查詢 Investment 對應的 TradeJournal
    func journal(for investmentID: UUID) -> TradeJournal? {
        journals.first { $0.investmentID == investmentID }
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
