import Foundation
import Observation

@Observable
final class BuyAnalysisViewModel {

    // MARK: - Input
    var searchText: String = ""

    // MARK: - Output
    var ticker: String = ""
    var stockName: String = ""
    var resolvedSymbol: String = ""

    var currentPrice: Double = 0
    var changePercent: Double?

    var recommendation: TechnicalIndicators.BuyRecommendation?
    var signalSummary: TechnicalIndicators.SignalSummary?
    var allPatterns: [TechnicalIndicators.CandlestickSignal] = []
    var bullishPatterns: [TechnicalIndicators.CandlestickSignal] = []

    var week52High: Double?
    var week52Low: Double?

    var institutionalSummary: StockService.InstitutionalSummary?

    var maDeductions: [TechnicalIndicators.MADeductionInfo] = []
    var volumeProfile: TechnicalIndicators.VolumeProfileResult?

    var isLoading: Bool = false
    var errorMessage: String?
    var hasResult: Bool = false

    // MARK: - Load

    @MainActor
    func load() async {
        let input = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        hasResult = false
        defer { isLoading = false }

        // 解析代號
        let resolved = StockMapping.resolve(input)
        ticker = resolved.symbol
        resolvedSymbol = resolved.symbol
        stockName = resolved.name ?? resolved.symbol

        let formatter = AppDateFormatter.apiDate
        let todayStr = formatter.string(from: Date())
        let fromDate = Calendar.current.date(byAdding: .day, value: -300, to: Date()) ?? Date()
        let fromStr = formatter.string(from: fromDate)

        do {
            // 平行載入：報價 + K 線 + 52 週統計
            async let quoteTask = StockService.shared.fetchQuote(symbol: ticker)
            async let candleTask = StockService.shared.fetchHistoricalCandles(
                symbol: ticker, from: fromStr, to: todayStr
            )
            async let statsTask: StockService.StatsResponse? = {
                try? await StockService.shared.fetchStats(symbol: ticker)
            }()

            let quote = try await quoteTask
            let candleResponse = try await candleTask
            let stats = await statsTask

            currentPrice = quote.lastPrice
            changePercent = quote.changePercent
            if let name = quote.name.nilIfEmpty {
                stockName = name
            }

            week52High = stats?.week52High
            week52Low = stats?.week52Low

            // 整理 K 線資料
            let sorted = candleResponse.data.sorted { $0.date < $1.date }
            let opens = sorted.map(\.open)
            let closes = sorted.map(\.close)
            let highs = sorted.map(\.high)
            let lows = sorted.map(\.low)
            let volumes = sorted.map(\.volume)

            guard !closes.isEmpty else {
                errorMessage = "無法取得 K 線資料"
                return
            }

            // 計算技術指標
            let signal = TechnicalIndicators.computeSignalSummary(
                opens: opens,
                closes: closes,
                highs: highs,
                lows: lows,
                volumes: volumes
            )
            signalSummary = signal

            // K 線型態偵測（最多 10 個）
            let ma5 = TechnicalIndicators.sma(closes: closes, period: 5)
            let ma20 = TechnicalIndicators.sma(closes: closes, period: 20)
            let patterns = TechnicalIndicators.detectCandlestickPatterns(
                opens: opens,
                closes: closes,
                highs: highs,
                lows: lows,
                ma5Values: ma5,
                ma20Values: ma20,
                maxResults: 10
            )
            allPatterns = patterns
            bullishPatterns = patterns.filter { $0.direction == TechnicalIndicators.CandlestickDirection.bullish }

            // 法人資料（best-effort，最近 5 個工作日）
            let instSummary = await fetchInstitutionalSummary()
            institutionalSummary = instSummary

            // 為了買入建議，使用完整型態列表建立自訂 SignalSummary
            let signalForBuy = TechnicalIndicators.SignalSummary(
                ma5Position: signal.ma5Position,
                ma20Position: signal.ma20Position,
                maCross: signal.maCross,
                rsi: signal.rsi,
                rsiSignal: signal.rsiSignal,
                kdjSignal: signal.kdjSignal,
                kdjK: signal.kdjK,
                kdjD: signal.kdjD,
                macdSignal: signal.macdSignal,
                macdDIF: signal.macdDIF,
                macdDEA: signal.macdDEA,
                bollingerSignal: signal.bollingerSignal,
                bollingerUpper: signal.bollingerUpper,
                bollingerMiddle: signal.bollingerMiddle,
                bollingerLower: signal.bollingerLower,
                ma5Value: signal.ma5Value,
                ma20Value: signal.ma20Value,
                recentHigh20: signal.recentHigh20,
                recentLow20: signal.recentLow20,
                volumeSignal: signal.volumeSignal,
                volumeRatio: signal.volumeRatio,
                divergences: signal.divergences,
                candlestickPatterns: patterns,  // 使用完整型態列表
                regime: signal.regime,
                atr: signal.atr, atrPercent: signal.atrPercent,
                adx: signal.adx, plusDI: signal.plusDI, minusDI: signal.minusDI, adxSignal: signal.adxSignal
            )

            recommendation = TechnicalIndicators.computeBuyRecommendation(
                signal: signalForBuy,
                week52High: week52High,
                week52Low: week52Low,
                currentPrice: currentPrice,
                foreignStreak: instSummary?.foreignStreak,
                trustStreak: instSummary?.trustStreak,
                foreignCumulativeNet: instSummary?.foreignCumulativeNet,
                trustCumulativeNet: instSummary?.trustCumulativeNet,
                regime: signal.regime
            )

            // 均線扣抵值分析
            maDeductions = TechnicalIndicators.computeMADeductions(
                closes: closes,
                currentPrice: currentPrice
            )

            // Volume Profile
            volumeProfile = TechnicalIndicators.volumeProfile(
                highs: highs,
                lows: lows,
                closes: closes,
                volumes: volumes.map { Double($0) }
            )

            hasResult = true
        } catch {
            errorMessage = "載入失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - 法人資料

    private func fetchInstitutionalSummary() async -> StockService.InstitutionalSummary? {
        let calendar = Calendar.current
        let today = Date()
        let formatter = AppDateFormatter.cacheDate

        // 產生最近 5 個工作日
        var datesToFetch: [String] = []
        var dayOffset = 0
        while datesToFetch.count < 5 && dayOffset < 10 {
            if let d = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let weekday = calendar.component(.weekday, from: d)
                if weekday != 1 && weekday != 7 {
                    datesToFetch.append(formatter.string(from: d))
                }
            }
            dayOffset += 1
        }

        // 平行抓取 TWSE + TPEx
        let allDayResults = await withTaskGroup(
            of: (String, [String: StockService.InstitutionalDayData]?).self
        ) { group in
            for dateStr in datesToFetch {
                group.addTask {
                    do {
                        let data = try await StockService.shared.fetchInstitutionalData(date: dateStr)
                        return ("TWSE_\(dateStr)", data)
                    } catch {
                        return ("TWSE_\(dateStr)", nil)
                    }
                }
                group.addTask {
                    do {
                        let data = try await StockService.shared.fetchTPExInstitutionalData(date: dateStr)
                        return ("TPEx_\(dateStr)", data)
                    } catch {
                        return ("TPEx_\(dateStr)", nil)
                    }
                }
            }

            var twseMap: [String: [String: StockService.InstitutionalDayData]] = [:]
            var tpexMap: [String: [String: StockService.InstitutionalDayData]] = [:]
            for await (key, data) in group {
                guard let data else { continue }
                if key.hasPrefix("TWSE_") {
                    twseMap[String(key.dropFirst(5))] = data
                } else if key.hasPrefix("TPEx_") {
                    tpexMap[String(key.dropFirst(5))] = data
                }
            }

            var merged: [(String, [String: StockService.InstitutionalDayData])] = []
            let allDates = Set(twseMap.keys).union(tpexMap.keys)
            for dateStr in allDates {
                var dayData = twseMap[dateStr] ?? [:]
                if let tpexData = tpexMap[dateStr] {
                    dayData.merge(tpexData) { existing, _ in existing }
                }
                merged.append((dateStr, dayData))
            }
            return merged.sorted { $0.0 > $1.0 }
        }

        // 提取此 ticker 的法人資料
        var days: [StockService.InstitutionalDayData] = []
        for (_, dayMap) in allDayResults {
            if let dayData = dayMap[ticker] {
                days.append(dayData)
            }
        }

        guard !days.isEmpty else { return nil }
        return StockService.InstitutionalSummary(days: days)
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
