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

    // MARK: - TWSE 三大法人買賣超

    /// 單日法人買賣超
    struct InstitutionalDayData: Sendable {
        let date: String
        let foreignNet: Int      // 外資買賣超（張）
        let trustNet: Int        // 投信買賣超（張）
        let dealerNet: Int       // 自營商買賣超（張）
        let totalNet: Int        // 三大法人合計（張）
    }

    /// 某檔股票的法人統計摘要
    struct InstitutionalSummary: Sendable {
        let days: [InstitutionalDayData]   // 最近 N 日（新→舊）

        var latestForeignNet: Int { days.first?.foreignNet ?? 0 }
        var latestTrustNet: Int { days.first?.trustNet ?? 0 }
        var latestDealerNet: Int { days.first?.dealerNet ?? 0 }
        var latestTotalNet: Int { days.first?.totalNet ?? 0 }
        var latestDate: String { days.first?.date ?? "" }

        /// 連續天數（正=連續買超，負=連續賣超，0=無資料或方向不一致）
        var foreignStreak: Int { Self.streak(days.map(\.foreignNet)) }
        var trustStreak: Int { Self.streak(days.map(\.trustNet)) }
        var totalStreak: Int { Self.streak(days.map(\.totalNet)) }

        private static func streak(_ values: [Int]) -> Int {
            guard let first = values.first, first != 0 else { return 0 }
            let positive = first > 0
            var count = 0
            for v in values {
                if (positive && v > 0) || (!positive && v < 0) {
                    count += 1
                } else {
                    break
                }
            }
            return positive ? count : -count
        }
    }

    /// TWSE 三大法人買賣超 API 回應
    private struct TWSEInstitutionalResponse: Decodable {
        let stat: String?
        let data: [[String]]?
    }

    /// 取得單日全部個股的三大法人買賣超
    /// - Parameter date: 日期格式 "yyyyMMdd"
    /// - Returns: [證券代號: InstitutionalDayData]
    func fetchInstitutionalData(date: String) async throws -> [String: InstitutionalDayData] {
        let urlString = "https://www.twse.com.tw/rwd/zh/fund/T86?date=\(date)&selectType=ALL&response=json"
        guard let url = URL(string: urlString) else {
            throw StockServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StockServiceError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw StockServiceError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(TWSEInstitutionalResponse.self, from: data)
        guard decoded.stat == "OK", let rows = decoded.data, !rows.isEmpty else {
            throw StockServiceError.noData
        }

        var result: [String: InstitutionalDayData] = [:]
        for row in rows where row.count >= 19 {
            let code = row[0].trimmingCharacters(in: .whitespaces)
            let foreignNet = Self.parseShares(row[4])
            let trustNet = Self.parseShares(row[10])
            let dealerNet = Self.parseShares(row[11])
            let totalNet = Self.parseShares(row[18])

            result[code] = InstitutionalDayData(
                date: date,
                foreignNet: foreignNet,
                trustNet: trustNet,
                dealerNet: dealerNet,
                totalNet: totalNet
            )
        }
        return result
    }

    /// 解析帶逗號的股數字串，轉為張數（除以 1000）
    private static func parseShares(_ str: String) -> Int {
        let cleaned = str.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        let shares = Int(cleaned) ?? 0
        return shares / 1000
    }

    // MARK: - TPEx (櫃買) 三大法人買賣超

    /// TPEx 三大法人買賣超 API 回應
    /// 結構：{ "tables": [ { "data": [[String]], ... } ], "stat": "ok" }
    private struct TPExInstitutionalResponse: Decodable {
        let tables: [TPExTable]?
        let stat: String?

        struct TPExTable: Decodable {
            let data: [[String]]?
            let totalCount: Int?
        }
    }

    /// 取得單日櫃買市場（上櫃）個股的三大法人買賣超
    /// - Parameter date: 日期格式 "yyyyMMdd"（會轉換為民國日期格式）
    /// - Returns: [證券代號: InstitutionalDayData]
    func fetchTPExInstitutionalData(date: String) async throws -> [String: InstitutionalDayData] {
        // 將西元 yyyyMMdd 轉為民國 yyy/MM/dd
        guard date.count == 8,
              let year = Int(date.prefix(4)) else {
            throw StockServiceError.invalidURL
        }
        let rocYear = year - 1911
        let rocDate = "\(rocYear)/\(date.dropFirst(4).prefix(2))/\(date.dropFirst(6))"

        let urlString = "https://www.tpex.org.tw/web/stock/3insti/daily_trade/3itrade_hedge_result.php?l=zh-tw&o=json&se=EW&t=D&d=\(rocDate)"
        guard let url = URL(string: urlString) else {
            throw StockServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StockServiceError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw StockServiceError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(TPExInstitutionalResponse.self, from: data)
        guard let rows = decoded.tables?.first?.data, !rows.isEmpty else {
            throw StockServiceError.noData
        }

        // TPEx 24 欄位格式：
        // [0] 代號, [1] 名稱
        // [2-4] 外資及陸資(不含自營商) buy/sell/net
        // [5-7] 外資自營商 buy/sell/net
        // [8-10] 外資及陸資合計 buy/sell/net → net = [10]
        // [11-13] 投信 buy/sell/net → net = [13]
        // [14-16] 自營商(自行買賣) buy/sell/net
        // [17-19] 自營商(避險) buy/sell/net
        // [20-22] 自營商合計 buy/sell/net → net = [22]
        // [23] 三大法人合計
        var result: [String: InstitutionalDayData] = [:]
        for row in rows where row.count >= 24 {
            let code = row[0].trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty else { continue }
            let foreignNet = Self.parseShares(row[10])
            let trustNet = Self.parseShares(row[13])
            let dealerNet = Self.parseShares(row[22])
            let totalNet = Self.parseShares(row[23])

            result[code] = InstitutionalDayData(
                date: date,
                foreignNet: foreignNet,
                trustNet: trustNet,
                dealerNet: dealerNet,
                totalNet: totalNet
            )
        }
        return result
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
