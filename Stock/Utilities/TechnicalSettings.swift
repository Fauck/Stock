import Foundation

/// 技術指標參數設定（可持久化至 UserDefaults）
struct TechnicalSettings: Codable, Equatable, Sendable {

    // MARK: - 均線 (MA)
    var maShortPeriod: Int = 5
    var maLongPeriod: Int = 20

    // MARK: - RSI
    var rsiPeriod: Int = 14
    var rsiOverbought: Double = 80
    var rsiOversold: Double = 20

    // MARK: - KDJ
    var kdjPeriod: Int = 9
    var kdjKSmooth: Int = 3
    var kdjDSmooth: Int = 3

    // MARK: - MACD
    var macdFastPeriod: Int = 12
    var macdSlowPeriod: Int = 26
    var macdSignalPeriod: Int = 9

    // MARK: - 布林通道 (Bollinger Bands)
    var bollingerPeriod: Int = 20
    var bollingerMultiplier: Double = 2.0
    var bollingerSqueezeThreshold: Double = 0.05
    var bollingerNearBandThreshold: Double = 0.02

    // MARK: - ATR (Average True Range)
    var atrPeriod: Int = 14

    // MARK: - ADX (Average Directional Index)
    var adxPeriod: Int = 14
    var adxStrongThreshold: Double = 25

    // MARK: - 成交量 (Volume)
    var volumeSurgeMultiplier: Double = 2.0
    var volumeHighMultiplier: Double = 1.5
    var volumeShrinkMultiplier: Double = 0.5
    var volumeMAPeriod: Int = 20

    // MARK: - 版本（Codable 向後相容）
    var version: Int = 1

    // MARK: - Defaults

    static let defaults = TechnicalSettings()

    private static let storageKey = "technicalSettings"

    /// 從 UserDefaults 讀取，找不到則回傳預設值
    static func load() -> TechnicalSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(TechnicalSettings.self, from: data).clamped()
        } catch {
            #if DEBUG
            print("[TechnicalSettings] 解碼失敗，使用預設值: \(error)")
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
    func clamped() -> TechnicalSettings {
        var s = self
        s.maShortPeriod = max(1, min(s.maShortPeriod, 100))
        s.maLongPeriod = max(2, min(s.maLongPeriod, 500))
        s.rsiPeriod = max(2, min(s.rsiPeriod, 100))
        s.rsiOverbought = max(50, min(s.rsiOverbought, 100))
        s.rsiOversold = max(0, min(s.rsiOversold, 50))
        s.kdjPeriod = max(2, min(s.kdjPeriod, 100))
        s.kdjKSmooth = max(1, min(s.kdjKSmooth, 20))
        s.kdjDSmooth = max(1, min(s.kdjDSmooth, 20))
        s.macdFastPeriod = max(2, min(s.macdFastPeriod, 100))
        s.macdSlowPeriod = max(2, min(s.macdSlowPeriod, 200))
        s.macdSignalPeriod = max(2, min(s.macdSignalPeriod, 100))
        s.bollingerPeriod = max(2, min(s.bollingerPeriod, 100))
        s.bollingerMultiplier = max(0.5, min(s.bollingerMultiplier, 5.0))
        s.bollingerSqueezeThreshold = max(0.01, min(s.bollingerSqueezeThreshold, 0.5))
        s.bollingerNearBandThreshold = max(0.005, min(s.bollingerNearBandThreshold, 0.2))
        s.atrPeriod = max(2, min(s.atrPeriod, 100))
        s.adxPeriod = max(2, min(s.adxPeriod, 100))
        s.adxStrongThreshold = max(10, min(s.adxStrongThreshold, 50))
        s.volumeSurgeMultiplier = max(1.1, min(s.volumeSurgeMultiplier, 10.0))
        s.volumeHighMultiplier = max(1.0, min(s.volumeHighMultiplier, 5.0))
        s.volumeShrinkMultiplier = max(0.1, min(s.volumeShrinkMultiplier, 0.9))
        s.volumeMAPeriod = max(2, min(s.volumeMAPeriod, 100))
        return s
    }
}
