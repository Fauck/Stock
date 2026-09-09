import Foundation

/// K 線歷史資料快取用（共用於 PortfolioListViewModel 與 UnrealizedPnLChartViewModel）
struct CandleCacheData: Codable {
    let dates: [String]      // "yyyy-MM-dd" 格式
    let opens: [Double]
    let closes: [Double]
    let highs: [Double]
    let lows: [Double]
    let volumes: [Int]
}

/// K 線快取 UserDefaults 鍵名
enum CandleCacheKeys {
    static let data = "candleCache"
    static let date = "candleCacheDate"
}
