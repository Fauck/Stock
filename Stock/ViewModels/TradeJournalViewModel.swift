import Foundation
import SwiftData
import Observation

@Observable
final class TradeJournalViewModel {
    // MARK: - Data (bridged from @Query)
    var allJournals: [TradeJournal] = []

    // MARK: - 查詢日誌

    /// 根據 Investment ID 查詢對應的交易日誌
    func journal(for investmentID: UUID) -> TradeJournal? {
        allJournals.first { $0.investmentID == investmentID }
    }

    /// 根據 Investment ID 從資料庫查詢日誌
    static func fetchJournal(for investmentID: UUID, context: ModelContext) -> TradeJournal? {
        let descriptor = FetchDescriptor<TradeJournal>(
            predicate: #Predicate<TradeJournal> { $0.investmentID == investmentID }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - R-Multiple 統計

    /// 計算所有有 R-Multiple 的日誌的平均 R 值
    var averageR: Double? {
        let journals = allJournals.compactMap(\.rMultiple)
        guard !journals.isEmpty else { return nil }
        return journals.reduce(0, +) / Double(journals.count)
    }

    /// 負 R 交易中因恐慌平倉的比例
    var panicSellRatio: Double? {
        let negativeR = allJournals.filter { ($0.rMultiple ?? 0) < 0 }
        guard !negativeR.isEmpty else { return nil }
        let panicCount = negativeR.filter { $0.exitReason == ExitReasonOption.panicSell.rawValue }.count
        return Double(panicCount) / Double(negativeR.count)
    }
}
