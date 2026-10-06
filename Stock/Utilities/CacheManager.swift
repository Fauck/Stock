import Foundation

/// 統一快取管理器
/// 提供 TTL + 版本號失效策略，取代散落各處的 UserDefaults 日期比較
enum CacheManager {

    /// 快取版本號（遞增即可讓所有舊快取失效）
    private static let cacheVersion = 1

    /// 快取信封：版本 + 日期 + 資料
    private struct Envelope<T: Codable>: Codable {
        let version: Int
        let dateKey: String   // "yyyyMMdd"
        let payload: T
    }

    // MARK: - Read / Write

    /// 讀取快取。日期不符或版本不符時回傳 nil。
    static func read<T: Codable>(
        _ type: T.Type,
        forKey key: String,
        validDate: String
    ) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
            guard envelope.version == cacheVersion, envelope.dateKey == validDate else {
                return nil
            }
            return envelope.payload
        } catch {
            #if DEBUG
            print("[CacheManager] decode failed for key '\(key)': \(error)")
            #endif
            return nil
        }
    }

    /// 寫入快取（包含版本 + 日期）
    static func write<T: Codable>(
        _ value: T,
        forKey key: String,
        dateKey: String
    ) {
        let envelope = Envelope(version: cacheVersion, dateKey: dateKey, payload: value)
        do {
            let data = try JSONEncoder().encode(envelope)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("[CacheManager] encode failed for key '\(key)': \(error)")
            #endif
        }
    }

    /// 移除指定鍵的快取
    static func remove(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Cache Keys（集中管理）

    enum Keys {
        static let weekStats = "cache_weekStats"
        static let institutional = "cache_institutional"
        static let margin = "cache_margin"
        static let candle = "cache_candle"
    }

    // MARK: - 舊快取遷移（一次性）

    /// 清除舊版分離式快取 key（升級後首次呼叫即可）
    static func migrateFromLegacyKeysIfNeeded() {
        let migrationFlag = "cacheManager_migrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationFlag) else { return }

        let legacyKeys = [
            "weekStatsCache", "weekStatsCacheDate",
            "institutionalCache", "institutionalCacheDate",
            "marginCache", "marginCacheDate",
            "candleCache", "candleCacheDate"
        ]
        for key in legacyKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.set(true, forKey: migrationFlag)
    }
}
