import Foundation
import SwiftData
import Observation

@Observable
final class PortfolioListViewModel {
    // MARK: - Data (bridged from @Query)
    var investments: [Investment] = []

    // MARK: - State
    var currentPrices: [String: String] = [:]
    /// 昨日收盤價 [ticker: previousClose]
    var previousClosePrices: [String: Double] = [:]
    /// 當日漲跌點數 [ticker: change]
    var dailyChangePoints: [String: Double] = [:]
    /// 當日漲跌百分比 [ticker: changePercent]
    var dailyChangePercents: [String: Double] = [:]
    var expandedTicker: String?

    /// 技術指標信號 [ticker: SignalSummary]
    var technicalSignals: [String: TechnicalIndicators.SignalSummary] = [:]
    /// 是否正在載入技術指標
    var isFetchingSignals: Bool = false

    /// 52 週高低統計
    struct WeekStats: Sendable {
        let high52w: Double
        let low52w: Double
    }
    var weekStats: [String: WeekStats] = [:]
    var isFetchingWeekStats: Bool = false

    /// 買入後最高價 [ticker: highestPrice]（用於移動停利）
    var highSinceBuy: [String: Double] = [:]

    /// 三大法人買賣超 [ticker: InstitutionalSummary]
    var institutionalData: [String: StockService.InstitutionalSummary] = [:]
    var isFetchingInstitutional: Bool = false

    /// API 查到的中文名稱快取 [symbol: name]
    var stockNames: [String: String] = [:]

    /// 是否正在批次載入即時價格
    var isFetchingPrices: Bool = false

    // 單筆賣出
    var selectedInvestment: Investment?
    var showingSellSheet: Bool = false

    // 整批賣出
    var selectedGroup: PortfolioGroup?
    var showingGroupSellSheet: Bool = false

    // 個股分析 sheet
    var selectedGroupForDetail: PortfolioGroup? = nil
    var showingStockDetailSheet: Bool = false

    // 刪除
    var investmentToDelete: Investment?
    var showingDeleteAlert: Bool = false

    private var fetchTask: Task<Void, Never>?
    private var loadDataTask: Task<Void, Never>?

    // MARK: - 快取鍵
    private static let weekStatsCacheKey = "weekStatsCache"
    private static let weekStatsCacheDateKey = "weekStatsCacheDate"
    private static let institutionalCacheKey = "institutionalCache"
    private static let institutionalCacheDateKey = "institutionalCacheDate"

    // MARK: - Computed

    var groups: [PortfolioGroup] {
        PortfolioGroup.buildGroups(from: investments)
    }

    // MARK: - Portfolio Summary

    var totalCost: Double {
        investments.reduce(0.0) { $0 + $1.totalCost }
    }

    var totalMarketValue: Double {
        groups.reduce(0.0) { sum, group in
            guard let priceStr = currentPrices[group.ticker],
                  let price = Double(priceStr), price > 0 else { return sum }
            return sum + price * group.totalQuantity
        }
    }

    var hasAnyPrice: Bool {
        groups.contains { group in
            guard let priceStr = currentPrices[group.ticker],
                  let price = Double(priceStr) else { return false }
            return price > 0
        }
    }

    /// 總損益（扣除手續費與交易稅）
    var totalPL: Double {
        let fees = TradingFeeSettings.load()
        return groups.reduce(0.0) { sum, group in
            guard let priceStr = currentPrices[group.ticker],
                  let price = Double(priceStr), price > 0 else { return sum }
            return sum + group.unrealizedProfitLoss(currentPrice: price, fees: fees)
        }
    }

    /// 總報酬率（百分比，扣除手續費與交易稅）
    var totalReturnPct: Double {
        let fees = TradingFeeSettings.load()
        let costWithFee = groups.reduce(0.0) { sum, group in
            sum + group.totalInvested + fees.buyCommission(price: group.weightedAverageCost, quantity: group.totalQuantity)
        }
        guard costWithFee > 0 else { return 0 }
        return totalPL / costWithFee * 100
    }

