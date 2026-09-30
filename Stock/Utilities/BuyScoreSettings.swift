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

    // MARK: - K 線型態（僅供參考，權重已下調）
    var candleHighBullishPoints: Int = 5
    var candleHighBearishPoints: Int = -4
    var candleMedBullishPoints: Int = 3
    var candleMedBearishPoints: Int = -2
    var candleLowBullishPoints: Int = 1
    var candleLowBearishPoints: Int = -1

    // MARK: - 52 週位置
    var near52WeekLowPoints: Int = 8
    var near52WeekHighPoints: Int = -6

    // MARK: - 市場狀態修正
    var sidewaysDiscountPct: Int = 50  // 盤整時超買超賣信號打折 %

    // MARK: - 法人累計
    var foreignCumulativeLargeThreshold: Int = 5000
    var foreignCumulativeLargePoints: Int = 5
    var foreignCumulativeSmallThreshold: Int = 1000
    var foreignCumulativeSmallPoints: Int = 3
    var trustCumulativeLargeThreshold: Int = 2000
    var trustCumulativeLargePoints: Int = 4
    var trustCumulativeSmallThreshold: Int = 500
    var trustCumulativeSmallPoints: Int = 2

    // MARK: - 融資融券
    var marginIncreasePoints: Int = -3    // 融資大增 → 偏空（散戶追多）
    var marginDecreasePoints: Int = 3     // 融資大減 → 偏多（賣壓減少）
    var shortIncreasePoints: Int = 3      // 融券大增 → 偏多（軋空潛力）
    var shortDecreasePoints: Int = -2     // 融券大減 → 偏空（回補完畢）
    var marginChangeThreshold: Int = 500  // 增減超過此張數才計分

    // MARK: - 信號分組上限（去相關化）
    var trendGroupCap: Int = 15       // 趨勢組 (MA cross + MACD cross + DIF) ±上限
    var momentumGroupCap: Int = 12    // 動量組 (KDJ + RSI) ±上限

    // MARK: - 版本（Codable 向後相容）
    var version: Int = 1

    // MARK: - Persistence

    static let defaults = BuyScoreSettings()

    private static let storageKey = "buyScoreSettings"

    /// 從 UserDefaults 讀取，找不到則回傳預設值
    static func load() -> BuyScoreSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(BuyScoreSettings.self, from: data).clamped()
        } catch {
            #if DEBUG
            print("[BuyScoreSettings] 解碼失敗，使用預設值: \(error)")
            #endif
            return .defaults
        }
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

    /// 將所有數值夾到合理範圍
    func clamped() -> BuyScoreSettings {
        var s = self
        // 各分數項目 ±30
        func clampPts(_ v: Int) -> Int { max(-30, min(v, 30)) }
        s.maGoldenCrossPoints = clampPts(s.maGoldenCrossPoints)
        s.maDeathCrossPoints = clampPts(s.maDeathCrossPoints)
        s.aboveMA5Points = clampPts(s.aboveMA5Points)
        s.belowMA5Points = clampPts(s.belowMA5Points)
        s.aboveMA20Points = clampPts(s.aboveMA20Points)
        s.belowMA20Points = clampPts(s.belowMA20Points)
        s.macdGoldenCrossPoints = clampPts(s.macdGoldenCrossPoints)
        s.macdDeathCrossPoints = clampPts(s.macdDeathCrossPoints)
        s.macdPositivePoints = clampPts(s.macdPositivePoints)
        s.macdNegativePoints = clampPts(s.macdNegativePoints)
        s.kdjGoldenCrossPoints = clampPts(s.kdjGoldenCrossPoints)
        s.kdjDeathCrossPoints = clampPts(s.kdjDeathCrossPoints)
        s.kdjOversoldPoints = clampPts(s.kdjOversoldPoints)
        s.kdjOverboughtPoints = clampPts(s.kdjOverboughtPoints)
        s.rsiOversoldPoints = clampPts(s.rsiOversoldPoints)
        s.rsiOverboughtPoints = clampPts(s.rsiOverboughtPoints)
        s.bollingerLowerPoints = clampPts(s.bollingerLowerPoints)
        s.bollingerUpperPoints = clampPts(s.bollingerUpperPoints)
        s.volumeSurgePoints = clampPts(s.volumeSurgePoints)
        s.volumeShrinkPoints = clampPts(s.volumeShrinkPoints)
        s.foreignBuyStreakPoints = clampPts(s.foreignBuyStreakPoints)
        s.foreignSellStreakPoints = clampPts(s.foreignSellStreakPoints)
        s.trustBuyStreakPoints = clampPts(s.trustBuyStreakPoints)
        s.trustSellStreakPoints = clampPts(s.trustSellStreakPoints)
        s.rsiBullishDivPoints = clampPts(s.rsiBullishDivPoints)
        s.rsiBearishDivPoints = clampPts(s.rsiBearishDivPoints)
        s.macdBullishDivPoints = clampPts(s.macdBullishDivPoints)
        s.macdBearishDivPoints = clampPts(s.macdBearishDivPoints)
        s.candleHighBullishPoints = clampPts(s.candleHighBullishPoints)
        s.candleHighBearishPoints = clampPts(s.candleHighBearishPoints)
        s.candleMedBullishPoints = clampPts(s.candleMedBullishPoints)
        s.candleMedBearishPoints = clampPts(s.candleMedBearishPoints)
        s.candleLowBullishPoints = clampPts(s.candleLowBullishPoints)
        s.candleLowBearishPoints = clampPts(s.candleLowBearishPoints)
        s.near52WeekLowPoints = clampPts(s.near52WeekLowPoints)
        s.near52WeekHighPoints = clampPts(s.near52WeekHighPoints)
        // 折扣百分比
        s.sidewaysDiscountPct = max(0, min(s.sidewaysDiscountPct, 100))
        // 法人累計
        s.foreignCumulativeLargeThreshold = max(100, min(s.foreignCumulativeLargeThreshold, 100000))
        s.foreignCumulativeLargePoints = clampPts(s.foreignCumulativeLargePoints)
        s.foreignCumulativeSmallThreshold = max(10, min(s.foreignCumulativeSmallThreshold, 50000))
        s.foreignCumulativeSmallPoints = clampPts(s.foreignCumulativeSmallPoints)
        s.trustCumulativeLargeThreshold = max(100, min(s.trustCumulativeLargeThreshold, 50000))
        s.trustCumulativeLargePoints = clampPts(s.trustCumulativeLargePoints)
        s.trustCumulativeSmallThreshold = max(10, min(s.trustCumulativeSmallThreshold, 20000))
        s.trustCumulativeSmallPoints = clampPts(s.trustCumulativeSmallPoints)
        // 融資融券
        s.marginIncreasePoints = clampPts(s.marginIncreasePoints)
        s.marginDecreasePoints = clampPts(s.marginDecreasePoints)
        s.shortIncreasePoints = clampPts(s.shortIncreasePoints)
        s.shortDecreasePoints = clampPts(s.shortDecreasePoints)
        s.marginChangeThreshold = max(10, min(s.marginChangeThreshold, 10000))
        // 分組上限
        s.trendGroupCap = max(1, min(s.trendGroupCap, 50))
        s.momentumGroupCap = max(1, min(s.momentumGroupCap, 50))
        return s
    }
}
