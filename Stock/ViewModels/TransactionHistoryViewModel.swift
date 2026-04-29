import Foundation
import SwiftData
import Observation

/// 持倉狀態篩選
enum StatusFilterOption: String, CaseIterable, Identifiable {
    case all = "全部"
    case holding = "持有中"
    case closed = "已平倉"

    var id: String { rawValue }
}

@Observable
final class TransactionHistoryViewModel {
    // MARK: - Data (bridged from @Query)
    var allInvestments: [Investment] = []
    var allRecordsForExport: [Investment] = []

    // MARK: - State
    var selectedFilter: DateFilterOption = .all
    var selectedStatusFilter: StatusFilterOption = .all
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var customEndDate: Date = Date()
    var investmentToDelete: Investment?
    var showingDeleteAlert: Bool = false
    var csvFileURL: URL?
    var showingShareSheet: Bool = false

    // MARK: - Filtered Data

    var filteredInvestments: [Investment] {
        let dateFiltered = filterInvestments(
            allInvestments,
            by: selectedFilter,
            customStart: customStartDate,
            customEnd: customEndDate,
            dateExtractor: { $0.buyDate }
        )
        switch selectedStatusFilter {
        case .all:
            return dateFiltered
        case .holding:
            return dateFiltered.filter { !$0.isClosed }
        case .closed:
            return dateFiltered.filter { $0.isClosed }
        }
    }

    // MARK: - Summary

    var summaryCount: Int {
        filteredInvestments.count
    }

    var summaryTotalCost: Double {
        filteredInvestments.reduce(0.0) { $0 + $1.originalTotalCost }
    }

    // MARK: - Actions

    func exportCSV() {
        if let url = Investment.exportCSV(from: allRecordsForExport) {
            csvFileURL = url
            showingShareSheet = true
        }
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
        AppDateFormatter.slashDateWithWeekday.string(from: date)
    }
}
