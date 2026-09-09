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

    /// 目標價 / 停損價（從交易日誌取得）[ticker: JournalTarget]
    var journalTargets: [String: JournalTarget] = [:]

    /// 交易日誌（由 View 的 @Query bridge 進來）
    var journals: [TradeJournal] = []

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
    private static let candleCacheKey = CandleCacheKeys.data
    private static let candleCacheDateKey = CandleCacheKeys.date

    /// 上次成功載入的日期（用於判斷重新整理是否需要重抓）
    private var lastLoadDate: String?

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

    // MARK: - Sell Recommendation

    /// 計算單一標的的賣出建議（受設定開關控制）
    func sellRecommendation(for ticker: String, avgCost: Double) -> TechnicalIndicators.SellRecommendation? {
        guard TradingFeeSettings.load().sellRecommendationEnabled else { return nil }
        guard let signal = technicalSignals[ticker] else { return nil }

        // 計算移動停利狀態
        let price = currentPrice(for: ticker)
        let high = highSinceBuy[ticker]
        var trailingStopTriggered = false
        var nearTrailingStop = false

        if let price, let high, high > 0 {
            let pct = TradingFeeSettings.load().trailingStopPct
            let rawStop = high * (1 - pct / 100)
            let stopPrice = max(rawStop, avgCost)
            trailingStopTriggered = price <= stopPrice
            nearTrailingStop = !trailingStopTriggered && price <= stopPrice * 1.03
        }

        // 法人連續天數
        let inst = institutionalData[ticker]

        return TechnicalIndicators.computeSellRecommendation(
            signal: signal,
            trailingStopTriggered: trailingStopTriggered,
            nearTrailingStop: nearTrailingStop,
            foreignStreak: inst?.foreignStreak,
            trustStreak: inst?.trustStreak
        )
    }

    // MARK: - Journal Target (目標價 / 停損價)

    struct JournalTarget {
        let targetPrice: Double?
        let stopLoss: Double?
    }

    /// 從 journals + investments 建立每個 ticker 的目標價/停損價
    /// 同標的多筆 investment → 以最近一筆有填寫的 journal 為準
    func buildJournalTargets() {
        // 建立 investmentID → Investment 對照表（僅未平倉）
        let activeInvestments = investments.filter { !$0.isClosed }
        let investmentMap = Dictionary(uniqueKeysWithValues: activeInvestments.map { ($0.id, $0) })

        // 建立 ticker → [journal] 對照（僅關聯到未平倉 investment 的 journals）
        var tickerJournals: [String: [(date: Date, journal: TradeJournal)]] = [:]
        for journal in journals {
            guard let inv = investmentMap[journal.investmentID] else { continue }
            let ticker = StockMapping.normalizedSymbol(for: inv.ticker)
            tickerJournals[ticker, default: []].append((date: inv.buyDate, journal: journal))
        }

        var result: [String: JournalTarget] = [:]
        for (ticker, entries) in tickerJournals {
            // 按買入日期由新到舊排序
            let sorted = entries.sorted { $0.date > $1.date }
            // 取最近一筆有填寫 target 的
            let target = sorted.first(where: { $0.journal.targetPrice != nil })?.journal.targetPrice
            // 取最近一筆有填寫 stopLoss 的
            let stop = sorted.first(where: { $0.journal.initialStopLoss != nil })?.journal.initialStopLoss
            if target != nil || stop != nil {
                result[ticker] = JournalTarget(targetPrice: target, stopLoss: stop)
            }
        }
        journalTargets = result
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
    /// forceRefresh = true 時（重新整理按鈕），若日期與上次相同則只刷新即時報價，
    /// 快取類資料（K 線 / 52 週 / 法人）不重抓。跨日才真正強制刷新。
    func loadData(forceRefresh: Bool = false) {
        loadDataTask?.cancel()
        loadDataTask = Task { @MainActor in
            let todayStr = Self.todayString()
            let alreadyLoadedToday = (lastLoadDate == todayStr)

            // Phase 1：即時報價（永遠重抓）
            await fetchAllPricesAsync()

            guard !Task.isCancelled else { return }

            // 同日重新整理 + 無新 ticker → 跳過 Phase 2（只刷即時價）
            if forceRefresh && alreadyLoadedToday {
                let tickers = Set(groups.map(\.ticker))
                let hasCachedSignals = tickers.allSatisfy { technicalSignals[$0] != nil }
                if hasCachedSignals {
                    return
                }
            }

            // Phase 2：次要資料並行載入
            let needRefreshCache = forceRefresh && !alreadyLoadedToday
            async let signalsTask: () = fetchTechnicalSignalsIfNeeded(forceRefresh: needRefreshCache)
            async let weekTask: () = fetchWeekStatsIfNeeded(forceRefresh: needRefreshCache)
            async let instTask: () = fetchInstitutionalIfNeeded(forceRefresh: needRefreshCache)
            _ = await (signalsTask, weekTask, instTask)

            lastLoadDate = todayStr
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

    /// 技術指標載入（帶 K 線當日快取）
    /// K 線為歷史資料，盤後不變，當日只需抓一次
    /// 新增 ticker 時只補抓缺少的部分，不重抓已快取的
    private func fetchTechnicalSignalsIfNeeded(forceRefresh: Bool) async {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        let todayStr = Self.todayString()
        let settings = TechnicalSettings.load()

        // 嘗試讀取 K 線快取
        var existingCache: [String: CandleCacheData] = [:]
        if !forceRefresh,
           let cachedDate = UserDefaults.standard.string(forKey: Self.candleCacheDateKey),
           cachedDate == todayStr,
           let data = UserDefaults.standard.data(forKey: Self.candleCacheKey),
           let cached = try? JSONDecoder().decode([String: CandleCacheData].self, from: data) {
            existingCache = cached
        }

        // 找出快取中缺少的 ticker
        let missingTickers = tickers.filter { existingCache[$0] == nil }

        // 全部命中快取 → 直接計算信號
        if missingTickers.isEmpty && !existingCache.isEmpty {
            applySignalsFromCandles(existingCache, tickers: tickers, settings: settings)
            return
        }

        // 需要抓取（全部或部分）
        let tickersToFetch = forceRefresh ? tickers : missingTickers
        guard !tickersToFetch.isEmpty else { return }

        isFetchingSignals = true

        let calendar = Calendar.current
        let today = Date()
        let defaultFromDate = calendar.date(byAdding: .day, value: -60, to: today) ?? today

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let defaultFromStr = formatter.string(from: defaultFromDate)
        let toStr = formatter.string(from: today)

        var tickerSymbols: [(ticker: String, symbol: String, fromStr: String)] = []
        for ticker in tickersToFetch {
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
            let opens: [Double]
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
                            opens: sorted.map(\.open),
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

        guard !Task.isCancelled else { return }

        // 合併快取 + 新抓取的資料
        var mergedCache = existingCache
        for result in results {
            mergedCache[result.ticker] = CandleCacheData(
                dates: result.dates, opens: result.opens,
                closes: result.closes, highs: result.highs,
                lows: result.lows, volumes: result.volumes
            )
        }

        // 寫回快取
        if let encoded = try? JSONEncoder().encode(mergedCache) {
            UserDefaults.standard.set(encoded, forKey: Self.candleCacheKey)
            UserDefaults.standard.set(todayStr, forKey: Self.candleCacheDateKey)
        }

        // 從合併結果計算信號
        applySignalsFromCandles(mergedCache, tickers: tickers, settings: settings)
        isFetchingSignals = false
    }

    /// 從 K 線資料計算技術指標 + 買入後最高價
    private func applySignalsFromCandles(
        _ candles: [String: CandleCacheData],
        tickers: [String],
        settings: TechnicalSettings
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var earliestBuyDates: [String: String] = [:]
        for group in groups {
            if let earliest = group.investments.map(\.buyDate).min() {
                earliestBuyDates[group.ticker] = formatter.string(from: earliest)
            }
        }

        for ticker in tickers {
            guard let candle = candles[ticker] else { continue }

            let summary = TechnicalIndicators.computeSignalSummary(
                opens: candle.opens,
                closes: candle.closes, highs: candle.highs, lows: candle.lows,
                volumes: candle.volumes, settings: settings
            )
            technicalSignals[ticker] = summary

            if let buyDateStr = earliestBuyDates[ticker] {
                var maxHigh: Double = 0
                for (i, date) in candle.dates.enumerated() where date >= buyDateStr {
                    maxHigh = max(maxHigh, candle.highs[i])
                }
                // 含今日即時價格（K 線可能尚未包含今天）
                if let price = currentPrice(for: ticker) {
                    maxHigh = max(maxHigh, price)
                }
                if maxHigh > 0 {
                    highSinceBuy[ticker] = maxHigh
                }
            }
        }
    }

    /// 52 週統計（帶當日快取，新 ticker 自動補抓）
    private func fetchWeekStatsIfNeeded(forceRefresh: Bool) async {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        let todayStr = Self.todayString()

        // 嘗試讀取快取
        var existingCache: [String: CodableWeekStats] = [:]
        if !forceRefresh,
           let cachedDate = UserDefaults.standard.string(forKey: Self.weekStatsCacheDateKey),
           cachedDate == todayStr,
           let data = UserDefaults.standard.data(forKey: Self.weekStatsCacheKey),
           let cached = try? JSONDecoder().decode([String: CodableWeekStats].self, from: data) {
            existingCache = cached
            for (ticker, stats) in cached {
                weekStats[ticker] = WeekStats(high52w: stats.high, low52w: stats.low)
            }
        }

        // 找出快取中缺少的 ticker
        let missingTickers = tickers.filter { existingCache[$0] == nil }

        if missingTickers.isEmpty && !existingCache.isEmpty {
            return
        }

        let tickersToFetch = forceRefresh ? tickers : missingTickers
        guard !tickersToFetch.isEmpty else { return }

        isFetchingWeekStats = true

        var tickerSymbols: [(String, String)] = []
        for ticker in tickersToFetch {
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

        // 合併快取 + 新結果
        var mergedCache = existingCache
        for result in results {
            weekStats[result.ticker] = WeekStats(high52w: result.high52w, low52w: result.low52w)
            mergedCache[result.ticker] = CodableWeekStats(high: result.high52w, low: result.low52w)
        }

        // 寫回快取
        if let encoded = try? JSONEncoder().encode(mergedCache) {
            UserDefaults.standard.set(encoded, forKey: Self.weekStatsCacheKey)
            UserDefaults.standard.set(todayStr, forKey: Self.weekStatsCacheDateKey)
        }

        guard !Task.isCancelled else { return }
        isFetchingWeekStats = false
    }

    /// 法人買賣超（帶當日快取 + 排除週末，新 ticker 自動補抓）
    /// 注意：法人 API 一次回傳全部個股，所以只要有缺 ticker 就需重抓全部日期
    private func fetchInstitutionalIfNeeded(forceRefresh: Bool) async {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        let todayStr = Self.todayString()

        // 嘗試讀取快取
        var existingCache: [String: CodableInstitutionalSummary] = [:]
        if !forceRefresh,
           let cachedDate = UserDefaults.standard.string(forKey: Self.institutionalCacheDateKey),
           cachedDate == todayStr,
           let data = UserDefaults.standard.data(forKey: Self.institutionalCacheKey),
           let cached = try? JSONDecoder().decode([String: CodableInstitutionalSummary].self, from: data) {
            existingCache = cached
            for (ticker, summary) in cached {
                institutionalData[ticker] = summary.toSummary()
            }
        }

        // 找出快取中缺少的 ticker
        let missingTickers = tickers.filter { existingCache[$0] == nil }

        if missingTickers.isEmpty && !existingCache.isEmpty {
            return
        }

        // 法人 API 一次回傳全市場，重抓後可涵蓋所有 ticker
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
                if weekday != 1 && weekday != 7 {
                    datesToFetch.append(formatter.string(from: d))
                }
            }
            dayOffset += 1
        }

        // 同時抓取 TWSE（上市）與 TPEx（上櫃）法人資料，再合併
        let allDayResults = await withTaskGroup(
            of: (String, [String: StockService.InstitutionalDayData]?).self
        ) { group in
            for dateStr in datesToFetch {
                // TWSE 上市
                group.addTask {
                    do {
                        let data = try await StockService.shared.fetchInstitutionalData(date: dateStr)
                        return ("TWSE_\(dateStr)", data)
                    } catch {
                        return ("TWSE_\(dateStr)", nil)
                    }
                }
                // TPEx 上櫃
                group.addTask {
                    do {
                        let data = try await StockService.shared.fetchTPExInstitutionalData(date: dateStr)
                        return ("TPEx_\(dateStr)", data)
                    } catch {
                        return ("TPEx_\(dateStr)", nil)
                    }
                }
            }
            // 收集並依日期合併 TWSE + TPEx
            var twseMap: [String: [String: StockService.InstitutionalDayData]] = [:]
            var tpexMap: [String: [String: StockService.InstitutionalDayData]] = [:]
            for await (key, data) in group {
                guard let data else { continue }
                if key.hasPrefix("TWSE_") {
                    let dateStr = String(key.dropFirst(5))
                    twseMap[dateStr] = data
                } else if key.hasPrefix("TPEx_") {
                    let dateStr = String(key.dropFirst(5))
                    tpexMap[dateStr] = data
                }
            }
            // 合併同一日期的 TWSE + TPEx 資料
            var merged: [(String, [String: StockService.InstitutionalDayData])] = []
            let allDates = Set(twseMap.keys).union(tpexMap.keys)
            for dateStr in allDates {
                var dayData = twseMap[dateStr] ?? [:]
                if let tpexData = tpexMap[dateStr] {
                    dayData.merge(tpexData) { existing, _ in existing }
                }
                merged.append((dateStr, dayData))
            }
            return merged.sorted { $0.0 > $1.0 }
        }

        guard !Task.isCancelled else { return }

        let tradingDays = Array(allDayResults.prefix(5))

        var mergedCache = existingCache
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
                mergedCache[ticker] = CodableInstitutionalSummary(from: summary)
            }
        }

        // 寫回快取
        if let encoded = try? JSONEncoder().encode(mergedCache) {
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

