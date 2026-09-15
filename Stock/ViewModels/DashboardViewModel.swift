import Foundation
import Observation

// MARK: - 圖表資料結構

/// 月度損益資料點
struct MonthlyPnLPoint: Identifiable {
    let id = UUID()
    let label: String        // "2026/05"
    let periodStart: Date
    let pnl: Double
    let tradeCount: Int
    let winCount: Int
}

/// 滾動勝率資料點
struct RollingWinRatePoint: Identifiable {
    let id = UUID()
    let tradeIndex: Int      // 第 N 筆交易
    let winRate: Double      // 0.0 – 1.0
}

/// 持有天數分類
enum HoldingBucket: String, CaseIterable, Identifiable {
    case short  = "短線(<5日)"
    case medium = "中線(5-20日)"
    case long   = "長線(>20日)"

    var id: String { rawValue }

    static func bucket(for days: Int) -> HoldingBucket {
        if days < 5 { return .short }
        if days <= 20 { return .medium }
        return .long
    }
}

/// 持有天數分類統計
struct HoldingBucketStat: Identifiable {
    let id: HoldingBucket
    let tradeCount: Int
    let winCount: Int
    var winRate: Double { tradeCount > 0 ? Double(winCount) / Double(tradeCount) * 100 : 0 }
}

/// 情緒分數分組統計
struct EmotionGroupStat: Identifiable {
    let id: Int               // emotionScore 1–5
    let tradeCount: Int
    let winCount: Int
    let avgReturnPct: Double
    var winRate: Double { tradeCount > 0 ? Double(winCount) / Double(tradeCount) * 100 : 0 }

    var scoreLabel: String {
        switch id {
        case 1: return "1 恐慌"
        case 2: return "2 不安"
        case 3: return "3 中立"
        case 4: return "4 樂觀"
        case 5: return "5 貪婪"
        default: return "\(id)"
        }
    }
}

/// R-Multiple 分佈 bucket
struct RBucket: Identifiable {
    let id: String
    let label: String
    let count: Int
    let isPositive: Bool
}

/// 出場理由統計
struct ExitReasonStat: Identifiable {
    let id: String
    let label: String
    let count: Int
    let icon: String
}

/// 標的排行統計
struct DashboardTickerStat: Identifiable {
    let id: String            // normalized ticker
    let displayName: String
    let tradeCount: Int
    let totalPL: Double
    let winCount: Int
    var winRate: Double { tradeCount > 0 ? Double(winCount) / Double(tradeCount) * 100 : 0 }
}

/// 標的排行 Tab
enum TickerRankTab: String, CaseIterable, Identifiable {
    case profit = "獲利排行"
    case loss   = "虧損排行"
    case traded = "交易次數"

    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
final class DashboardViewModel {

    // MARK: - Bridged Data

    var allSoldInvestments: [Investment] = []
    var allJournals: [TradeJournal] = []

    // MARK: - Date Filter State

    var selectedFilter: DateFilterOption = .all
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    var customEndDate: Date = Date()

    // MARK: - Private

    private var fees: TradingFeeSettings { TradingFeeSettings.load() }

    // MARK: - Filtered Data

    var filteredInvestments: [Investment] {
        filterInvestments(
            allSoldInvestments,
            by: selectedFilter,
            customStart: customStartDate,
            customEnd: customEndDate,
            dateExtractor: { $0.sellDate }
        )
    }

    private var journalMap: [UUID: TradeJournal] {
        Dictionary(allJournals.map { ($0.investmentID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var filteredJournals: [TradeJournal] {
        let ids = Set(filteredInvestments.map(\.id))
        return allJournals.filter { ids.contains($0.investmentID) }
    }

    // MARK: - Section 1：績效總覽

    var totalPL: Double {
        filteredInvestments.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) }
    }

    var tradeCount: Int { filteredInvestments.count }

    var winCount: Int {
        filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) > 0 }.count
    }

