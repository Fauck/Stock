import Foundation
import Observation

// MARK: - 資料結構

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

/// 月度/季度切換
enum PeriodMode: String, CaseIterable, Identifiable {
    case monthly = "月度"
    case quarterly = "季度"

    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
final class PnLChartViewModel {
    // MARK: - Data (bridged from @Query)
    var allSoldInvestments: [Investment] = []

    // MARK: - State
    var selectedFilter: DateFilterOption = .all
    var customStartDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    var customEndDate: Date = Date()
    var periodMode: PeriodMode = .monthly

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

    // MARK: - 累計損益曲線資料

    var cumulativeData: [CumulativePoint] {
        let fees = TradingFeeSettings.load()
        let sorted = filteredInvestments
            .sorted { ($0.sellDate ?? .distantPast) < ($1.sellDate ?? .distantPast) }

        // 同日期合併
        var dailyMap: [(date: Date, pnl: Double)] = []
        let calendar = Calendar.current

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

    // MARK: - 月度/季度損益柱狀圖資料

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
        }

        let labelFormatter = DateFormatter()
        labelFormatter.locale = Locale(identifier: "zh_TW")

        return grouped.compactMap { comps, investments -> PeriodPnL? in
            guard let year = comps.year, let month = comps.month else { return nil }
            guard let periodStart = calendar.date(from: comps) else { return nil }

            let label: String
            switch periodMode {
            case .monthly:
                label = String(format: "%d/%02d", year, month)
            case .quarterly:
                let q = (month - 1) / 3 + 1
                label = "\(year) Q\(q)"
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

    // MARK: - 摘要統計

    var summary: PnLSummary {
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
}
