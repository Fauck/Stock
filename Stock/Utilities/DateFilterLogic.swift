import Foundation

/// 通用日期區間篩選函式
/// - Parameters:
///   - investments: 投資紀錄陣列
///   - filter: 篩選選項
///   - customStart: 自訂區間起始日期
///   - customEnd: 自訂區間結束日期
///   - dateExtractor: 從紀錄中提取日期的閉包（可回傳 nil 表示該紀錄不適用）
func filterInvestments(
    _ investments: [Investment],
    by filter: DateFilterOption,
    customStart: Date,
    customEnd: Date,
    dateExtractor: (Investment) -> Date?
) -> [Investment] {
    let calendar = Calendar.current
    let now = Date()

    switch filter {
    case .all:
        return investments
    case .week:
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return investments
        }
        return investments.filter { inv in
            guard let date = dateExtractor(inv) else { return false }
            return date >= weekAgo
        }
    case .month:
        guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
            return investments
        }
        return investments.filter { inv in
            guard let date = dateExtractor(inv) else { return false }
            return date >= monthAgo
        }
    case .thisMonth:
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let firstDay = calendar.date(from: components),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) else {
            return investments
        }
        return investments.filter { inv in
            guard let date = dateExtractor(inv) else { return false }
            return date >= firstDay && date < nextMonth
        }
    case .custom:
        let startOfDay = calendar.startOfDay(for: customStart)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd)) else {
            return investments
        }
        return investments.filter { inv in
            guard let date = dateExtractor(inv) else { return false }
            return date >= startOfDay && date < endOfDay
        }
    }
}
