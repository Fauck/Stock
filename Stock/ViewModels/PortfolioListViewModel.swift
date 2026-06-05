import Foundation
import SwiftData
import Observation

@Observable
final class PortfolioListViewModel {
    // MARK: - Data (bridged from @Query)
    var investments: [Investment] = []

    // MARK: - State
    var currentPrices: [String: String] = [:]
    var expandedTicker: String?

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

    // 刪除
    var investmentToDelete: Investment?
    var showingDeleteAlert: Bool = false

    private var fetchTask: Task<Void, Never>?

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
                    let cleanName = result.name.replacingOccurrences(of: "*", with: "")
                    stockNames[ticker] = cleanName
                    StockMapping.cache(symbol: apiSymbol, name: result.name)
                }
            }
            isFetchingPrices = false
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
