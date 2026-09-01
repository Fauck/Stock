import Foundation
import Observation

/// 盤中分析頁籤
enum IntradayTab: String, CaseIterable, Identifiable {
    case volumes = "分價量"
    case trades = "成交明細"
    case bigOrders = "大單追蹤"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .volumes: return "chart.bar.doc.horizontal"
        case .trades: return "list.bullet"
        case .bigOrders: return "exclamationmark.triangle"
        }
    }
}

/// 分價量排序方式
enum VolumeSortMode: String, CaseIterable, Identifiable {
    case byVolume = "依成交量"
    case byPrice = "依價格"

    var id: String { rawValue }
}

/// 大單門檻選項（張）
enum BigOrderThreshold: Int, CaseIterable, Identifiable {
    case t50 = 50
    case t100 = 100
    case t200 = 200
    case t500 = 500

    var id: Int { rawValue }
    var label: String { "\(rawValue)張" }
}

@Observable
final class IntradayAnalysisViewModel {
    // MARK: - Input
    var symbol: String
    var stockName: String = ""
    var resolvedSymbol: String = ""

    // MARK: - Tab & Filter
    var selectedTab: IntradayTab = .volumes
    var volumeSortMode: VolumeSortMode = .byVolume
    var bigOrderThreshold: BigOrderThreshold = .t100

    // MARK: - 分價量資料
    struct VolumeRow: Identifiable {
        let id: Double          // price as id
        let price: Double
        let volume: Int
        let volumeAtBid: Int    // 內盤
        let volumeAtAsk: Int    // 外盤
        let percentage: Double  // 佔總成交量百分比
    }
    var volumeRows: [VolumeRow] = []
    var totalVolume: Int = 0
    var totalBid: Int = 0
    var totalAsk: Int = 0
    var bidAskRatio: Double? = nil  // 外盤/內盤比，nil = 無法計算

    // MARK: - 成交明細
    struct TradeRow: Identifiable {
        let id: Int             // serial
        let time: String
        let price: Double
        let size: Int           // 單筆股數
        let isBigOrder: Bool
    }
    var tradeRows: [TradeRow] = []

    // MARK: - 狀態
    var isLoading = false
    var errorMessage: String? = nil
    var lastUpdated: String? = nil

    private var fetchTask: Task<Void, Never>?

    // MARK: - Computed

    var sortedVolumeRows: [VolumeRow] {
        switch volumeSortMode {
        case .byVolume:
            return volumeRows.sorted { $0.volume > $1.volume }
        case .byPrice:
            return volumeRows.sorted { $0.price > $1.price }
        }
    }

    var maxVolume: Int {
        volumeRows.map(\.volume).max() ?? 0
    }

    var bigOrders: [TradeRow] {
        let thresholdShares = bigOrderThreshold.rawValue * 1000
        return tradeRows.filter { $0.size >= thresholdShares }
    }

    var bigOrderTotalSize: Int {
        bigOrders.reduce(0) { $0 + $1.size }
    }

    // MARK: - Init

    init(symbol: String = "") {
        self.symbol = symbol
    }

    // MARK: - Load

    func load() {
        let input = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        let resolved = StockMapping.resolve(input)
        resolvedSymbol = resolved.symbol
        stockName = resolved.name ?? ""

        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                // 並行取得 trades + volumes
                async let tradesReq = StockService.shared.fetchIntradayTrades(symbol: resolvedSymbol)
                async let volumesReq = StockService.shared.fetchIntradayVolumes(symbol: resolvedSymbol)

                let (tradesResponse, volumesResponse) = try await (tradesReq, volumesReq)

                guard !Task.isCancelled else { return }

                // 處理分價量
                let totalVol = volumesResponse.data.reduce(0) { $0 + $1.volume }
                let totalB = volumesResponse.data.reduce(0) { $0 + $1.volumeAtBid }
                let totalA = volumesResponse.data.reduce(0) { $0 + $1.volumeAtAsk }

                volumeRows = volumesResponse.data.map { item in
                    VolumeRow(
                        id: item.price,
                        price: item.price,
                        volume: item.volume,
                        volumeAtBid: item.volumeAtBid,
                        volumeAtAsk: item.volumeAtAsk,
                        percentage: totalVol > 0 ? Double(item.volume) / Double(totalVol) * 100 : 0
                    )
                }
                totalVolume = totalVol
                totalBid = totalB
                totalAsk = totalA
                bidAskRatio = totalB > 0 ? Double(totalA) / Double(totalB) : nil

                // 處理成交明細
                let thresholdShares = bigOrderThreshold.rawValue * 1000
                tradeRows = tradesResponse.data.map { item in
                    TradeRow(
                        id: item.serial,
                        time: formatTimestamp(item.time),
                        price: item.price,
                        size: item.size,
                        isBigOrder: item.size >= thresholdShares
                    )
                }

                // 更新名稱（如果 API 沒有，使用本地映射）
                if stockName.isEmpty {
                    stockName = resolvedSymbol
                }

                // 更新時間
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                timeFormatter.locale = Locale(identifier: "en_US_POSIX")
                lastUpdated = timeFormatter.string(from: Date())

                isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Formatting

    private func formatTimestamp(_ ms: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        return formatter.string(from: date)
    }

    func formatVolume(_ vol: Int) -> String {
        let lots = vol / 1000
        if lots >= 10_000 {
            return String(format: "%.1f萬張", Double(lots) / 10_000)
        } else if lots > 0 {
            return "\(lots)張"
        }
        return "\(vol)股"
    }
}
