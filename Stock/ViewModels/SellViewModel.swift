import Foundation
import SwiftData
import Observation

/// 損益預覽值型別
struct ProfitPreview {
    let sellTotal: Double
    let costTotal: Double
    let profitLoss: Double
    let returnPct: Double
}

@Observable
final class SellViewModel {
    // MARK: - Input
    let investment: Investment

    // MARK: - Form State
    var sellPriceText: String = ""
    var sellQuantityText: String = ""
    var sellReason: String = ""
    var sellMarketCondition: MarketCondition?
    var showingAlert: Bool = false
    var alertMessage: String = ""

    // MARK: - 出場覆盤 (Review)
    /// 關聯的交易日誌（如果有）
    var journal: TradeJournal?
    /// 是否展開覆盤區塊
    var reviewExpanded: Bool = false
    /// 出場理由選項
    var exitReasonOption: ExitReasonOption? = nil
    /// 自訂出場理由文字
    var customExitReason: String = ""
    /// 反思筆記
    var reflection: String = ""

    init(investment: Investment) {
        self.investment = investment
    }

    /// 載入關聯的交易日誌
    func loadJournal(context: ModelContext) {
        journal = TradeJournalViewModel.fetchJournal(for: investment.id, context: context)
        if journal != nil {
            reviewExpanded = true
        }
    }

    // MARK: - Computed

    var profitPreview: ProfitPreview? {
        guard let sellPrice = Double(sellPriceText),
              let sellQty = Double(sellQuantityText),
              sellPrice > 0, sellQty > 0 else { return nil }
        let profitLoss = (sellPrice - investment.buyPrice) * sellQty
        let returnPct = investment.buyPrice > 0
            ? (sellPrice - investment.buyPrice) / investment.buyPrice * 100
            : 0
        return ProfitPreview(
            sellTotal: sellPrice * sellQty,
            costTotal: investment.buyPrice * sellQty,
            profitLoss: profitLoss,
            returnPct: returnPct
        )
    }

    /// 即時預覽 R-Multiple（需有停損價）
    var rMultiplePreview: Double? {
        guard let sellPrice = Double(sellPriceText),
              sellPrice > 0,
              let stopLoss = journal?.initialStopLoss else { return nil }
        return TradeJournal.calculateRMultiple(
            entryPrice: investment.buyPrice,
            exitPrice: sellPrice,
            stopLoss: stopLoss
        )
    }

    /// 組合出場理由文字
    var composedExitReason: String {
        if let option = exitReasonOption {
            if option == .custom {
                return customExitReason.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return option.rawValue
        }
        return ""
    }

    /// 是否有覆盤內容
    var hasReviewContent: Bool {
        exitReasonOption != nil || !reflection.isEmpty
    }

    // MARK: - Actions

    func fillAllQuantity() {
        sellQuantityText = "\(Int(investment.quantity))"
    }

    /// 執行賣出，成功回傳 true（呼叫端應 dismiss）
    func executeSell(context: ModelContext) -> Bool {
        guard let sellPrice = Double(sellPriceText), sellPrice > 0 else {
            alertMessage = "請輸入有效的賣出價格"
            showingAlert = true
            return false
        }
        guard let sellQuantity = Double(sellQuantityText), sellQuantity > 0 else {
            alertMessage = "請輸入有效的賣出數量"
            showingAlert = true
            return false
        }
        guard sellQuantity <= investment.quantity else {
            alertMessage = "賣出數量（\(Int(sellQuantity))）不可大於持有數量（\(Int(investment.quantity))）"
            showingAlert = true
            return false
        }
        investment.sell(
            quantity: sellQuantity,
            price: sellPrice,
            date: Date(),
            reason: sellReason.trimmingCharacters(in: .whitespacesAndNewlines),
            marketCondition: sellMarketCondition,
            context: context
        )

        // 更新交易日誌的覆盤資料
        if let journal = journal, hasReviewContent {
            journal.exitReason = composedExitReason
            journal.reflection = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
            // 計算 R-Multiple
            if let stopLoss = journal.initialStopLoss {
                journal.rMultiple = TradeJournal.calculateRMultiple(
                    entryPrice: investment.buyPrice,
                    exitPrice: sellPrice,
                    stopLoss: stopLoss
                )
            }
        }

        return true
    }
}
