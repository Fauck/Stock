import Foundation

/// 交易費用設定（手續費與證券交易稅，可持久化至 UserDefaults）
struct TradingFeeSettings: Codable, Equatable, Sendable {

    /// 手續費率（預設 0.1425%）— 買賣各收一次
    var commissionRate: Double = 0.001425

    /// 證券交易稅率（預設 0.3%）— 僅賣出時收取
    var taxRate: Double = 0.003

    /// 移動停利 — 從最高價回撤百分比 (%)，預設 10%
    var trailingStopPct: Double = 10

    /// 是否顯示賣出建議（預設關閉）
    var sellRecommendationEnabled: Bool = false

    /// 是否顯示壓力/支撐價位（預設關閉）
    var supportResistanceEnabled: Bool = false

    // MARK: - Defaults

    static let defaults = TradingFeeSettings()

    private static let storageKey = "tradingFeeSettings"

    /// 從 UserDefaults 讀取，找不到則回傳預設值
    static func load() -> TradingFeeSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(TradingFeeSettings.self, from: data)
        else { return .defaults }
        return settings
    }

    /// 儲存至 UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// 恢復預設（移除儲存的設定）
    static func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - 費用計算

    /// 買入手續費
    func buyCommission(price: Double, quantity: Double) -> Double {
        price * quantity * commissionRate
    }

    /// 賣出手續費
    func sellCommission(price: Double, quantity: Double) -> Double {
        price * quantity * commissionRate
    }

    /// 證券交易稅（僅賣出）
    func transactionTax(sellPrice: Double, quantity: Double) -> Double {
        sellPrice * quantity * taxRate
    }

    /// 總交易成本（買入手續費 + 賣出手續費 + 交易稅）
    func totalFees(buyPrice: Double, sellPrice: Double, quantity: Double) -> Double {
        buyCommission(price: buyPrice, quantity: quantity)
        + sellCommission(price: sellPrice, quantity: quantity)
        + transactionTax(sellPrice: sellPrice, quantity: quantity)
    }

    /// 淨損益（扣除所有費用）
    func netProfitLoss(buyPrice: Double, sellPrice: Double, quantity: Double) -> Double {
        (sellPrice - buyPrice) * quantity - totalFees(buyPrice: buyPrice, sellPrice: sellPrice, quantity: quantity)
    }

}
