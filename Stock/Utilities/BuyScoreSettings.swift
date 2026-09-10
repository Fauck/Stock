import Foundation

/// 買入評分權重設定（可持久化至 UserDefaults）
struct BuyScoreSettings: Codable, Equatable, Sendable {

    // MARK: - 均線 (MA)
    var maGoldenCrossPoints: Int = 12
    var maDeathCrossPoints: Int = -8
    var aboveMA5Points: Int = 4
    var belowMA5Points: Int = -4
    var aboveMA20Points: Int = 4
    var belowMA20Points: Int = -4

    // MARK: - MACD
    var macdGoldenCrossPoints: Int = 10
    var macdDeathCrossPoints: Int = -7
    var macdPositivePoints: Int = 3       // DIF > 0
    var macdNegativePoints: Int = -3      // DIF < 0

    // MARK: - KDJ
    var kdjGoldenCrossPoints: Int = 8
    var kdjDeathCrossPoints: Int = -6
    var kdjOversoldPoints: Int = 6        // K < 20
    var kdjOverboughtPoints: Int = -5     // K > 80

    // MARK: - RSI
    var rsiOversoldPoints: Int = 10
    var rsiOverboughtPoints: Int = -8

    // MARK: - 布林通道
    var bollingerLowerPoints: Int = 6     // 靠近下軌
    var bollingerUpperPoints: Int = -5    // 靠近上軌

    // MARK: - 成交量
    var volumeSurgePoints: Int = 6        // 量增
    var volumeShrinkPoints: Int = -3      // 量縮

    // MARK: - 法人
    var foreignBuyStreakPoints: Int = 5
    var foreignSellStreakPoints: Int = -5
    var trustBuyStreakPoints: Int = 5
    var trustSellStreakPoints: Int = -5

    // MARK: - 背離
    var rsiBullishDivPoints: Int = 10
    var rsiBearishDivPoints: Int = -8
    var macdBullishDivPoints: Int = 10
    var macdBearishDivPoints: Int = -8

    // MARK: - K 線型態
    var candleHighBullishPoints: Int = 10
    var candleHighBearishPoints: Int = -8
    var candleMedBullishPoints: Int = 6
    var candleMedBearishPoints: Int = -5
    var candleLowBullishPoints: Int = 3
    var candleLowBearishPoints: Int = -2

    // MARK: - 52 週位置
    var near52WeekLowPoints: Int = 8
    var near52WeekHighPoints: Int = -6

    // MARK: - Persistence

    static let defaults = BuyScoreSettings()

    private static let storageKey = "buyScoreSettings"

    /// 從 UserDefaults 讀取，找不到則回傳預設值
    static func load() -> BuyScoreSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(BuyScoreSettings.self, from: data)
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
}