    var lossCount: Int {
        filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) < 0 }.count
    }

    var winRate: Double {
        guard tradeCount > 0 else { return 0 }
        return Double(winCount) / Double(tradeCount) * 100
    }

    var avgProfit: Double {
        let wins = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) > 0 }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) } / Double(wins.count)
    }

    var avgLoss: Double {
        let losses = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) < 0 }
        guard !losses.isEmpty else { return 0 }
        return abs(losses.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) } / Double(losses.count))
    }

    var profitLossRatio: Double {
        guard avgLoss > 0 else { return 0 }
        return avgProfit / avgLoss
    }

    var maxConsecutiveLosses: Int {
        var maxStreak = 0, current = 0
        let sorted = filteredInvestments.sorted { ($0.sellDate ?? .distantPast) < ($1.sellDate ?? .distantPast) }
        for inv in sorted {
            if inv.realizedProfitLoss(fees: fees) < 0 {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 0
            }
        }
        return maxStreak
    }

    var bestTrade: Double {
        filteredInvestments.map { $0.realizedProfitLoss(fees: fees) }.max() ?? 0
    }

    var worstTrade: Double {
        filteredInvestments.map { $0.realizedProfitLoss(fees: fees) }.min() ?? 0
    }

    // MARK: - Section 2：損益趨勢

    var monthlyPnLData: [MonthlyPnLPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredInvestments) { inv -> DateComponents in
            guard let sd = inv.sellDate else { return DateComponents() }
            return calendar.dateComponents([.year, .month], from: sd)
        }
        return grouped.compactMap { comps, investments -> MonthlyPnLPoint? in
            guard let year = comps.year, let month = comps.month,
                  let periodStart = calendar.date(from: comps) else { return nil }
            let pnl = investments.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) }
            let wins = investments.filter { $0.realizedProfitLoss(fees: fees) > 0 }.count
            return MonthlyPnLPoint(
                label: String(format: "%d/%02d", year, month),
                periodStart: periodStart, pnl: pnl,
                tradeCount: investments.count, winCount: wins
            )
        }
        .sorted { $0.periodStart < $1.periodStart }
    }

    var rollingWinRateData: [RollingWinRatePoint] {
        let windowSize = 10
        let sorted = filteredInvestments.sorted { ($0.sellDate ?? .distantPast) < ($1.sellDate ?? .distantPast) }
        guard sorted.count >= windowSize else { return [] }
        return (windowSize...sorted.count).map { i in
            let window = Array(sorted[(i - windowSize)..<i])
            let wins = window.filter { $0.realizedProfitLoss(fees: fees) > 0 }.count
            return RollingWinRatePoint(tradeIndex: i, winRate: Double(wins) / Double(windowSize))
        }
    }

    // MARK: - Section 3：持有天數分析

    var avgHoldingDaysWin: Int {
        let wins = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) > 0 }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0) { $0 + $1.holdingDays } / wins.count
    }

    var avgHoldingDaysLoss: Int {
        let losses = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) < 0 }
        guard !losses.isEmpty else { return 0 }
        return losses.reduce(0) { $0 + $1.holdingDays } / losses.count
    }

    var holdingBucketStats: [HoldingBucketStat] {
        var buckets: [HoldingBucket: (trades: Int, wins: Int)] = [:]
        for bucket in HoldingBucket.allCases { buckets[bucket] = (0, 0) }

        for inv in filteredInvestments {
            let bucket = HoldingBucket.bucket(for: inv.holdingDays)
            let isWin = inv.realizedProfitLoss(fees: fees) > 0
            buckets[bucket]?.trades += 1
            if isWin { buckets[bucket]?.wins += 1 }
        }

        return HoldingBucket.allCases.compactMap { bucket in
            guard let data = buckets[bucket], data.trades > 0 else { return nil }
            return HoldingBucketStat(id: bucket, tradeCount: data.trades, winCount: data.wins)
        }
    }

    // MARK: - Section 4：情緒 vs 績效

    var hasEmotionData: Bool {
        filteredJournals.contains { $0.emotionScore != nil }
    }

    var emotionGroupStats: [EmotionGroupStat] {
        guard hasEmotionData else { return [] }
        let jMap = journalMap

        var groups: [Int: [(pnl: Double, returnPct: Double)]] = [:]
        for inv in filteredInvestments {
            guard let j = jMap[inv.id], let score = j.emotionScore else { continue }
            let pnl = inv.realizedProfitLoss(fees: fees)
            let ret = inv.realizedReturnPercentage(fees: fees)
            groups[score, default: []].append((pnl, ret))
        }

        return (1...5).compactMap { score -> EmotionGroupStat? in
            guard let data = groups[score], !data.isEmpty else { return nil }
            let wins = data.filter { $0.pnl > 0 }.count
            let avgRet = data.map(\.returnPct).reduce(0, +) / Double(data.count)
            return EmotionGroupStat(id: score, tradeCount: data.count, winCount: wins, avgReturnPct: avgRet)
        }
    }

    // MARK: - Section 5：紀律分析

    var hasRMultipleData: Bool {
        filteredJournals.contains { $0.rMultiple != nil }
    }

    var averageR: Double? {
        let rs = filteredJournals.compactMap(\.rMultiple)
        guard !rs.isEmpty else { return nil }
        return rs.reduce(0, +) / Double(rs.count)
    }

    var disciplinedStopRatio: Double? {
        let losses = filteredJournals.filter { ($0.rMultiple ?? 0) < 0 }
        guard !losses.isEmpty else { return nil }
        let disciplined = losses.filter { ($0.rMultiple ?? 0) >= -1 }.count
        return Double(disciplined) / Double(losses.count)
    }

    var panicSellRatio: Double? {
        let negativeR = filteredJournals.filter { ($0.rMultiple ?? 0) < 0 }
        guard !negativeR.isEmpty else { return nil }
        let panicCount = negativeR.filter { $0.exitReason == ExitReasonOption.panicSell.rawValue }.count
        return Double(panicCount) / Double(negativeR.count)
    }

    var rDistributionBuckets: [RBucket] {
        let rs = filteredJournals.compactMap(\.rMultiple)
        guard !rs.isEmpty else { return [] }

        let defs: [(label: String, match: (Double) -> Bool, positive: Bool)] = [
            ("< -2R",    { $0 < -2 },              false),
            ("-2R~-1R",  { $0 >= -2 && $0 < -1 },  false),
            ("-1R~0R",   { $0 >= -1 && $0 < 0 },   false),
            ("0R~1R",    { $0 >= 0 && $0 < 1 },    true),
            ("1R~2R",    { $0 >= 1 && $0 < 2 },    true),
            ("> 2R",     { $0 >= 2 },               true),
        ]

        return defs.compactMap { def in
            let count = rs.filter(def.match).count
            guard count > 0 else { return nil }
            return RBucket(id: def.label, label: def.label, count: count, isPositive: def.positive)
        }
    }

    var exitReasonStats: [ExitReasonStat] {
        let reasoned = filteredJournals.filter { !$0.exitReason.isEmpty }
        guard !reasoned.isEmpty else { return [] }

        let grouped = Dictionary(grouping: reasoned) { $0.exitReason }
        var result: [ExitReasonStat] = []

        for option in ExitReasonOption.allCases {
            let count = grouped[option.rawValue]?.count ?? 0
            if count > 0 {
                result.append(ExitReasonStat(id: option.rawValue, label: option.rawValue,
                                             count: count, icon: option.icon))
            }
        }
        // 自訂理由（不在 ExitReasonOption 中的）
        for (reason, trades) in grouped where ExitReasonOption(rawValue: reason) == nil {
            result.append(ExitReasonStat(id: reason, label: reason, count: trades.count, icon: "pencil"))
        }
        return result.sorted { $0.count > $1.count }
    }

    // MARK: - Section 6：標的排行

    private var tickerStats: [DashboardTickerStat] {
        var grouped: [String: [Investment]] = [:]
        for inv in filteredInvestments {
            let key = StockMapping.normalizedSymbol(for: inv.ticker)
            grouped[key, default: []].append(inv)
        }
        return grouped.map { ticker, investments in
            let pls = investments.map { $0.realizedProfitLoss(fees: fees) }
            let total = pls.reduce(0, +)
            let wins = pls.filter { $0 > 0 }.count
            return DashboardTickerStat(
                id: ticker,
                displayName: StockMapping.displayName(for: ticker),
                tradeCount: investments.count,
                totalPL: total,
                winCount: wins
            )
        }
    }

    var topProfitTickers: [DashboardTickerStat] {
        Array(tickerStats.filter { $0.totalPL > 0 }.sorted { $0.totalPL > $1.totalPL }.prefix(5))
    }

    var topLossTickers: [DashboardTickerStat] {
        Array(tickerStats.filter { $0.totalPL < 0 }.sorted { $0.totalPL < $1.totalPL }.prefix(5))
    }

    var mostTradedTickers: [DashboardTickerStat] {
        Array(tickerStats.sorted { $0.tradeCount > $1.tradeCount }.prefix(5))
    }

    // MARK: - Format Helpers

    func formatPL(_ v: Double) -> String {
        if abs(v) >= 10000 {
            return String(format: "%@%.1f萬", v >= 0 ? "+" : "", v / 10000)
        }
        return String(format: "%@$%.0f", v >= 0 ? "+" : "", v)
    }
}
