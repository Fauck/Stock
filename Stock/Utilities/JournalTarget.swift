import Foundation

/// 目標價 / 停損價（從交易日誌取得）
struct JournalTarget {
    let targetPrice: Double?
    let stopLoss: Double?
}
