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

    // 單筆賣出
    var selectedInvestment: Investment?
    var showingSellSheet: Bool = false

    // 整批賣出
    var selectedGroup: PortfolioGroup?
    var showingGroupSellSheet: Bool = false

    // 刪除
    var investmentToDelete: Investment?
    var showingDeleteAlert: Bool = false

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
