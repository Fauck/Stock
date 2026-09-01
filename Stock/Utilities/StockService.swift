import Foundation

/// 富果 API 即時股價服務
actor StockService {
    static let shared = StockService()

    private let baseURL = "https://api.fugle.tw/marketdata/v1.0/stock"
    private let apiKey = Secrets.fugleAPIKey

    // MARK: - Response Models   

    struct QuoteResponse: Decodable {
        let symbol: String?
        let name: String?
        let lastPrice: Double?
        let closePrice: Double?
        let previousClose: Double?
        let change: Double?
        let changePercent: Double?
    }

    struct TickerResponse: Decodable {
        let symbol: String?
        let name: String?
        let exchange: String?
        let previousClose: Double?
    }

    /// 歷史 K 線單根蠟燭資料
    struct CandleData: Decodable, Sendable {
        let date: String
        let open: Double
        let high: Double
        let low: Double
        let close: Double
        let volume: Int
    }

    /// 歷史 K 線 API 回應
    struct HistoricalCandlesResponse: Decodable {
        let symbol: String?
        let data: [CandleData]
    }

    /// 查詢結果：包含即時價格與股票名稱
    struct StockQuoteResult: Sendable {
        let symbol: String
        let name: String
        let lastPrice: Double
        let previousClose: Double?
        let change: Double?
        let changePercent: Double?
    }

    // MARK: - API Calls

    /// 取得即時報價（含股名）
    func fetchQuote(symbol: String) async throws -> StockQuoteResult {
        let urlString = "\(baseURL)/intraday/quote/\(symbol)"
        guard let url = URL(string: urlString) else {
            throw StockServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw StockServiceError.httpError(httpResponse.statusCode)
        }

        let quote = try JSONDecoder().decode(QuoteResponse.self, from: data)

        // 優先順序：lastPrice → closePrice → previousClose
        let bestPrice = [quote.lastPrice, quote.closePrice, quote.previousClose]
            .compactMap { $0 }
            .first { $0 > 0 }

        guard let price = bestPrice else {
            throw StockServiceError.noPrice
        }

        return StockQuoteResult(
            symbol: quote.symbol ?? symbol,
            name: quote.name ?? symbol,
            lastPrice: price,
            previousClose: quote.previousClose,
            change: quote.change,
            changePercent: quote.changePercent
        )
    }

    /// 取得股票基本資訊（含中文名稱）
    func fetchTickerInfo(symbol: String) async throws -> TickerResponse {
        let urlString = "\(baseURL)/intraday/ticker/\(symbol)"
        guard let url = URL(string: urlString) else {
            throw StockServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw StockServiceError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(TickerResponse.self, from: data)
    }

    /// 取得歷史 K 線資料（最多回溯 1 年）
    func fetchHistoricalCandles(
        symbol: String,
        from: String,
        to: String
    ) async throws -> HistoricalCandlesResponse {
        let urlString = "\(baseURL)/historical/candles/\(symbol)?from=\(from)&to=\(to)&fields=open,high,low,close,volume"
        guard let url = URL(string: urlString) else {
            throw StockServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw StockServiceError.httpError(httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(HistoricalCandlesResponse.self, from: data)

        guard !result.data.isEmpty else {
            throw StockServiceError.noData
        }

        return result
    }

    // MARK: - Intraday Trades & Volumes API

    /// 逐筆成交項目
    struct IntradayTradeItem: Decodable, Sendable {
        let bid: Double?
        let ask: Double?
        let price: Double
        let size: Int
        let volume: Int
        let time: Int       // Unix timestamp (ms)
        let serial: Int
    }

    /// 逐筆成交 API 回應
    struct IntradayTradesResponse: Decodable, Sendable {
        let date: String?
        let symbol: String?
        let data: [IntradayTradeItem]
    }

    /// 分價量項目
    struct IntradayVolumeItem: Decodable, Sendable {
        let price: Double
        let volume: Int
        let volumeAtBid: Int
        let volumeAtAsk: Int
    }

    /// 分價量 API 回應
    struct IntradayVolumesResponse: Decodable, Sendable {
        let date: String?
        let symbol: String?
        let data: [IntradayVolumeItem]
    }

    /// 取得當日逐筆成交明細
    func fetchIntradayTrades(symbol: String, limit: Int = 200) async throws -> IntradayTradesResponse {
        let urlString = "\(baseURL)/intraday/trades/\(symbol)?limit=\(limit)&sort=desc"
        guard let url = URL(string: urlString) else { throw StockServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StockServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw StockServiceError.httpError(http.statusCode) }

        return try JSONDecoder().decode(IntradayTradesResponse.self, from: data)
    }

    /// 取得當日分價量統計
    func fetchIntradayVolumes(symbol: String) async throws -> IntradayVolumesResponse {
        let urlString = "\(baseURL)/intraday/volumes/\(symbol)"
        guard let url = URL(string: urlString) else { throw StockServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StockServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw StockServiceError.httpError(http.statusCode) }

        return try JSONDecoder().decode(IntradayVolumesResponse.self, from: data)
    }

    // MARK: - Historical Stats API

    /// 52 週統計回應
    struct StatsResponse: Decodable, Sendable {
        let symbol: String?
        let name: String?
        let closePrice: Double?
        let week52High: Double?
        let week52Low: Double?
    }

    /// 取得個股 52 週統計（高低點）
    func fetchStats(symbol: String) async throws -> StatsResponse {
        let urlString = "\(baseURL)/historical/stats/\(symbol)"
        guard let url = URL(string: urlString) else { throw StockServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StockServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw StockServiceError.httpError(http.statusCode) }

        return try JSONDecoder().decode(StatsResponse.self, from: data)
    }

    // MARK: - Snapshot API

    /// 快照個股項目（movers / actives 共用）
    struct SnapshotItem: Decodable, Sendable {
        let symbol: String
        let name: String
        let openPrice: Double?
        let highPrice: Double?
        let lowPrice: Double?
        let closePrice: Double?
        let change: Double?
        let changePercent: Double?
        let tradeVolume: Int?
        let tradeValue: Double?
    }

    /// 快照 API 回應
    struct SnapshotResponse: Decodable {
        let date: String?
        let time: String?
        let market: String?
        let data: [SnapshotItem]
    }

    /// 漲跌幅排行
    /// - Parameters:
    ///   - market: 市場（TSE / OTC）
    ///   - direction: up = 漲幅、down = 跌幅
    ///   - change: percent = 百分比、value = 點數
    func fetchMovers(
        market: String = "TSE",
        direction: String = "up",
        change: String = "percent"
    ) async throws -> SnapshotResponse {
        let urlString = "\(baseURL)/snapshot/movers/\(market)?direction=\(direction)&change=\(change)&type=COMMONSTOCK"
        guard let url = URL(string: urlString) else { throw StockServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StockServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw StockServiceError.httpError(http.statusCode) }

        return try JSONDecoder().decode(SnapshotResponse.self, from: data)
    }

    /// 成交量/成交值排行
    /// - Parameters:
    ///   - market: 市場（TSE / OTC）
    ///   - trade: volume = 成交量、value = 成交值
    func fetchActives(
        market: String = "TSE",
        trade: String = "volume"
    ) async throws -> SnapshotResponse {
        let urlString = "\(baseURL)/snapshot/actives/\(market)?trade=\(trade)&type=COMMONSTOCK"
        guard let url = URL(string: urlString) else { throw StockServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StockServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw StockServiceError.httpError(http.statusCode) }

        return try JSONDecoder().decode(SnapshotResponse.self, from: data)
    }

    /// 批次取得多檔即時報價
    func fetchQuotes(symbols: [String]) async -> [String: StockQuoteResult] {
        var results: [String: StockQuoteResult] = [:]
        await withTaskGroup(of: (String, StockQuoteResult?).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        let result = try await self.fetchQuote(symbol: symbol)
                        return (symbol, result)
                    } catch {
                        #if DEBUG
                        print("[StockService] 查詢 \(symbol) 失敗: \(error.localizedDescription)")
                        #endif
                        return (symbol, nil)
                    }
                }
            }
            for await (symbol, result) in group {
                if let result {
                    results[symbol] = result
                }
            }
        }
        return results
    }
}

// MARK: - Errors

enum StockServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noPrice
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無效的 API 網址"
        case .invalidResponse: return "無效的伺服器回應"
        case .httpError(let code): return "API 錯誤（HTTP \(code)）"
        case .noPrice: return "目前無即時報價"
        case .noData: return "查無歷史資料"
        }
    }
}
