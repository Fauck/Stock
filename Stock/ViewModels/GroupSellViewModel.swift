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

    init(group: PortfolioGroup) {
        self.group = group
    }

    // MARK: - Computed

    var profitPreview: ProfitPreview? {
        guard let sellPrice = Double(sellPriceText),
              let sellQty = Double(sellQuantityText),
              sellPrice > 0, sellQty > 0 else { return nil }
        let avgCost = group.weightedAverageCost
        let profitLoss = (sellPrice - avgCost) * sellQty
        let returnPct = avgCost > 0
            ? (sellPrice - avgCost) / avgCost * 100
            : 0
        return ProfitPreview(
            sellTotal: sellPrice * sellQty,
            costTotal: avgCost * sellQty,
            profitLoss: profitLoss,
            returnPct: returnPct
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
        return true
    }
}
