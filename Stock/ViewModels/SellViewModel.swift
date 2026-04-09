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
    var showingAlert: Bool = false
    var alertMessage: String = ""

    init(investment: Investment) {
        self.investment = investment
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
            context: context
        )
        return true
    }
}
