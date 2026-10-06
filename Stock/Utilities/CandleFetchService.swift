import Foundation

/// K 線快取讀寫 + 並行抓取服務（無狀態）
enum CandleFetchService {

    // MARK: - Fetch Spec

    /// 單一 ticker 的抓取規格
    struct FetchSpec: Sendable {
        let ticker: String
        let symbol: String
        let from: String   // "yyyy-MM-dd"
    }

    // MARK: - Cache Read / Write

    /// 讀取當日 K 線快取。若日期不符或版本不符，回傳 nil。
    static func readCandleCache(forDate todayCacheStr: String) -> [String: CandleCacheData]? {
        CacheManager.read([String: CandleCacheData].self,
                          forKey: CacheManager.Keys.candle,
                          validDate: todayCacheStr)
    }

    /// 寫入 K 線快取
    static func writeCandleCache(_ cache: [String: CandleCacheData], forDate todayCacheStr: String) {
        CacheManager.write(cache, forKey: CacheManager.Keys.candle, dateKey: todayCacheStr)
    }

    /// 今日快取日期鍵 "yyyyMMdd"
    static func todayCacheString() -> String {
        AppDateFormatter.cacheDate.string(from: Date())
    }

    // MARK: - Parallel Fetch

    /// 並行抓取多檔 K 線，回傳 [(ticker, CandleCacheData)]
    static func fetchCandles(
        specs: [FetchSpec],
        to: String
    ) async -> [(ticker: String, candle: CandleCacheData)] {
        guard !specs.isEmpty else { return [] }

        return await withTaskGroup(of: (String, CandleCacheData)?.self) { group in
            for spec in specs {
                group.addTask {
                    do {
                        let response = try await StockService.shared.fetchHistoricalCandles(
                            symbol: spec.symbol, from: spec.from, to: to
                        )
                        let sorted = response.data.sorted { $0.date < $1.date }
                        let candle = CandleCacheData(
                            dates: sorted.map(\.date),
                            opens: sorted.map(\.open),
                            closes: sorted.map(\.close),
                            highs: sorted.map(\.high),
                            lows: sorted.map(\.low),
                            volumes: sorted.map(\.volume)
                        )
                        return (spec.ticker, candle)
                    } catch {
                        return nil
                    }
                }
            }
            var collected: [(String, CandleCacheData)] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }
    }

    // MARK: - Ticker Resolution

    /// 將 tickers 映射為 API symbols，回傳 (mapping, uniqueSymbols)
    static func mapTickersToSymbols(_ tickers: [String]) -> (mapping: [String: String], symbols: [String]) {
        var mapping: [String: String] = [:]
        for ticker in tickers {
            mapping[ticker] = StockMapping.resolve(ticker).symbol
        }
        return (mapping, Array(Set(mapping.values)))
    }
}
