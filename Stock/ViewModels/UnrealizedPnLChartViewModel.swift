import Foundation
import Observation

// MARK: - 資料結構

/// 未實現損益走勢資料點
struct UnrealizedPnLPoint: Identifiable {
    let id = UUID()
    let date: Date
    let totalUnrealizedPnL: Double
}

/// 未實現損益摘要
struct UnrealizedPnLSummary {
    let currentPnL: Double      // 當前未實現損益
    let peakPnL: Double         // 區間最高
    let troughPnL: Double       // 區間最低
    let positionCount: Int      // 持有檔數
    let totalCost: Double       // 投入成本
    let returnPct: Double       // 報酬率 %

    static let empty = UnrealizedPnLSummary(
        currentPnL: 0, peakPnL: 0, troughPnL: 0,
        positionCount: 0, totalCost: 0, returnPct: 0
    )
}

/// 損益走勢圖分頁
enum PnLSegment: String, CaseIterable, Identifiable {
    case realized = "已實現"
    case unrealized = "未實現"
    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
final class UnrealizedPnLChartViewModel {
    // MARK: - Data (bridged from @Query)
    var openInvestments: [Investment] = []

    // MARK: - State
    var selectedFilter: DateFilterOption = .all
    var customStartDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    var customEndDate: Date = Date()
    var isLoading: Bool = false

    // MARK: - Internal
    /// ticker → (dateString → closePrice)
    private var candleLookup: [String: [String: Double]] = [:]
    /// 所有交易日排序（yyyy-MM-dd）
    private var allTradingDates: [String] = []
    /// 即時報價 ticker → price
    private var currentPrices: [String: Double] = [:]
    /// 是否已載入資料
    private var hasLoaded = false

    private static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - 圖表資料

    var chartData: [UnrealizedPnLPoint] {
        guard hasLoaded else { return [] }

        let investments = openInvestments.filter { !$0.isClosed && $0.quantity > 0 }
        guard !investments.isEmpty else { return [] }

        let fees = TradingFeeSettings.load()
        let calendar = Calendar.current
        let formatter = Self.apiDateFormatter

        // 建立每日未實現損益
        var points: [UnrealizedPnLPoint] = []

        for dateStr in allTradingDates {
            guard let date = formatter.date(from: dateStr) else { continue }

            var dayPnL: Double = 0
            var hasData = false

            for inv in investments {
                let buyDateStr = formatter.string(from: inv.buyDate)
                guard buyDateStr <= dateStr else { continue }

                let ticker = inv.ticker
                guard let closePrice = candleLookup[ticker]?[dateStr] else { continue }

                let gross = (closePrice - inv.buyPrice) * inv.quantity
                let fee = fees.totalFees(buyPrice: inv.buyPrice, sellPrice: closePrice, quantity: inv.quantity)
                dayPnL += gross - fee
                hasData = true
            }

            if hasData {
                points.append(UnrealizedPnLPoint(date: calendar.startOfDay(for: date), totalUnrealizedPnL: dayPnL))
            }
        }

        // 附加今日即時價格點
        if !currentPrices.isEmpty {
            let today = calendar.startOfDay(for: Date())
            var todayPnL: Double = 0
            var hasTodayData = false

            for inv in investments {
                guard inv.buyDate <= Date() else { continue }
                let ticker = inv.ticker
                guard let price = currentPrices[ticker], price > 0 else { continue }

                let gross = (price - inv.buyPrice) * inv.quantity
                let fee = fees.totalFees(buyPrice: inv.buyPrice, sellPrice: price, quantity: inv.quantity)
                todayPnL += gross - fee
                hasTodayData = true
            }

            if hasTodayData {
                // 移除重複的今日點（若 K 線資料已含今日）
                if let lastPoint = points.last, calendar.isDate(lastPoint.date, inSameDayAs: today) {
                    points.removeLast()
                }
                points.append(UnrealizedPnLPoint(date: today, totalUnrealizedPnL: todayPnL))
            }
        }

        // 套用日期篩選
        return filterPoints(points)
    }

    // MARK: - 摘要統計

    var summary: UnrealizedPnLSummary {
        let data = chartData
        let investments = openInvestments.filter { !$0.isClosed && $0.quantity > 0 }
        guard !data.isEmpty, !investments.isEmpty else { return .empty }

        let currentPnL = data.last?.totalUnrealizedPnL ?? 0
        let peakPnL = data.map(\.totalUnrealizedPnL).max() ?? 0
        let troughPnL = data.map(\.totalUnrealizedPnL).min() ?? 0

        let tickers = Set(investments.map(\.ticker))
        let totalCost = investments.reduce(0.0) { $0 + $1.buyPrice * $1.quantity }
        let returnPct = totalCost > 0 ? currentPnL / totalCost * 100 : 0

        return UnrealizedPnLSummary(
            currentPnL: currentPnL,
            peakPnL: peakPnL,
            troughPnL: troughPnL,
            positionCount: tickers.count,
            totalCost: totalCost,
            returnPct: returnPct
        )
    }

