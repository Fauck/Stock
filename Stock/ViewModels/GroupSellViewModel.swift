import Foundation
import SwiftData
import Observation

@Observable
final class GroupSellViewModel {
    // MARK: - Input
    let group: PortfolioGroup

    // MARK: - Form State
    var sellPriceText: String = ""
    var sellQuantityText: String = ""
    var sellReason: String = ""
    var sellMarketCondition: MarketCondition?
    var showingAlert: Bool = false
    var alertMessage: String = ""

    // MARK: - 出場覆盤 (Review)
    var reviewExpanded: Bool = false
    var exitReasonOption: ExitReasonOption? = nil
    var customExitReason: String = ""
    var reflection: String = ""
    /// 群組中所有有日誌的 Investment 的日誌
    var journals: [TradeJournal] = []

    init(group: PortfolioGroup) {
        self.group = group
    }

    /// 載入群組中所有投資的日誌
    func loadJournals(context: ModelContext) {
        let investmentIDs = group.investments.map(\.id)
        let descriptor = FetchDescriptor<TradeJournal>()
        guard let allJournals = try? context.fetch(descriptor) else { return }
        journals = allJournals.filter { investmentIDs.contains($0.investmentID) }
        if !journals.isEmpty {
            reviewExpanded = true
        }
    }

    var composedExitReason: String {
        if let option = exitReasonOption {
            if option == .custom {
                return customExitReason.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return option.rawValue
        }
        return ""
    }

    var hasReviewContent: Bool {
        exitReasonOption != nil || !reflection.isEmpty
    }

    // MARK: - Computed

    var profitPreview: ProfitPreview? {
        guard let sellPrice = Double(sellPriceText),
              let sellQty = Double(sellQuantityText),
              sellPrice > 0, sellQty > 0 else { return nil }
        let avgCost = group.weightedAverageCost
        let fees = TradingFeeSettings.load()
        let feesTotal = fees.totalFees(buyPrice: avgCost, sellPrice: sellPrice, quantity: sellQty)
        let profitLoss = fees.netProfitLoss(buyPrice: avgCost, sellPrice: sellPrice, quantity: sellQty)
        let costWithFee = avgCost * sellQty + fees.buyCommission(price: avgCost, quantity: sellQty)
        let returnPct = costWithFee > 0
            ? profitLoss / costWithFee * 100
            : 0
        return ProfitPreview(
            sellTotal: sellPrice * sellQty,
            costTotal: avgCost * sellQty,
            profitLoss: profitLoss,
            returnPct: returnPct,
            totalFees: feesTotal
        )
    }

    // MARK: - Actions

    func fillAllQuantity() {
        sellQuantityText = "\(Int(group.totalQuantity))"
    }

    /// 執行整批賣出，成功回傳 true（呼叫端應 dismiss）
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
        guard sellQuantity <= group.totalQuantity else {
            alertMessage = "賣出數量（\(Int(sellQuantity))）不可大於總持有數量（\(Int(group.totalQuantity))）"
            showingAlert = true
            return false
        }
        group.batchSell(
            quantity: sellQuantity,
            price: sellPrice,
            date: Date(),
            reason: sellReason.trimmingCharacters(in: .whitespacesAndNewlines),
            marketCondition: sellMarketCondition,
            context: context
        )

        // 更新所有關聯日誌的覆盤資料
        if hasReviewContent {
            for journal in journals {
                journal.exitReason = composedExitReason
                journal.reflection = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
                if let stopLoss = journal.initialStopLoss {
                    let entryPrice = group.investments
                        .first { $0.id == journal.investmentID }?.buyPrice ?? group.weightedAverageCost
                    journal.rMultiple = TradeJournal.calculateRMultiple(
                        entryPrice: entryPrice,
                        exitPrice: sellPrice,
                        stopLoss: stopLoss
                    )
                }
            }
        }

        return true
    }
}
