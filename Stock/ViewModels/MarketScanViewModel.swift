import Foundation
import Observation

/// 市場掃描排行類型
enum ScanCategory: String, CaseIterable, Identifiable {
    case topGainers = "漲幅排行"
    case topLosers = "跌幅排行"
    case mostActive = "成交量排行"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .topGainers: return "arrow.up.right"
        case .topLosers: return "arrow.down.right"
        case .mostActive: return "chart.bar.fill"
        }
    }
}

/// 市場選擇
enum ScanMarket: String, CaseIterable, Identifiable {
    case tse = "上市"
    case otc = "上櫃"

    var id: String { rawValue }

    var apiValue: String {
        switch self {
        case .tse: return "TSE"
        case .otc: return "OTC"
        }
    }
}

/// 掃描結果項目（View 用）
struct ScanItem: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let closePrice: Double
    let change: Double
    let changePercent: Double
    let volume: Int
    let tradeValue: Double
}

@Observable
final class MarketScanViewModel {
    var category: ScanCategory = .topGainers
    var market: ScanMarket = .tse

    var items: [ScanItem] = []
    var isLoading = false
    var errorMessage: String? = nil
    var lastUpdated: String? = nil

    private var fetchTask: Task<Void, Never>?

    func load() {
        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                let response: StockService.SnapshotResponse

                switch category {
                case .topGainers:
                    response = try await StockService.shared.fetchMovers(
                        market: market.apiValue, direction: "up", change: "percent"
                    )
                case .topLosers:
                    response = try await StockService.shared.fetchMovers(
                        market: market.apiValue, direction: "down", change: "percent"
                    )
                case .mostActive:
                    response = try await StockService.shared.fetchActives(
                        market: market.apiValue, trade: "volume"
                    )
                }

                guard !Task.isCancelled else { return }

                items = response.data.prefix(20).map { item in
                    ScanItem(
                        id: item.symbol,
                        symbol: item.symbol,
                        name: item.name.replacingOccurrences(of: "*", with: ""),
                        closePrice: item.closePrice ?? 0,
                        change: item.change ?? 0,
                        changePercent: item.changePercent ?? 0,
                        volume: item.tradeVolume ?? 0,
                        tradeValue: item.tradeValue ?? 0
                    )
                }

                // 更新時間
                if let time = response.time {
                    let trimmed = String(time.prefix(8)) // "HH:mm:ss"
                    lastUpdated = trimmed
                }

                isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// 切換分類時自動重新載入
    func selectCategory(_ cat: ScanCategory) {
        guard cat != category else { return }
        category = cat
        load()
    }

    /// 切換市場時自動重新載入
    func selectMarket(_ mkt: ScanMarket) {
        guard mkt != market else { return }
        market = mkt
        load()
    }

    func formatVolume(_ volume: Int) -> String {
        if volume >= 10_000 {
            return String(format: "%.0f張", Double(volume) / 1_000)
        } else if volume >= 1_000 {
            return String(format: "%.1f張", Double(volume) / 1_000)
        }
        return "\(volume)股"
    }

    func formatTradeValue(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1f億", value / 100_000_000)
        } else if value >= 100_000_000 {
            return String(format: "%.0f億", value / 100_000_000)
        } else if value >= 10_000_000 {
            return String(format: "%.0f萬", value / 10_000)
        }
        return String(format: "%.0f", value)
    }
}
