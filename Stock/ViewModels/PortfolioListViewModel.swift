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
    private var signalTask: Task<Void, Never>?
    private var weekStatsTask: Task<Void, Never>?

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

    var totalPL: Double {
        totalMarketValue - totalCost
    }

    /// 總報酬率（百分比）
    var totalReturnPct: Double {
        guard totalCost > 0 else { return 0 }
        return totalPL / totalCost * 100
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

    // MARK: - 技術指標載入

    /// 批次載入所有持有標的的技術指標信號
    /// 需要歷史 K 線資料（最近 30 個交易日 ≈ 45 日曆日）
    func fetchTechnicalSignals() {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        signalTask?.cancel()
        signalTask = Task { @MainActor in
            isFetchingSignals = true

            let calendar = Calendar.current
            let today = Date()
            let fromDate = calendar.date(byAdding: .day, value: -60, to: today) ?? today

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let fromStr = formatter.string(from: fromDate)
            let toStr = formatter.string(from: today)

            // 預先解析代號（MainActor 上）
            var tickerSymbols: [(String, String)] = []
            for ticker in tickers {
                let symbol = StockMapping.resolve(ticker).symbol
                tickerSymbols.append((ticker, symbol))
            }

            // 定義回傳型別
            struct CandleResult: Sendable {
                let ticker: String
                let closes: [Double]
                let highs: [Double]
                let lows: [Double]
            }

            // 並行取得歷史資料
            let results = await withTaskGroup(of: CandleResult?.self) { group in
                for (ticker, symbol) in tickerSymbols {
                    group.addTask {
                        do {
                            let response = try await StockService.shared.fetchHistoricalCandles(
                                symbol: symbol, from: fromStr, to: toStr
                            )
                            let sorted = response.data.sorted { $0.date < $1.date }
                            return CandleResult(
                                ticker: ticker,
                                closes: sorted.map(\.close),
                                highs: sorted.map(\.high),
                                lows: sorted.map(\.low)
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

            // 在 MainActor 上計算信號
            for result in results {
                let summary = TechnicalIndicators.computeSignalSummary(
                    closes: result.closes, highs: result.highs, lows: result.lows
                )
                technicalSignals[result.ticker] = summary
            }

            guard !Task.isCancelled else { return }
            isFetchingSignals = false
        }
    }

    // MARK: - 52 週統計載入

    /// 批次載入所有持有標的的 52 週高低點
    func fetchWeekStats() {
        let tickers = groups.map(\.ticker)
        guard !tickers.isEmpty else { return }

        weekStatsTask?.cancel()
        weekStatsTask = Task { @MainActor in
            isFetchingWeekStats = true

            // 預先解析代號（MainActor 上）
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

            for result in results {
                weekStats[result.ticker] = WeekStats(high52w: result.high52w, low52w: result.low52w)
            }

            guard !Task.isCancelled else { return }
            isFetchingWeekStats = false
        }
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