    // MARK: - 載入資料

    @MainActor
    func loadCandleData() async {
        guard !openInvestments.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let investments = openInvestments.filter { !$0.isClosed && $0.quantity > 0 }
        let tickers = Array(Set(investments.map(\.ticker)))
        guard !tickers.isEmpty else { return }

        let formatter = Self.apiDateFormatter
        let todayStr = formatter.string(from: Date())

        // 計算最早買入日
        let earliestBuyDate = investments.map(\.buyDate).min() ?? Date()
        let earliestStr = formatter.string(from: earliestBuyDate)

        // Step 1: 嘗試讀取 K 線快取
        var cachedCandles: [String: CandleCacheData]? = nil
        let cacheDateFmt = DateFormatter()
        cacheDateFmt.dateFormat = "yyyyMMdd"
        cacheDateFmt.locale = Locale(identifier: "en_US_POSIX")
        let todayCacheStr = cacheDateFmt.string(from: Date())

        if let cachedDate = UserDefaults.standard.string(forKey: CandleCacheKeys.date),
           cachedDate == todayCacheStr,
           let data = UserDefaults.standard.data(forKey: CandleCacheKeys.data),
           let cached = try? JSONDecoder().decode([String: CandleCacheData].self, from: data) {
            cachedCandles = cached
        }

        // Step 2: 判斷哪些 ticker 需要補抓（快取不夠長或無快取）
        var needFetch: [(ticker: String, symbol: String, from: String)] = []
        var mergedCandles: [String: CandleCacheData] = [:]

        for ticker in tickers {
            if let cached = cachedCandles?[ticker] {
                mergedCandles[ticker] = cached
                // 檢查是否涵蓋最早買入日
                if let firstDate = cached.dates.first, firstDate <= earliestStr {
                    continue  // 快取足夠
                }
            }
            // 需要抓取
            let symbol = StockMapping.resolve(ticker).symbol
            needFetch.append((ticker, symbol, earliestStr))
        }

        // Step 3: 補抓缺少的 K 線
        if !needFetch.isEmpty {
            struct FetchResult: Sendable {
                let ticker: String
                let candle: CandleCacheData
            }

            let results = await withTaskGroup(of: FetchResult?.self) { group in
                for (ticker, symbol, fromStr) in needFetch {
                    group.addTask {
                        do {
                            let response = try await StockService.shared.fetchHistoricalCandles(
                                symbol: symbol, from: fromStr, to: todayStr
                            )
                            let sorted = response.data.sorted { $0.date < $1.date }
                            return FetchResult(
                                ticker: ticker,
                                candle: CandleCacheData(
                                    dates: sorted.map(\.date),
                                    closes: sorted.map(\.close),
                                    highs: sorted.map(\.high),
                                    lows: sorted.map(\.low),
                                    volumes: sorted.map(\.volume)
                                )
                            )
                        } catch {
                            return nil
                        }
                    }
                }
                var collected: [FetchResult] = []
                for await result in group {
                    if let result { collected.append(result) }
                }
                return collected
            }

            for result in results {
                mergedCandles[result.ticker] = result.candle
            }
        }

        // Step 4: 同時抓即時報價
        var tickerToSymbol: [String: String] = [:]
        for ticker in tickers {
            tickerToSymbol[ticker] = StockMapping.resolve(ticker).symbol
        }
        let apiSymbols = Array(Set(tickerToSymbol.values))
        let quoteResults = await StockService.shared.fetchQuotes(symbols: apiSymbols)

        for (ticker, apiSymbol) in tickerToSymbol {
            if let result = quoteResults[apiSymbol] {
                currentPrices[ticker] = result.lastPrice
            }
        }

        // Step 5: 建立 candleLookup 與 allTradingDates
        var dateSet: Set<String> = []
        for (ticker, candle) in mergedCandles {
            var lookup: [String: Double] = [:]
            for (i, dateStr) in candle.dates.enumerated() {
                lookup[dateStr] = candle.closes[i]
                dateSet.insert(dateStr)
            }
            candleLookup[ticker] = lookup
        }
        allTradingDates = dateSet.sorted()

        hasLoaded = true
    }

    // MARK: - 日期篩選

    private func filterPoints(_ points: [UnrealizedPnLPoint]) -> [UnrealizedPnLPoint] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedFilter {
        case .all:
            return points
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return points }
            return points.filter { $0.date >= weekAgo }
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return points }
            return points.filter { $0.date >= monthAgo }
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            guard let firstDay = calendar.date(from: comps) else { return points }
            return points.filter { $0.date >= firstDay }
        case .custom:
            let start = calendar.startOfDay(for: customStartDate)
            guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate)) else {
                return points
            }
            return points.filter { $0.date >= start && $0.date < end }
        }
    }
}
