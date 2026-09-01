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

    // MARK: - 成交量 (Volume)
    var volumeSurgeMultiplier: Double = 2.0
    var volumeHighMultiplier: Double = 1.5
    var volumeShrinkMultiplier: Double = 0.5
    var volumeMAPeriod: Int = 20

    // MARK: - Defaults

    static let defaults = TechnicalSettings()

    private static let storageKey = "technicalSettings"

    /// 從 UserDefaults 讀取，找不到則回傳預設值
    static func load() -> TechnicalSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(TechnicalSettings.self, from: data)
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
