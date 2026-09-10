import Foundation
import Observation

/// K 線圖資料項目
struct CandleItem: Identifiable, Sendable {
    let id: String
    let date: Date
    let dateLabel: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

/// K 線圖 ViewModel：管理歷史 K 線資料取得、日期範圍、互動狀態
@Observable
final class KLineChartViewModel {
    let investment: Investment?
    let journal: TradeJournal?
    let ticker: String
    /// 庫存總覽用：多筆買入標記
    let portfolioGroup: PortfolioGroup?

    var candles: [CandleItem] = []
    var isLoading = false
    var errorMessage: String? = nil
    var selectedCandleIndex: Int? = nil

    // MARK: - Indicator Toggle State
    var showMA: Bool = true
    var showVolume: Bool = true

    // MARK: - Computed Indicator Data
    var ma5: [Double?] = []
    var ma20: [Double?] = []
    var volumeMax: Int = 0

    // MARK: - Date Formatters

    private static let labelDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// 交易日誌用：帶買賣標記
    init(investment: Investment, journal: TradeJournal) {
        self.investment = investment
        self.journal = journal
        self.ticker = investment.ticker
        self.portfolioGroup = nil
    }

    /// 庫存總覽用：帶多筆買入標記
    init(group: PortfolioGroup) {
        self.investment = nil
        self.journal = nil
        self.ticker = group.ticker
        self.portfolioGroup = group
    }

    // MARK: - Computed Markers

    var buyMarker: (date: Date, price: Double)? {
        guard let inv = investment else { return nil }
        return (inv.buyDate, inv.buyPrice)
    }

    /// 庫存總覽用：多筆買入標記
    var buyMarkers: [(date: Date, price: Double)] {
        if let group = portfolioGroup {
            return group.investments.map { ($0.buyDate, $0.buyPrice) }
        }
        if let inv = investment {
            return [(inv.buyDate, inv.buyPrice)]
        }
        return []
    }

    var sellMarker: (date: Date, price: Double)? {
        guard let inv = investment, inv.isClosed,
              let sellDate = inv.sellDate,
              let sellPrice = inv.sellPrice else { return nil }
        return (sellDate, sellPrice)
    }

    var stopLossPrice: Double? {
        journal?.initialStopLoss
    }

    var plannedEntryPrice: Double? {
        guard let inv = investment,
              let planned = journal?.plannedEntryPrice,
              abs(planned - inv.buyPrice) > 0.01 else { return nil }
        return planned
    }

    var selectedCandle: CandleItem? {
        guard let idx = selectedCandleIndex,
              idx >= 0, idx < candles.count else { return nil }
        return candles[idx]
    }

    // MARK: - Data Loading

    func loadCandles() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let calendar = Calendar.current
        let endDate: Date
        let clampedStart: Date

        if let inv = investment {
            // 交易日誌模式：買入日前推 45 天 → 賣出日/今日
            endDate = inv.sellDate ?? Date()
            let startDate = calendar.date(byAdding: .day, value: -45, to: inv.buyDate) ?? inv.buyDate
            let oneYearBefore = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
            clampedStart = max(startDate, oneYearBefore)
        } else if let group = portfolioGroup,
                  let earliestBuyDate = group.investments.map(\.buyDate).min() {
            // 庫存總覽模式：最早買入日前推 45 天 → 今日
            endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -45, to: earliestBuyDate) ?? earliestBuyDate
            let oneYearBefore = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
            clampedStart = max(startDate, oneYearBefore)
        } else {
            // 僅 ticker 模式：近 6 個月
            endDate = Date()
            clampedStart = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        }

        let fromStr = AppDateFormatter.apiDate.string(from: clampedStart)
        let toStr = AppDateFormatter.apiDate.string(from: endDate)

        let symbol = StockMapping.resolve(ticker).symbol

        do {
            let response = try await StockService.shared.fetchHistoricalCandles(
                symbol: symbol,
                from: fromStr,
                to: toStr
            )

            let items = response.data.compactMap { candle -> CandleItem? in
                guard let date = AppDateFormatter.apiDate.date(from: candle.date) else { return nil }
                return CandleItem(
                    id: candle.date,
                    date: date,
                    dateLabel: Self.labelDateFormatter.string(from: date),
                    open: candle.open,
                    high: candle.high,
                    low: candle.low,
                    close: candle.close,
                    volume: candle.volume
                )
            }
            .sorted { $0.date < $1.date }

            candles = items
            computeIndicators()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Indicator Computation

    private func computeIndicators() {
        let settings = TechnicalSettings.load()
        let closes = candles.map(\.close)
        ma5 = TechnicalIndicators.sma(closes: closes, period: settings.maShortPeriod)
        ma20 = TechnicalIndicators.sma(closes: closes, period: settings.maLongPeriod)
        volumeMax = candles.map(\.volume).max() ?? 0
    }
}
