import Foundation
import SwiftData
import Observation

@Observable
final class SoldRecordsViewModel {
    // MARK: - Data (bridged from @Query)
    var allSoldInvestments: [Investment] = []

    // MARK: - State
    var selectedFilter: DateFilterOption = .all
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var customEndDate: Date = Date()
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

    // MARK: - 月度損益

    struct MonthlyPL: Identifiable {
        let id: String      // "2026-01" 格式
        let label: String   // "1月" 格式
        let profit: Double  // 獲利總額（正值）
        let loss: Double    // 虧損總額（負值）
        var net: Double { profit + loss }
    }

    var monthlyPLData: [MonthlyPL] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        let labelDf = DateFormatter()
        labelDf.dateFormat = "M月"

        var grouped: [String: (profit: Double, loss: Double, date: Date)] = [:]
        for inv in filteredInvestments {
            guard let sellDate = inv.sellDate else { continue }
            let key = df.string(from: sellDate)
            let pl = inv.realizedProfitLoss(fees: fees)
            var entry = grouped[key] ?? (profit: 0, loss: 0, date: sellDate)
            if pl >= 0 {
                entry.profit += pl
            } else {
                entry.loss += pl
            }
            entry.date = sellDate
            grouped[key] = entry
        }

        return grouped
            .sorted { $0.key < $1.key }
            .map { key, val in
                MonthlyPL(
                    id: key,
                    label: labelDf.string(from: val.date),
                    profit: val.profit,
                    loss: val.loss
                )
            }
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
