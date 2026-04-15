import Foundation
import SwiftData
import Observation

@Observable
final class AddInvestmentViewModel {
    // MARK: - Input
    let selectedDate: Date

    // MARK: - Form State
    var ticker: String = ""
    var buyPriceText: String = ""
    var quantityText: String = ""
    var buyReason: String = ""
    var buyMarketCondition: MarketCondition?
    var showingAlert: Bool = false
    var alertMessage: String = ""

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
    }

    // MARK: - Computed

    var formattedDate: String {
        AppDateFormatter.fullDateWithWeekday.string(from: selectedDate)
    }

    var costPreview: Double? {
        guard let price = Double(buyPriceText),
              let qty = Double(quantityText),
              price > 0, qty > 0 else { return nil }
        return price * qty
    }

    // MARK: - Actions

    /// 儲存投資紀錄，成功回傳 true（呼叫端應 dismiss）
    func save(context: ModelContext) -> Bool {
        let trimmedTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTicker.isEmpty else {
            alertMessage = "請輸入標的名稱或代號"
            showingAlert = true
            return false
        }
        guard let buyPrice = Double(buyPriceText), buyPrice > 0 else {
            alertMessage = "請輸入有效的買入價格"
            showingAlert = true
            return false
        }
        guard let quantity = Double(quantityText), quantity > 0 else {
            alertMessage = "請輸入有效的買入數量"
            showingAlert = true
            return false
        }
        let investment = Investment(
            ticker: trimmedTicker,
            buyDate: selectedDate,
            buyPrice: buyPrice,
            quantity: quantity,
            buyReason: buyReason.trimmingCharacters(in: .whitespacesAndNewlines),
            buyMarketCondition: buyMarketCondition
        )
        context.insert(investment)
        return true
    }
}
