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
        filteredInvestments.reduce(0.0) { $0 + $1.realizedProfitLoss }
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

    // MARK: - Actions

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
