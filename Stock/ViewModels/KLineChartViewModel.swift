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
    let investment: Investment
    let journal: TradeJournal

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

    private static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let labelDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(investment: Investment, journal: TradeJournal) {
        self.investment = investment
        self.journal = journal
    }

    // MARK: - Computed Markers

    var buyMarker: (date: Date, price: Double) {
        (investment.buyDate, investment.buyPrice)
    }

    var sellMarker: (date: Date, price: Double)? {
        guard investment.isClosed,
              let sellDate = investment.sellDate,
              let sellPrice = investment.sellPrice else { return nil }
        return (sellDate, sellPrice)
    }

    var stopLossPrice: Double? {
        journal.initialStopLoss
    }

    var plannedEntryPrice: Double? {
        guard let planned = journal.plannedEntryPrice,
              abs(planned - investment.buyPrice) > 0.01 else { return nil }
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
        let endDate = investment.sellDate ?? Date()

        // 買入日前推 45 日曆日（約 30 個交易日）
        let startDate = calendar.date(byAdding: .day, value: -45, to: investment.buyDate) ?? investment.buyDate

        // 上限 1 年
        let oneYearBefore = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        let clampedStart = max(startDate, oneYearBefore)

        let fromStr = Self.apiDateFormatter.string(from: clampedStart)
        let toStr = Self.apiDateFormatter.string(from: endDate)

        let symbol = StockMapping.resolve(investment.ticker).symbol

        do {
            let response = try await StockService.shared.fetchHistoricalCandles(
                symbol: symbol,
                from: fromStr,
                to: toStr
            )

            let items = response.data.compactMap { candle -> CandleItem? in
                guard let date = Self.apiDateFormatter.date(from: candle.date) else { return nil }
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
        let closes = candles.map(\.close)
        ma5 = TechnicalIndicators.sma(closes: closes, period: 5)
        ma20 = TechnicalIndicators.sma(closes: closes, period: 20)
        volumeMax = candles.map(\.volume).max() ?? 0
    }
}
