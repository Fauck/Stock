import Foundation
import SwiftData
import Observation

// MARK: - 圖表資料結構

/// 累計損益曲線資料點
struct CumulativePoint: Identifiable {
    let id = UUID()
    let date: Date
    let cumulativePnL: Double
}

/// 月度/季度損益彙總
struct PeriodPnL: Identifiable {
    let id = UUID()
    let periodStart: Date
    let label: String
    let pnl: Double
    let tradeCount: Int
    let winCount: Int
}

/// 損益摘要統計
struct PnLSummary {
    let totalPnL: Double
    let tradeCount: Int
    let winRate: Double
    let bestTrade: Double
    let worstTrade: Double
    let avgPnL: Double

    static let empty = PnLSummary(
        totalPnL: 0, tradeCount: 0, winRate: 0,
        bestTrade: 0, worstTrade: 0, avgPnL: 0
    )
}

/// 損益週期模式（月/季/年）
enum PeriodMode: String, CaseIterable, Identifiable {
    case monthly   = "月"
    case quarterly = "季"
    case yearly    = "年"

    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
final class SoldRecordsViewModel {
    // MARK: - Data (bridged from @Query)
    var allSoldInvestments: [Investment] = []

    // MARK: - State
    var selectedFilter: DateFilterOption = .all
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var customEndDate: Date = Date()
    var periodMode: PeriodMode = .monthly
    var investmentToDelete: Investment?
    var showingDeleteAlert: Bool = false

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

    // MARK: - P&L Summary