    /// 本日總損益增減 = 今日未實現損益 - 昨日未實現損益
    /// 昨日未實現損益 = Σ (previousClose - avgCost) × qty
    /// 今日未實現損益 = Σ (currentPrice - avgCost) × qty
    /// 差值 = Σ (currentPrice - previousClose) × qty
    var totalDailyPLChange: Double? {
        var total: Double = 0
        var hasAny = false
        for group in groups {
            guard let priceStr = currentPrices[group.ticker],
                  let price = Double(priceStr), price > 0,
                  let prevClose = previousClosePrices[group.ticker], prevClose > 0 else { continue }
            hasAny = true
            total += (price - prevClose) * group.totalQuantity
        }
        return hasAny ? total : nil
    }

    /// 單一標的本日損益增減
    func dailyPLChange(for ticker: String, quantity: Double) -> Double? {
        guard let priceStr = currentPrices[ticker],
              let price = Double(priceStr), price > 0,
              let prevClose = previousClosePrices[ticker], prevClose > 0 else { return nil }
        return (price - prevClose) * quantity
    }

    // MARK: - Group Helpers

    func isExpanded(_ ticker: String) -> Bool {
        expandedTicker == ticker
    }

    func toggleExpanded(_ ticker: String) {
        expandedTicker = expandedTicker == ticker ? nil : ticker
    }

    func currentPrice(for ticker: String) -> Double? {
        guard let str = currentPrices[ticker], let p = Double(str), p > 0 else { return nil }
        return p
    }

    func priceBinding(for ticker: String) -> String {
        currentPrices[ticker] ?? ""
    }

    func setPrice(_ value: String, for ticker: String) {
        currentPrices[ticker] = value
    }

    /// 取得股票的顯示名稱：優先 API 名稱 → 本地字典 → 原始代號
    /// 自動去除 * 等標記
    func displayName(for ticker: String) -> String {
        if let name = stockNames[ticker] {
            return name.replacingOccurrences(of: "*", with: "")
        }
        if let name = StockMapping.cleanName(for: ticker) { return name }
        return ticker
    }

    // MARK: - 即時價格載入