    var totalPL: Double {
        let fees = TradingFeeSettings.load()
        return filteredInvestments.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) }
    }

    var totalSellAmount: Double {
        filteredInvestments.reduce(0.0) { sum, inv in
            guard let sp = inv.sellPrice, let sq = inv.sellQuantity else { return sum }
            return sum + sp * sq
        }
    }

    var totalCostAmount: Double {
        filteredInvestments.reduce(0.0) { sum, inv in
            guard let sq = inv.sellQuantity else { return sum }
            return sum + inv.buyPrice * sq
        }
    }

    var recordCount: Int {
        filteredInvestments.count
    }

    // MARK: - 累計損益曲線

    var cumulativeData: [CumulativePoint] {
        let fees = TradingFeeSettings.load()
        let sorted = filteredInvestments
            .sorted { ($0.sellDate ?? .distantPast) < ($1.sellDate ?? .distantPast) }

        let calendar = Calendar.current
        var dailyMap: [(date: Date, pnl: Double)] = []

        for inv in sorted {
            guard let sellDate = inv.sellDate else { continue }
            let day = calendar.startOfDay(for: sellDate)
            let pnl = inv.realizedProfitLoss(fees: fees)

            if let lastIndex = dailyMap.indices.last, calendar.isDate(dailyMap[lastIndex].date, inSameDayAs: day) {
                dailyMap[lastIndex].pnl += pnl
            } else {
                dailyMap.append((date: day, pnl: pnl))
            }
        }

        var cumulative: Double = 0
        return dailyMap.map { entry in
            cumulative += entry.pnl
            return CumulativePoint(date: entry.date, cumulativePnL: cumulative)
        }
    }

    // MARK: - 月度/季度損益

    var periodData: [PeriodPnL] {
        let fees = TradingFeeSettings.load()
        let calendar = Calendar.current

        let grouped: [DateComponents: [Investment]]

        switch periodMode {
        case .monthly:
            grouped = Dictionary(grouping: filteredInvestments) { inv in
                guard let sellDate = inv.sellDate else { return DateComponents() }
                return calendar.dateComponents([.year, .month], from: sellDate)
            }
        case .quarterly:
            grouped = Dictionary(grouping: filteredInvestments) { inv in
                guard let sellDate = inv.sellDate else { return DateComponents() }
                let comps = calendar.dateComponents([.year, .month], from: sellDate)
                let quarter = ((comps.month ?? 1) - 1) / 3
                return DateComponents(year: comps.year, month: quarter * 3 + 1)
            }
        case .yearly:
            grouped = Dictionary(grouping: filteredInvestments) { inv in
                guard let sellDate = inv.sellDate else { return DateComponents() }
                return calendar.dateComponents([.year], from: sellDate)
            }
        }

        return grouped.compactMap { comps, investments -> PeriodPnL? in
            guard let year = comps.year else { return nil }
            guard let periodStart = calendar.date(from: comps) else { return nil }

            let label: String
            switch periodMode {
            case .monthly:
                guard let month = comps.month else { return nil }
                label = String(format: "%d/%02d", year, month)
            case .quarterly:
                guard let month = comps.month else { return nil }
                let q = (month - 1) / 3 + 1
                label = "\(year) Q\(q)"
            case .yearly:
                label = "\(year)"
            }

            let pnl = investments.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) }
            let winCount = investments.filter { $0.realizedProfitLoss(fees: fees) > 0 }.count

            return PeriodPnL(
                periodStart: periodStart,
                label: label,
                pnl: pnl,
                tradeCount: investments.count,
                winCount: winCount
            )
        }
        .sorted { $0.periodStart < $1.periodStart }
    }

    // MARK: - 績效摘要

    var pnlSummary: PnLSummary {
        let fees = TradingFeeSettings.load()
        let pnls = filteredInvestments.map { $0.realizedProfitLoss(fees: fees) }
        guard !pnls.isEmpty else { return .empty }

        let totalPnL = pnls.reduce(0, +)
        let winCount = pnls.filter { $0 > 0 }.count
        let winRate = Double(winCount) / Double(pnls.count) * 100

        return PnLSummary(
            totalPnL: totalPnL,
            tradeCount: pnls.count,
            winRate: winRate,
            bestTrade: pnls.max() ?? 0,
            worstTrade: pnls.min() ?? 0,
            avgPnL: totalPnL / Double(pnls.count)
        )
    }

    // MARK: - 交易統計

    private var fees: TradingFeeSettings { TradingFeeSettings.load() }

    /// 獲利筆數
    var winCount: Int {
        filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) > 0 }.count
    }

    /// 虧損筆數
    var lossCount: Int {
        filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) < 0 }.count
    }

    /// 勝率
    var winRate: Double {
        guard recordCount > 0 else { return 0 }
        return Double(winCount) / Double(recordCount) * 100
    }

    /// 平均獲利金額（僅獲利筆）
    var avgProfit: Double {
        let wins = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) > 0 }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) } / Double(wins.count)
    }

    /// 平均虧損金額（僅虧損筆，回傳正值）
    var avgLoss: Double {
        let losses = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) < 0 }
        guard !losses.isEmpty else { return 0 }
        return abs(losses.reduce(0.0) { $0 + $1.realizedProfitLoss(fees: fees) } / Double(losses.count))
    }

    /// 盈虧比（平均獲利 / 平均虧損）
    var profitLossRatio: Double {
        guard avgLoss > 0 else { return 0 }
        return avgProfit / avgLoss
    }

    /// 最大連續虧損筆數
    var maxConsecutiveLosses: Int {
        var maxStreak = 0
        var currentStreak = 0
        // 按賣出日期排序
        let sorted = filteredInvestments.sorted { ($0.sellDate ?? .distantPast) < ($1.sellDate ?? .distantPast) }
        for inv in sorted {
            if inv.realizedProfitLoss(fees: fees) < 0 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        return maxStreak
    }

    /// 最大單筆虧損
    var maxSingleLoss: Double {
        let losses = filteredInvestments.map { $0.realizedProfitLoss(fees: fees) }
        return losses.min() ?? 0
    }

    /// 最大單筆獲利
    var maxSingleProfit: Double {
        let profits = filteredInvestments.map { $0.realizedProfitLoss(fees: fees) }
        return profits.max() ?? 0
    }

    /// 平均持有天數（獲利筆）
    var avgHoldingDaysWin: Int {
        let wins = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) > 0 }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0) { $0 + $1.holdingDays } / wins.count
    }

    /// 平均持有天數（虧損筆）
    var avgHoldingDaysLoss: Int {
        let losses = filteredInvestments.filter { $0.realizedProfitLoss(fees: fees) < 0 }
        guard !losses.isEmpty else { return 0 }
        return losses.reduce(0) { $0 + $1.holdingDays } / losses.count
    }

    // MARK: - 依標的彙總

    struct TickerSummary: Identifiable {
        let id: String  // ticker
        let displayName: String
        let tradeCount: Int
        let totalPL: Double
        let winCount: Int
        let winRate: Double
    }

    var tickerSummaries: [TickerSummary] {
        var grouped: [String: [Investment]] = [:]
        for inv in filteredInvestments {
            let key = StockMapping.normalizedSymbol(for: inv.ticker)
            grouped[key, default: []].append(inv)
        }

        return grouped.map { ticker, investments in
            let pls = investments.map { $0.realizedProfitLoss(fees: fees) }
            let total = pls.reduce(0, +)
            let wins = pls.filter { $0 > 0 }.count
            let rate = investments.isEmpty ? 0 : Double(wins) / Double(investments.count) * 100
            return TickerSummary(
                id: ticker,
                displayName: StockMapping.displayName(for: ticker),
                tradeCount: investments.count,
                totalPL: total,
                winCount: wins,
                winRate: rate
            )
        }
        .sorted { abs($0.totalPL) > abs($1.totalPL) }  // 按絕對損益排序
    }

    // MARK: - Actions

    func confirmDelete(_ investment: Investment) {
        investmentToDelete = investment
        showingDeleteAlert = true
    }

    var deleteErrorMessage: String? = nil
    var showingDeleteError: Bool = false

    func deleteConfirmed(context: ModelContext) {
        guard let investment = investmentToDelete else { return }
        do {
            try Investment.deleteInvestment(investment, context: context)
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
    }

    // MARK: - Formatting

    func formattedDate(_ date: Date) -> String {
        AppDateFormatter.slashDate.string(from: date)
    }
}