    /// 批次載入所有持有標的的即時報價
    func fetchAllPrices() {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            isFetchingPrices = true

            // 將 ticker 解析為 API 可查詢的代號
            // 例如：使用者之前可能存了 "台積電" 而非 "2330"
            var tickerToSymbol: [String: String] = [:]
            for ticker in tickers {
                let resolved = StockMapping.resolve(ticker)
                tickerToSymbol[ticker] = resolved.symbol
            }

            let apiSymbols = Array(Set(tickerToSymbol.values))
            let results = await StockService.shared.fetchQuotes(symbols: apiSymbols)

            guard !Task.isCancelled else { return }

            // 將結果映射回原始 ticker
            for (ticker, apiSymbol) in tickerToSymbol {
                if let result = results[apiSymbol] {
                    currentPrices[ticker] = String(format: "%.2f", result.lastPrice)
                    if let prevClose = result.previousClose, prevClose > 0 {
                        previousClosePrices[ticker] = prevClose
                    }
                    if let change = result.change {
                        dailyChangePoints[ticker] = change
                    }
                    if let changePct = result.changePercent {
                        dailyChangePercents[ticker] = changePct
                    }
                    let cleanName = result.name.replacingOccurrences(of: "*", with: "")
                    stockNames[ticker] = cleanName
                    StockMapping.cache(symbol: apiSymbol, name: result.name)
                }
            }
            isFetchingPrices = false
        }
    }

    // MARK: - 統一載入（分優先級）

    /// 分優先級載入所有資料：
    /// 1. 即時報價（最高優先，影響卡片核心數字）
    /// 2. 即時價完成後 → 技術指標 + 52 週統計 + 法人 並行載入
    /// forceRefresh = true 時會忽略快取
    func loadData(forceRefresh: Bool = false) {
        loadDataTask?.cancel()
        loadDataTask = Task { @MainActor in
            // Phase 1：即時報價
            await fetchAllPricesAsync()

            guard !Task.isCancelled else { return }

            // Phase 2：次要資料並行載入
            async let signalsTask: () = fetchTechnicalSignalsAsync()
            async let weekTask: () = fetchWeekStatsIfNeeded(forceRefresh: forceRefresh)
            async let instTask: () = fetchInstitutionalIfNeeded(forceRefresh: forceRefresh)
            _ = await (signalsTask, weekTask, instTask)
        }
    }

    /// 可 await 的即時報價載入
    private func fetchAllPricesAsync() async {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        isFetchingPrices = true

        var tickerToSymbol: [String: String] = [:]
        for ticker in tickers {
            let resolved = StockMapping.resolve(ticker)
            tickerToSymbol[ticker] = resolved.symbol
        }

        let apiSymbols = Array(Set(tickerToSymbol.values))
        let results = await StockService.shared.fetchQuotes(symbols: apiSymbols)

        guard !Task.isCancelled else { return }

        for (ticker, apiSymbol) in tickerToSymbol {
            if let result = results[apiSymbol] {
                currentPrices[ticker] = String(format: "%.2f", result.lastPrice)
                if let prevClose = result.previousClose, prevClose > 0 {
                    previousClosePrices[ticker] = prevClose
                }
                if let change = result.change {
                    dailyChangePoints[ticker] = change
                }
                if let changePct = result.changePercent {
                    dailyChangePercents[ticker] = changePct
                }
                let cleanName = result.name.replacingOccurrences(of: "*", with: "")
                stockNames[ticker] = cleanName
                StockMapping.cache(symbol: apiSymbol, name: result.name)
            }
        }
        isFetchingPrices = false
    }

    /// 可 await 的技術指標載入
    private func fetchTechnicalSignalsAsync() async {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        isFetchingSignals = true
        let settings = TechnicalSettings.load()

        let calendar = Calendar.current
        let today = Date()
        let defaultFromDate = calendar.date(byAdding: .day, value: -60, to: today) ?? today

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let defaultFromStr = formatter.string(from: defaultFromDate)
        let toStr = formatter.string(from: today)

        var tickerSymbols: [(ticker: String, symbol: String, fromStr: String)] = []
        for ticker in tickers {
            let symbol = StockMapping.resolve(ticker).symbol
            var fromStr = defaultFromStr
            if let group = groups.first(where: { $0.ticker == ticker }),
               let earliest = group.investments.map(\.buyDate).min() {
                let earliestStr = formatter.string(from: earliest)
                if earliestStr < defaultFromStr {
                    fromStr = earliestStr
                }
            }
            tickerSymbols.append((ticker, symbol, fromStr))
        }

        struct CandleResult: Sendable {
            let ticker: String
            let dates: [String]
            let closes: [Double]
            let highs: [Double]
            let lows: [Double]
            let volumes: [Int]
        }

        let results = await withTaskGroup(of: CandleResult?.self) { group in
            for (ticker, symbol, tickerFromStr) in tickerSymbols {
                group.addTask {
                    do {
                        let response = try await StockService.shared.fetchHistoricalCandles(
                            symbol: symbol, from: tickerFromStr, to: toStr
                        )
                        let sorted = response.data.sorted { $0.date < $1.date }
                        return CandleResult(
                            ticker: ticker,
                            dates: sorted.map(\.date),
                            closes: sorted.map(\.close),
                            highs: sorted.map(\.high),
                            lows: sorted.map(\.low),
                            volumes: sorted.map(\.volume)
                        )
                    } catch {
                        return nil
                    }
                }
            }
            var collected: [CandleResult] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }

        var earliestBuyDates: [String: String] = [:]
        for group in groups {
            if let earliest = group.investments.map(\.buyDate).min() {
                earliestBuyDates[group.ticker] = formatter.string(from: earliest)
            }
        }

        for result in results {
            let summary = TechnicalIndicators.computeSignalSummary(
                closes: result.closes, highs: result.highs, lows: result.lows,
                volumes: result.volumes,
                settings: settings
            )
            technicalSignals[result.ticker] = summary

            if let buyDateStr = earliestBuyDates[result.ticker] {
                var maxHigh: Double = 0
                for (i, date) in result.dates.enumerated() where date >= buyDateStr {
                    maxHigh = max(maxHigh, result.highs[i])
                }
                if maxHigh == 0, let allMax = result.highs.max() {
                    maxHigh = allMax
                }
                if let price = currentPrice(for: result.ticker) {
                    maxHigh = max(maxHigh, price)
                }
                if maxHigh > 0 {
                    highSinceBuy[result.ticker] = maxHigh
                }
            }
        }

        guard !Task.isCancelled else { return }
        isFetchingSignals = false
    }

    /// 52 週統計（帶當日快取）
    private func fetchWeekStatsIfNeeded(forceRefresh: Bool) async {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        let todayStr = Self.todayString()

        // 嘗試讀取快取
        if !forceRefresh,
           let cachedDate = UserDefaults.standard.string(forKey: Self.weekStatsCacheDateKey),
           cachedDate == todayStr,
           let data = UserDefaults.standard.data(forKey: Self.weekStatsCacheKey),
           let cached = try? JSONDecoder().decode([String: CodableWeekStats].self, from: data) {
            for (ticker, stats) in cached {
                weekStats[ticker] = WeekStats(high52w: stats.high, low52w: stats.low)
            }
            return
        }

        isFetchingWeekStats = true

        var tickerSymbols: [(String, String)] = []
        for ticker in tickers {
            let symbol = StockMapping.resolve(ticker).symbol
            tickerSymbols.append((ticker, symbol))
        }

        struct StatsResult: Sendable {
            let ticker: String
            let high52w: Double
            let low52w: Double
        }

        let results = await withTaskGroup(of: StatsResult?.self) { group in
            for (ticker, symbol) in tickerSymbols {
                group.addTask {
                    do {
                        let response = try await StockService.shared.fetchStats(symbol: symbol)
                        guard let high = response.week52High, let low = response.week52Low,
                              high > 0, low > 0 else { return nil }
                        return StatsResult(ticker: ticker, high52w: high, low52w: low)
                    } catch {
                        return nil
                    }
                }
            }
            var collected: [StatsResult] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }

        var cacheDict: [String: CodableWeekStats] = [:]
        for result in results {
            weekStats[result.ticker] = WeekStats(high52w: result.high52w, low52w: result.low52w)
            cacheDict[result.ticker] = CodableWeekStats(high: result.high52w, low: result.low52w)
        }

        // 寫入快取
        if let encoded = try? JSONEncoder().encode(cacheDict) {
            UserDefaults.standard.set(encoded, forKey: Self.weekStatsCacheKey)
            UserDefaults.standard.set(todayStr, forKey: Self.weekStatsCacheDateKey)
        }

        guard !Task.isCancelled else { return }
        isFetchingWeekStats = false
    }

    /// 法人買賣超（帶當日快取 + 排除週末）
    private func fetchInstitutionalIfNeeded(forceRefresh: Bool) async {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        let todayStr = Self.todayString()

        // 嘗試讀取快取
        if !forceRefresh,
           let cachedDate = UserDefaults.standard.string(forKey: Self.institutionalCacheDateKey),
           cachedDate == todayStr,
           let data = UserDefaults.standard.data(forKey: Self.institutionalCacheKey),
           let cached = try? JSONDecoder().decode([String: CodableInstitutionalSummary].self, from: data) {
            for (ticker, summary) in cached {
                institutionalData[ticker] = summary.toSummary()
            }
            return
        }

        isFetchingInstitutional = true

        var tickerToCode: [String: String] = [:]
        for ticker in tickers {
            let resolved = StockMapping.resolve(ticker)
            tickerToCode[ticker] = resolved.symbol
        }

        // 產生最近的工作日日期（排除週末），最多取 10 個工作日
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var datesToFetch: [String] = []
        var dayOffset = 0
        while datesToFetch.count < 10 && dayOffset < 20 {
            if let d = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let weekday = calendar.component(.weekday, from: d)
                // 1 = 週日, 7 = 週六
                if weekday != 1 && weekday != 7 {
                    datesToFetch.append(formatter.string(from: d))
                }
            }
            dayOffset += 1
        }

        let allDayResults = await withTaskGroup(
            of: (String, [String: StockService.InstitutionalDayData]?).self
        ) { group in
            for dateStr in datesToFetch {
                group.addTask {
                    do {
                        let data = try await StockService.shared.fetchInstitutionalData(date: dateStr)
                        return (dateStr, data)
                    } catch {
                        return (dateStr, nil)
                    }
                }
            }
            var collected: [(String, [String: StockService.InstitutionalDayData])] = []
            for await (dateStr, data) in group {
                if let data { collected.append((dateStr, data)) }
            }
            return collected.sorted { $0.0 > $1.0 }
        }

        guard !Task.isCancelled else { return }

        let tradingDays = Array(allDayResults.prefix(5))

        var cacheDict: [String: CodableInstitutionalSummary] = [:]
        for (ticker, code) in tickerToCode {
            var days: [StockService.InstitutionalDayData] = []
            for (_, dayMap) in tradingDays {
                if let dayData = dayMap[code] {
                    days.append(dayData)
                }
            }
            if !days.isEmpty {
                let summary = StockService.InstitutionalSummary(days: days)
                institutionalData[ticker] = summary
                cacheDict[ticker] = CodableInstitutionalSummary(from: summary)
            }
        }

        // 寫入快取
        if let encoded = try? JSONEncoder().encode(cacheDict) {
            UserDefaults.standard.set(encoded, forKey: Self.institutionalCacheKey)
            UserDefaults.standard.set(todayStr, forKey: Self.institutionalCacheDateKey)
        }

        guard !Task.isCancelled else { return }
        isFetchingInstitutional = false
    }

    /// 今天日期字串（用於快取判斷）
    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    // MARK: - Actions

    func selectForSell(_ investment: Investment) {
        selectedInvestment = investment
        showingSellSheet = true
    }

    func selectGroupForSell(_ group: PortfolioGroup) {
        selectedGroup = group
        showingGroupSellSheet = true
    }

    func openStockDetail(_ group: PortfolioGroup) {
        selectedGroupForDetail = group
        showingStockDetailSheet = true
    }

    func confirmDelete(_ investment: Investment) {
        investmentToDelete = investment
        showingDeleteAlert = true
    }

    func deleteConfirmed(context: ModelContext) {
        guard let investment = investmentToDelete else { return }
        Investment.deleteInvestment(investment, context: context)
    }

    // MARK: - Formatting

    func formattedDate(_ date: Date) -> String {
        AppDateFormatter.slashDate.string(from: date)
    }
}
// MARK: - Codable 快取結構

/// 52 週統計快取用
private struct CodableWeekStats: Codable {
    let high: Double
    let low: Double
}

/// 法人買賣超快取用
private struct CodableInstitutionalSummary: Codable {
    let days: [CodableDayData]

    struct CodableDayData: Codable {
        let date: String
        let foreignNet: Int
        let trustNet: Int
        let dealerNet: Int
        let totalNet: Int
    }

    init(from summary: StockService.InstitutionalSummary) {
        self.days = summary.days.map {
            CodableDayData(date: $0.date, foreignNet: $0.foreignNet, trustNet: $0.trustNet,
                           dealerNet: $0.dealerNet, totalNet: $0.totalNet)
        }
    }

    func toSummary() -> StockService.InstitutionalSummary {
        let converted = days.map {
            StockService.InstitutionalDayData(date: $0.date, foreignNet: $0.foreignNet,
                                               trustNet: $0.trustNet, dealerNet: $0.dealerNet,
                                               totalNet: $0.totalNet)
        }
        return StockService.InstitutionalSummary(days: converted)
    }
}

