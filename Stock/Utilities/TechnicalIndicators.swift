import Foundation

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// 技術指標計算工具（純函數，無狀態）
enum TechnicalIndicators {

    // MARK: - SMA

    /// 簡單移動平均線 (SMA)
    /// 使用滑動視窗 O(n) 演算法
    /// - Parameters:
    ///   - closes: 收盤價序列（按日期升序）
    ///   - period: 週期（如 5, 20）
    /// - Returns: 與 closes 等長陣列，前 (period - 1) 個元素為 nil
    static func sma(closes: [Double], period: Int) -> [Double?] {
        guard period > 0, closes.count >= period else {
            return Array(repeating: nil, count: closes.count)
        }

        var result: [Double?] = Array(repeating: nil, count: closes.count)
        var windowSum = closes[0..<period].reduce(0, +)
        result[period - 1] = windowSum / Double(period)

        for i in period..<closes.count {
            windowSum += closes[i] - closes[i - period]
            result[i] = windowSum / Double(period)
        }

        return result
    }

    // MARK: - RSI

    /// RSI (Relative Strength Index)
    /// 使用 Wilder's smoothing method
    /// - Parameters:
    ///   - closes: 收盤價序列（按日期升序）
    ///   - period: RSI 週期（常用 14）
    /// - Returns: RSI 值 (0~100)，前 period 個為 nil
    static func rsi(closes: [Double], period: Int = 14) -> [Double?] {
        guard period > 0, closes.count > period else {
            return Array(repeating: nil, count: closes.count)
        }

        var result: [Double?] = Array(repeating: nil, count: closes.count)

        // 計算每日漲跌
        var gains: [Double] = []
        var losses: [Double] = []
        for i in 1..<closes.count {
            let change = closes[i] - closes[i - 1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }

        // 初始平均（SMA）
        let initialGain = gains[0..<period].reduce(0, +) / Double(period)
        let initialLoss = losses[0..<period].reduce(0, +) / Double(period)

        var avgGain = initialGain
        var avgLoss = initialLoss

        if avgLoss == 0 {
            result[period] = 100
        } else {
            result[period] = 100 - 100 / (1 + avgGain / avgLoss)
        }

        // Wilder's smoothing
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)

            if avgLoss == 0 {
                result[i + 1] = 100
            } else {
                result[i + 1] = 100 - 100 / (1 + avgGain / avgLoss)
            }
        }

        return result
    }

    // MARK: - KDJ

    /// KDJ 指標結果
    struct KDJResult: Sendable {
        let k: Double
        let d: Double
        let j: Double
    }

    /// KDJ 隨機指標
    /// - Parameters:
    ///   - highs: 最高價序列
    ///   - lows: 最低價序列
    ///   - closes: 收盤價序列
    ///   - period: RSV 週期（常用 9）
    ///   - kSmooth: K 值平滑係數（常用 3）
    ///   - dSmooth: D 值平滑係數（常用 3）
    /// - Returns: KDJ 值陣列，前 (period - 1) 個為 nil
    static func kdj(
        highs: [Double],
        lows: [Double],
        closes: [Double],
        period: Int = 9,
        kSmooth: Int = 3,
        dSmooth: Int = 3
    ) -> [KDJResult?] {
        let count = closes.count
        guard count == highs.count, count == lows.count, count >= period else {
            return Array(repeating: nil, count: count)
        }

        var result: [KDJResult?] = Array(repeating: nil, count: count)

        var k: Double = 50 // 初始 K 值
        var d: Double = 50 // 初始 D 值

        for i in (period - 1)..<count {
            // 計算 RSV = (Close - LowestLow) / (HighestHigh - LowestLow) × 100
            let windowHighs = highs[(i - period + 1)...i]
            let windowLows = lows[(i - period + 1)...i]
            let highestHigh = windowHighs.max() ?? closes[i]
            let lowestLow = windowLows.min() ?? closes[i]

            let rsv: Double
            if highestHigh == lowestLow {
                rsv = 50
            } else {
                rsv = (closes[i] - lowestLow) / (highestHigh - lowestLow) * 100
            }

            // K = 前K × (kSmooth-1)/kSmooth + RSV × 1/kSmooth
            k = k * Double(kSmooth - 1) / Double(kSmooth) + rsv / Double(kSmooth)
            // D = 前D × (dSmooth-1)/dSmooth + K × 1/dSmooth
            d = d * Double(dSmooth - 1) / Double(dSmooth) + k / Double(dSmooth)
            // J = 3K - 2D
            let j = 3 * k - 2 * d

            result[i] = KDJResult(k: k, d: d, j: j)
        }

        return result
    }

    // MARK: - EMA

    /// 指數移動平均線 (EMA)
    /// - Parameters:
    ///   - values: 數值序列（按日期升序）
    ///   - period: 週期
    /// - Returns: 與 values 等長陣列，前 (period - 1) 個為 nil
    static func ema(values: [Double], period: Int) -> [Double?] {
        guard period > 0, values.count >= period else {
            return Array(repeating: nil, count: values.count)
        }

        var result: [Double?] = Array(repeating: nil, count: values.count)
        let multiplier = 2.0 / Double(period + 1)

        // 初始值為前 period 個的 SMA
        let initialSMA = values[0..<period].reduce(0, +) / Double(period)
        result[period - 1] = initialSMA

        var prev = initialSMA
        for i in period..<values.count {
            let emaVal = (values[i] - prev) * multiplier + prev
            result[i] = emaVal
            prev = emaVal
        }

        return result
    }

    // MARK: - MACD

    /// MACD 指標結果
    struct MACDResult: Sendable {
        let dif: Double   // DIF = EMA12 - EMA26
        let dea: Double   // DEA = DIF 的 9 日 EMA (信號線)
        let histogram: Double // 柱狀體 = DIF - DEA
    }

    /// MACD(12, 26, 9) 指標計算
    static func macd(
        closes: [Double],
        fastPeriod: Int = 12,
        slowPeriod: Int = 26,
        signalPeriod: Int = 9
    ) -> [MACDResult?] {
        let count = closes.count
        guard count >= slowPeriod else {
            return Array(repeating: nil, count: count)
        }

        let ema12 = ema(values: closes, period: fastPeriod)
        let ema26 = ema(values: closes, period: slowPeriod)

        // DIF = EMA12 - EMA26
        var difs: [Double?] = Array(repeating: nil, count: count)
        for i in 0..<count {
            if let e12 = ema12[i], let e26 = ema26[i] {
                difs[i] = e12 - e26
            }
        }

        // DEA = DIF 的 signalPeriod 日 EMA
        // 找到第一個非 nil 的 DIF 作為起點
        let difValues = difs.compactMap { $0 }
        guard difValues.count >= signalPeriod else {
            return Array(repeating: nil, count: count)
        }

        let difStartIdx = difs.firstIndex(where: { $0 != nil }) ?? 0
        let multiplier = 2.0 / Double(signalPeriod + 1)

        var result: [MACDResult?] = Array(repeating: nil, count: count)
        var dea: Double? = nil
        var difCount = 0

        for i in difStartIdx..<count {
            guard let difVal = difs[i] else { continue }
            difCount += 1

            if difCount < signalPeriod {
                continue
            } else if difCount == signalPeriod {
                // DEA 初始值 = 前 signalPeriod 個 DIF 的 SMA
                var sum = 0.0
                var found = 0
                for j in stride(from: i, through: 0, by: -1) {
                    if let d = difs[j] {
                        sum += d
                        found += 1
                        if found == signalPeriod { break }
                    }
                }
                dea = sum / Double(signalPeriod)
            } else {
                dea = (difVal - dea!) * multiplier + dea!
            }

            if let deaVal = dea {
                result[i] = MACDResult(dif: difVal, dea: deaVal, histogram: difVal - deaVal)
            }
        }

        return result
    }

    // MARK: - Bollinger Bands

    /// 布林通道結果
    struct BollingerResult: Sendable {
        let middle: Double  // 中軌 = SMA20
        let upper: Double   // 上軌 = 中軌 + 2σ
        let lower: Double   // 下軌 = 中軌 - 2σ
        let bandwidth: Double // 帶寬 = (上軌 - 下軌) / 中軌
    }

    /// 布林通道 (Bollinger Bands)
    static func bollingerBands(
        closes: [Double],
        period: Int = 20,
        multiplier: Double = 2.0
    ) -> [BollingerResult?] {
        let count = closes.count
        guard count >= period else {
            return Array(repeating: nil, count: count)
        }

        var result: [BollingerResult?] = Array(repeating: nil, count: count)

        for i in (period - 1)..<count {
            let window = Array(closes[(i - period + 1)...i])
            let mean = window.reduce(0, +) / Double(period)
            let variance = window.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(period)
            let stdDev = sqrt(variance)

            let upper = mean + multiplier * stdDev
            let lower = mean - multiplier * stdDev
            let bandwidth = mean > 0 ? (upper - lower) / mean : 0

            result[i] = BollingerResult(middle: mean, upper: upper, lower: lower, bandwidth: bandwidth)
        }

        return result
    }

    // MARK: - Divergence Detection

    /// 背離類型
    enum DivergenceType: Sendable {
        case bearish  // 頂背離：價格新高，指標未新高
        case bullish  // 底背離：價格新低，指標未新低
    }

    /// 單一背離信號
    struct DivergenceSignal: Sendable, Identifiable {
        let id = UUID()
        let indicator: String      // "RSI" / "MACD"
        let type: DivergenceType
        let pricePoint1: Double    // 第一個極值的價格（較早）
        let pricePoint2: Double    // 第二個極值的價格（較近期）
        let indicatorPoint1: Double
        let indicatorPoint2: Double
        let barsAgo: Int           // 第一個極值距今幾根 K 棒
    }

    /// 找出局部極值（高點或低點）
    /// - order: 左右各幾根 K 棒必須比極值低/高
    private static func findLocalExtremes(
        values: [Double],
        startIndex: Int,
        order: Int = 5,
        findHighs: Bool
    ) -> [(index: Int, value: Double)] {
        var extremes: [(index: Int, value: Double)] = []
        guard values.count > order * 2 else { return extremes }

        let end = values.count - order
        for i in max(startIndex, order)..<end {
            var isExtreme = true
            for j in 1...order {
                if findHighs {
                    if values[i] <= values[i - j] || values[i] <= values[i + j] {
                        isExtreme = false
                        break
                    }
                } else {
                    if values[i] >= values[i - j] || values[i] >= values[i + j] {
                        isExtreme = false
                        break
                    }
                }
            }
            if isExtreme {
                extremes.append((index: i, value: values[i]))
            }
        }
        return extremes
    }

    /// 偵測 RSI 和 MACD 的頂背離 / 底背離
    static func detectDivergences(
        closes: [Double],
        highs: [Double],
        lows: [Double],
        rsiValues: [Double?],
        macdValues: [MACDResult?],
        lookback: Int = 40,
        minSwingPct: Double = 2.0
    ) -> [DivergenceSignal] {
        let count = closes.count
        guard count >= lookback else { return [] }

        let startIdx = count - lookback
        var signals: [DivergenceSignal] = []

        // ── 頂背離：比較局部高點 ──
        let priceHighs = findLocalExtremes(values: highs, startIndex: startIdx, order: 3, findHighs: true)

        if priceHighs.count >= 2 {
            let h1 = priceHighs[priceHighs.count - 2]  // 較早的高點
            let h2 = priceHighs[priceHighs.count - 1]  // 較近的高點

            // 間隔至少 5 根 K 棒
            if h2.index - h1.index >= 5 {
                let swingPct = abs(h2.value - h1.value) / h1.value * 100
                // 價格新高（或接近等高）
                if h2.value >= h1.value && swingPct >= minSwingPct * 0.1 {
                    // RSI 頂背離
                    if let rsi1 = rsiValues[safe: h1.index] ?? nil,
                       let rsi2 = rsiValues[safe: h2.index] ?? nil,
                       rsi2 < rsi1 {
                        signals.append(DivergenceSignal(
                            indicator: "RSI",
                            type: .bearish,
                            pricePoint1: h1.value,
                            pricePoint2: h2.value,
                            indicatorPoint1: rsi1,
                            indicatorPoint2: rsi2,
                            barsAgo: count - 1 - h1.index
                        ))
                    }
                    // MACD 頂背離
                    if let macd1 = macdValues[safe: h1.index] ?? nil,
                       let macd2 = macdValues[safe: h2.index] ?? nil,
                       macd2.dif < macd1.dif {
                        signals.append(DivergenceSignal(
                            indicator: "MACD",
                            type: .bearish,
                            pricePoint1: h1.value,
                            pricePoint2: h2.value,
                            indicatorPoint1: macd1.dif,
                            indicatorPoint2: macd2.dif,
                            barsAgo: count - 1 - h1.index
                        ))
                    }
                }
            }
        }

        // ── 底背離：比較局部低點 ──
        let priceLows = findLocalExtremes(values: lows, startIndex: startIdx, order: 3, findHighs: false)

        if priceLows.count >= 2 {
            let l1 = priceLows[priceLows.count - 2]  // 較早的低點
            let l2 = priceLows[priceLows.count - 1]  // 較近的低點

            if l2.index - l1.index >= 5 {
                let swingPct = abs(l2.value - l1.value) / l1.value * 100
                // 價格新低（或接近等低）
                if l2.value <= l1.value && swingPct >= minSwingPct * 0.1 {
                    // RSI 底背離
                    if let rsi1 = rsiValues[safe: l1.index] ?? nil,
                       let rsi2 = rsiValues[safe: l2.index] ?? nil,
                       rsi2 > rsi1 {
                        signals.append(DivergenceSignal(
                            indicator: "RSI",
                            type: .bullish,
                            pricePoint1: l1.value,
                            pricePoint2: l2.value,
                            indicatorPoint1: rsi1,
                            indicatorPoint2: rsi2,
                            barsAgo: count - 1 - l1.index
                        ))
                    }
                    // MACD 底背離
                    if let macd1 = macdValues[safe: l1.index] ?? nil,
                       let macd2 = macdValues[safe: l2.index] ?? nil,
                       macd2.dif > macd1.dif {
                        signals.append(DivergenceSignal(
                            indicator: "MACD",
                            type: .bullish,
                            pricePoint1: l1.value,
                            pricePoint2: l2.value,
                            indicatorPoint1: macd1.dif,
                            indicatorPoint2: macd2.dif,
                            barsAgo: count - 1 - l1.index
                        ))
                    }
                }
            }
        }

        return signals
    }

    // MARK: - Candlestick Pattern Detection

    /// K 線型態類型
    enum CandlestickPatternType: String, Sendable {
        case hammer = "槌子線"
        case hangingMan = "上吊線"
        case doji = "十字星"
        case shootingStar = "流星線"
        case bullishEngulfing = "多頭吞噬"
        case bearishEngulfing = "空頭吞噬"
        case morningStar = "晨星"
        case eveningStar = "夜星"
    }

    /// K 線型態方向
    enum CandlestickDirection: Sendable {
        case bullish
        case bearish
        case neutral
    }

    /// K 線型態可靠度
    enum CandlestickReliability: String, Sendable {
        case high = "高"
        case medium = "中"
        case low = "低"
    }

    /// 單一 K 線型態信號
    struct CandlestickSignal: Sendable, Identifiable {
        let id = UUID()
        let pattern: CandlestickPatternType
        let direction: CandlestickDirection
        let reliability: CandlestickReliability
        let barsAgo: Int
        let description: String
    }

    // MARK: Candlestick Helpers

    private static func bodySize(_ open: Double, _ close: Double) -> Double {
        abs(close - open)
    }

    private static func upperShadow(_ open: Double, _ close: Double, _ high: Double) -> Double {
        high - max(open, close)
    }

    private static func lowerShadow(_ open: Double, _ close: Double, _ low: Double) -> Double {
        min(open, close) - low
    }

    private static func candleRange(_ high: Double, _ low: Double) -> Double {
        high - low
    }

    private static func isBullishCandle(_ open: Double, _ close: Double) -> Bool {
        close >= open
    }

    private static func isUptrend(
        index: Int, ma5: [Double?], ma20: [Double?], closes: [Double]
    ) -> Bool {
        if let m5 = ma5[safe: index] ?? nil, let m20 = ma20[safe: index] ?? nil {
            return m5 > m20
        }
        if let m20 = ma20[safe: index] ?? nil {
            return closes[index] > m20
        }
        return false
    }

    private static func isDowntrend(
        index: Int, ma5: [Double?], ma20: [Double?], closes: [Double]
    ) -> Bool {
        if let m5 = ma5[safe: index] ?? nil, let m20 = ma20[safe: index] ?? nil {
            return m5 < m20
        }
        if let m20 = ma20[safe: index] ?? nil {
            return closes[index] < m20
        }
        return false
    }

    /// 偵測近期 K 線型態（掃描最近 5 根 K 棒）
    static func detectCandlestickPatterns(
        opens: [Double],
        closes: [Double],
        highs: [Double],
        lows: [Double],
        ma5Values: [Double?],
        ma20Values: [Double?]
    ) -> [CandlestickSignal] {
        let count = opens.count
        guard count >= 5 else { return [] }

        var signals: [CandlestickSignal] = []
        let scanStart = count - 5

        // ── 三根型態（晨星 / 夜星）──
        for i in max(scanStart, 2)..<count {
            let barsAgo = count - 1 - i
            let o0 = opens[i - 2], c0 = closes[i - 2], h0 = highs[i - 2], l0 = lows[i - 2]
            let o1 = opens[i - 1], c1 = closes[i - 1]
            let o2 = opens[i], c2 = closes[i]

            let body0 = bodySize(o0, c0)
            let body1 = bodySize(o1, c1)
            let body2 = bodySize(o2, c2)
            let range0 = candleRange(h0, l0)

            guard range0 > 0 && body0 > range0 * 0.3 else { continue }

            // 晨星：大紅 → 小實體 → 大綠，收回一半以上
            if !isBullishCandle(o0, c0)
                && body1 < body0 * 0.3
                && isBullishCandle(o2, c2)
                && body2 > body0 * 0.3
                && c2 > (o0 + c0) / 2
                && isDowntrend(index: i - 2, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .morningStar,
                    direction: .bullish,
                    reliability: .high,
                    barsAgo: barsAgo,
                    description: "大陰線→小實體→大陽線，底部反轉訊號"
                ))
            }

            // 夜星：大綠 → 小實體 → 大紅，收回一半以上
            if isBullishCandle(o0, c0)
                && body1 < body0 * 0.3
                && !isBullishCandle(o2, c2)
                && body2 > body0 * 0.3
                && c2 < (o0 + c0) / 2
                && isUptrend(index: i - 2, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .eveningStar,
                    direction: .bearish,
                    reliability: .high,
                    barsAgo: barsAgo,
                    description: "大陽線→小實體→大陰線，頂部反轉訊號"
                ))
            }
        }

        // ── 兩根型態（吞噬）──
        for i in max(scanStart, 1)..<count {
            let barsAgo = count - 1 - i
            let prevO = opens[i - 1], prevC = closes[i - 1]
            let curO = opens[i], curC = closes[i]

            let prevBody = bodySize(prevO, prevC)
            let curBody = bodySize(curO, curC)

            guard curBody > prevBody && prevBody > 0 else { continue }

            let curBodyTop = max(curO, curC)
            let curBodyBot = min(curO, curC)
            let prevBodyTop = max(prevO, prevC)
            let prevBodyBot = min(prevO, prevC)

            // 多頭吞噬：前紅後綠，後實體完全包住前實體
            if !isBullishCandle(prevO, prevC)
                && isBullishCandle(curO, curC)
                && curBodyBot <= prevBodyBot
                && curBodyTop >= prevBodyTop
                && isDowntrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .bullishEngulfing,
                    direction: .bullish,
                    reliability: .high,
                    barsAgo: barsAgo,
                    description: "陽線完全吞噬前一根陰線，底部反轉訊號"
                ))
            }

            // 空頭吞噬：前綠後紅，後實體完全包住前實體
            if isBullishCandle(prevO, prevC)
                && !isBullishCandle(curO, curC)
                && curBodyBot <= prevBodyBot
                && curBodyTop >= prevBodyTop
                && isUptrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .bearishEngulfing,
                    direction: .bearish,
                    reliability: .high,
                    barsAgo: barsAgo,
                    description: "陰線完全吞噬前一根陽線，頂部反轉訊號"
                ))
            }
        }

        // ── 單根型態（槌子 / 上吊 / 流星 / 十字星）──
        for i in scanStart..<count {
            let barsAgo = count - 1 - i
            let o = opens[i], c = closes[i], h = highs[i], l = lows[i]

            let body = bodySize(o, c)
            let range = candleRange(h, l)
            guard range > 0 else { continue }

            let upper = upperShadow(o, c, h)
            let lower = lowerShadow(o, c, l)

            // 十字星：實體 < 全距 10%
            if body < range * 0.1 {
                let inUptrend = isUptrend(index: i, ma5: ma5Values, ma20: ma20Values, closes: closes)
                let inDowntrend = isDowntrend(index: i, ma5: ma5Values, ma20: ma20Values, closes: closes)
                let dir: CandlestickDirection = inUptrend ? .bearish : (inDowntrend ? .bullish : .neutral)
                let desc: String
                switch dir {
                case .bearish: desc = "上漲趨勢中出現十字星，可能反轉下跌"
                case .bullish: desc = "下跌趨勢中出現十字星，可能反轉上漲"
                case .neutral: desc = "十字星表示多空力道均衡，觀望"
                }
                signals.append(CandlestickSignal(
                    pattern: .doji,
                    direction: dir,
                    reliability: .low,
                    barsAgo: barsAgo,
                    description: desc
                ))
                continue
            }

            // 槌子線 / 上吊線：下影線 ≥ 2× 實體，上影線 ≤ 0.3× 實體，實體 > 全距 5%
            if lower >= body * 2 && upper <= body * 0.3 && body > range * 0.05 {
                if isDowntrend(index: i, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                    signals.append(CandlestickSignal(
                        pattern: .hammer,
                        direction: .bullish,
                        reliability: .medium,
                        barsAgo: barsAgo,
                        description: "下跌趨勢中出現長下影線，底部反轉訊號"
                    ))
                } else if isUptrend(index: i, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                    signals.append(CandlestickSignal(
                        pattern: .hangingMan,
                        direction: .bearish,
                        reliability: .medium,
                        barsAgo: barsAgo,
                        description: "上漲趨勢中出現長下影線，注意反轉風險"
                    ))
                }
                continue
            }

            // 流星線：上影線 ≥ 2× 實體，下影線 ≤ 0.3× 實體，實體 > 全距 5%
            if upper >= body * 2 && lower <= body * 0.3 && body > range * 0.05 {
                if isUptrend(index: i, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                    signals.append(CandlestickSignal(
                        pattern: .shootingStar,
                        direction: .bearish,
                        reliability: .medium,
                        barsAgo: barsAgo,
                        description: "上漲趨勢中出現長上影線，賣壓明顯"
                    ))
                }
            }
        }

        // 排序：可靠度高優先、barsAgo 小（近期）優先，最多回傳 3 個
        let reliabilityOrder: [CandlestickReliability: Int] = [.high: 0, .medium: 1, .low: 2]
        let sorted = signals.sorted { a, b in
            let ra = reliabilityOrder[a.reliability] ?? 9
            let rb = reliabilityOrder[b.reliability] ?? 9
            if ra != rb { return ra < rb }
            return a.barsAgo < b.barsAgo
        }
        return Array(sorted.prefix(3))
    }

    // MARK: - Signal Summary

    /// 技術指標信號摘要（用於庫存頁面快速顯示）
    struct SignalSummary: Sendable {
        /// 最新收盤價相對 MA5 的位置
        let ma5Position: MAPosition?
        /// 最新收盤價相對 MA20 的位置
        let ma20Position: MAPosition?
        /// MA5/MA20 均線交叉
        let maCross: MACrossSignal?
        /// 最新 RSI 值
        let rsi: Double?
        /// RSI 狀態
        let rsiSignal: RSISignal?
        /// KDJ 交叉信號
        let kdjSignal: KDJSignal?
        /// 最新 KDJ K/D 值
        let kdjK: Double?
        let kdjD: Double?
        /// MACD 信號
        let macdSignal: MACDSignal?
        /// 最新 MACD DIF / DEA 值
        let macdDIF: Double?
        let macdDEA: Double?
        /// 布林通道信號
        let bollingerSignal: BollingerSignal?
        /// 布林通道具體數值（壓力/支撐用）
        let bollingerUpper: Double?
        let bollingerMiddle: Double?
        let bollingerLower: Double?
        /// 均線具體數值（壓力/支撐用）
        let ma5Value: Double?
        let ma20Value: Double?
        /// 近 20 日區間高低（壓力/支撐用）
        let recentHigh20: Double?
        let recentLow20: Double?
        /// 成交量異動信號
        let volumeSignal: VolumeSignal?
        /// 最新成交量 / MA20 量比
        let volumeRatio: Double?
        /// 背離信號
        let divergences: [DivergenceSignal]
        /// K 線型態信號
        let candlestickPatterns: [CandlestickSignal]
    }

    /// 均線相對位置
    enum MAPosition: Sendable {
        case above  // 價格在均線上方
        case below  // 價格在均線下方
    }

    /// MA5/MA20 均線交叉
    enum MACrossSignal: Sendable {
        case goldenCross  // MA5 上穿 MA20（多頭排列）
        case deathCross   // MA5 下穿 MA20（空頭排列）

        var label: String {
            switch self {
            case .goldenCross: return "均線金叉"
            case .deathCross: return "均線死叉"
            }
        }
    }

    enum RSISignal: Sendable {
        case overbought  // RSI > 80
        case oversold    // RSI < 20
        case neutral

        var label: String? {
            switch self {
            case .overbought: return "超買"
            case .oversold: return "超賣"
            case .neutral: return nil
            }
        }
    }

    enum KDJSignal: Sendable {
        case goldenCross   // K 上穿 D（買入訊號）
        case deathCross    // K 下穿 D（賣出訊號）
        case none

        var label: String? {
            switch self {
            case .goldenCross: return "KD金叉"
            case .deathCross: return "KD死叉"
            case .none: return nil
            }
        }
    }

    /// MACD 信號
    enum MACDSignal: Sendable {
        case goldenCross   // DIF 上穿 DEA
        case deathCross    // DIF 下穿 DEA
        case none

        var label: String? {
            switch self {
            case .goldenCross: return "MACD金叉"
            case .deathCross: return "MACD死叉"
            case .none: return nil
            }
        }
    }

    /// 布林通道信號
    enum BollingerSignal: Sendable {
        case nearUpper    // 價格接近或突破上軌（壓力）
        case nearLower    // 價格接近或觸及下軌（支撐）
        case squeeze      // 帶寬收窄（即將變盤）
        case normal

        var label: String? {
            switch self {
            case .nearUpper: return "觸布林上軌"
            case .nearLower: return "觸布林下軌"
            case .squeeze: return "布林收窄"
            case .normal: return nil
            }
        }
    }

    /// 成交量異動信號
    enum VolumeSignal: Sendable {
        case surge    // 量能爆量 ≥ 2 倍 MA20
        case high     // 量能放大 ≥ 1.5 倍 MA20
        case shrink   // 量能萎縮 ≤ 0.5 倍 MA20
        case normal

        var label: String? {
            switch self {
            case .surge: return "爆量"
            case .high: return "量增"
            case .shrink: return "量縮"
            case .normal: return nil
            }
        }
    }

    /// 根據歷史 OHLCV 資料計算技術指標信號摘要
    static func computeSignalSummary(
        opens: [Double] = [],
        closes: [Double],
        highs: [Double],
        lows: [Double],
        volumes: [Int] = [],
        settings: TechnicalSettings = .defaults
    ) -> SignalSummary {
        guard !closes.isEmpty else {
            return SignalSummary(
                ma5Position: nil, ma20Position: nil, maCross: nil,
                rsi: nil, rsiSignal: nil, kdjSignal: nil, kdjK: nil, kdjD: nil,
                macdSignal: nil, macdDIF: nil, macdDEA: nil,
                bollingerSignal: nil,
                bollingerUpper: nil, bollingerMiddle: nil, bollingerLower: nil,
                ma5Value: nil, ma20Value: nil,
                recentHigh20: nil, recentLow20: nil,
                volumeSignal: nil, volumeRatio: nil,
                divergences: [],
                candlestickPatterns: []
            )
        }

        let lastClose = closes.last!

        // ── 短期均線 ──
        let maShortValues = sma(closes: closes, period: settings.maShortPeriod)
        let ma5Pos: MAPosition?
        if let maShort = maShortValues.last ?? nil {
            ma5Pos = lastClose >= maShort ? .above : .below
        } else {
            ma5Pos = nil
        }

        // ── 長期均線 ──
        let maLongValues = sma(closes: closes, period: settings.maLongPeriod)
        let ma20Pos: MAPosition?
        if let maLong = maLongValues.last ?? nil {
            ma20Pos = lastClose >= maLong ? .above : .below
        } else {
            ma20Pos = nil
        }

        // ── 均線交叉（短期 vs 長期）──
        let maCrossSig: MACrossSignal?
        if maShortValues.count >= 2, maLongValues.count >= 2,
           let curShort = maShortValues[maShortValues.count - 1],
           let prevShort = maShortValues[maShortValues.count - 2],
           let curLong = maLongValues[maLongValues.count - 1],
           let prevLong = maLongValues[maLongValues.count - 2] {
            if curShort > curLong && prevShort <= prevLong {
                maCrossSig = .goldenCross
            } else if curShort < curLong && prevShort >= prevLong {
                maCrossSig = .deathCross
            } else {
                maCrossSig = nil
            }
        } else {
            maCrossSig = nil
        }

        // ── RSI ──
        let rsiValues = rsi(closes: closes, period: settings.rsiPeriod)
        let latestRSI = rsiValues.last ?? nil
        let rsiSig: RSISignal?
        if let r = latestRSI {
            if r > settings.rsiOverbought { rsiSig = .overbought }
            else if r < settings.rsiOversold { rsiSig = .oversold }
            else { rsiSig = .neutral }
        } else {
            rsiSig = nil
        }

        // ── KDJ ──
        let kdjValues = kdj(
            highs: highs, lows: lows, closes: closes,
            period: settings.kdjPeriod,
            kSmooth: settings.kdjKSmooth,
            dSmooth: settings.kdjDSmooth
        )
        let kdjSig: KDJSignal
        var latestK: Double?
        var latestD: Double?
        if kdjValues.count >= 2,
           let current = kdjValues[kdjValues.count - 1],
           let previous = kdjValues[kdjValues.count - 2] {
            latestK = current.k
            latestD = current.d
            if current.k > current.d && previous.k <= previous.d {
                kdjSig = .goldenCross
            } else if current.k < current.d && previous.k >= previous.d {
                kdjSig = .deathCross
            } else {
                kdjSig = .none
            }
        } else {
            kdjSig = .none
            if let last = kdjValues.last ?? nil {
                latestK = last.k
                latestD = last.d
            }
        }

        // ── MACD ──
        let macdValues = macd(
            closes: closes,
            fastPeriod: settings.macdFastPeriod,
            slowPeriod: settings.macdSlowPeriod,
            signalPeriod: settings.macdSignalPeriod
        )
        let macdSig: MACDSignal
        var latestDIF: Double?
        var latestDEA: Double?
        if macdValues.count >= 2,
           let current = macdValues[macdValues.count - 1],
           let previous = macdValues[macdValues.count - 2] {
            latestDIF = current.dif
            latestDEA = current.dea
            if current.dif > current.dea && previous.dif <= previous.dea {
                macdSig = .goldenCross
            } else if current.dif < current.dea && previous.dif >= previous.dea {
                macdSig = .deathCross
            } else {
                macdSig = .none
            }
        } else {
            macdSig = .none
            if let last = macdValues.last ?? nil {
                latestDIF = last.dif
                latestDEA = last.dea
            }
        }

        // ── 布林通道 ──
        let bbValues = bollingerBands(
            closes: closes,
            period: settings.bollingerPeriod,
            multiplier: settings.bollingerMultiplier
        )
        let bbSig: BollingerSignal
        if let bb = bbValues.last ?? nil {
            let range = bb.upper - bb.lower
            if range > 0 {
                if lastClose >= bb.upper || (bb.upper - lastClose) / range <= settings.bollingerNearBandThreshold {
                    bbSig = .nearUpper
                }
                else if lastClose <= bb.lower || (lastClose - bb.lower) / range <= settings.bollingerNearBandThreshold {
                    bbSig = .nearLower
                }
                else if bb.bandwidth < settings.bollingerSqueezeThreshold {
                    bbSig = .squeeze
                } else {
                    bbSig = .normal
                }
            } else {
                bbSig = .normal
            }
        } else {
            bbSig = .normal
        }

        // ── 布林通道數值 ──
        let latestBB = bbValues.last ?? nil
        let bbUpper = latestBB?.upper
        let bbMiddle = latestBB?.middle
        let bbLower = latestBB?.lower

        // ── 均線數值 ──
        let latestMA5 = maShortValues.last ?? nil
        let latestMA20 = maLongValues.last ?? nil

        // ── 近 20 日區間高低 ──
        let recent20High: Double? = highs.count >= 20 ? highs.suffix(20).max() : (highs.isEmpty ? nil : highs.max())
        let recent20Low: Double? = lows.count >= 20 ? lows.suffix(20).min() : (lows.isEmpty ? nil : lows.min())

        // ── 成交量異動 ──
        let volSig: VolumeSignal
        var volRatio: Double?
        let volMAPeriod = settings.volumeMAPeriod
        if !volumes.isEmpty, volumes.count >= volMAPeriod {
            let volDoubles = volumes.map { Double($0) }
            let maVol = volDoubles.suffix(volMAPeriod).reduce(0, +) / Double(volMAPeriod)
            if maVol > 0, let lastVol = volumes.last {
                let ratio = Double(lastVol) / maVol
                volRatio = ratio
                if ratio >= settings.volumeSurgeMultiplier {
                    volSig = .surge
                } else if ratio >= settings.volumeHighMultiplier {
                    volSig = .high
                } else if ratio <= settings.volumeShrinkMultiplier {
                    volSig = .shrink
                } else {
                    volSig = .normal
                }
            } else {
                volSig = .normal
            }
        } else {
            volSig = .normal
        }

        // ── 背離偵測 ──
        let divergences = detectDivergences(
            closes: closes,
            highs: highs,
            lows: lows,
            rsiValues: rsiValues,
            macdValues: macdValues
        )

        // ── K 線型態偵測 ──
        let candlestickPatterns: [CandlestickSignal]
        if !opens.isEmpty, opens.count == closes.count {
            candlestickPatterns = detectCandlestickPatterns(
                opens: opens, closes: closes,
                highs: highs, lows: lows,
                ma5Values: maShortValues, ma20Values: maLongValues
            )
        } else {
            candlestickPatterns = []
        }

        return SignalSummary(
            ma5Position: ma5Pos,
            ma20Position: ma20Pos,
            maCross: maCrossSig,
            rsi: latestRSI,
            rsiSignal: rsiSig,
            kdjSignal: kdjSig,
            kdjK: latestK,
            kdjD: latestD,
            macdSignal: macdSig,
            macdDIF: latestDIF,
            macdDEA: latestDEA,
            bollingerSignal: bbSig == .normal ? nil : bbSig,
            bollingerUpper: bbUpper,
            bollingerMiddle: bbMiddle,
            bollingerLower: bbLower,
            ma5Value: latestMA5,
            ma20Value: latestMA20,
            recentHigh20: recent20High,
            recentLow20: recent20Low,
            volumeSignal: volSig == .normal ? nil : volSig,
            volumeRatio: volRatio,
            divergences: divergences,
            candlestickPatterns: candlestickPatterns
        )
    }

    // MARK: - Sell Recommendation

    /// 賣出建議等級
    enum SellLevel: Sendable {
        case strongSell     // ≥ 70
        case considerSell   // 50–69
        case neutral        // 30–49
        case holdBullish    // 10–29
        case strongHold     // < 10

        var label: String {
            switch self {
            case .strongSell: return "強烈建議賣出"
            case .considerSell: return "建議考慮賣出"
            case .neutral: return "觀望"
            case .holdBullish: return "持有偏多"
            case .strongHold: return "強力持有"
            }
        }

        var shortLabel: String {
            switch self {
            case .strongSell: return "建議賣出"
            case .considerSell: return "考慮賣出"
            case .neutral: return "觀望"
            case .holdBullish: return "偏多持有"
            case .strongHold: return "強力持有"
            }
        }

        var icon: String {
            switch self {
            case .strongSell: return "exclamationmark.triangle.fill"
            case .considerSell: return "exclamationmark.circle.fill"
            case .neutral: return "minus.circle"
            case .holdBullish: return "hand.thumbsup"
            case .strongHold: return "checkmark.shield.fill"
            }
        }
    }

    /// 影響因子
    struct SellFactor: Sendable, Identifiable {
        let id = UUID()
        let name: String      // e.g. "均線死叉"
        let points: Int       // e.g. +15 or -10
        let isBearish: Bool   // true = 偏空（加分）, false = 偏多（扣分）
    }

    /// 賣出建議結果
    struct SellRecommendation: Sendable {
        let score: Int              // 0–100
        let level: SellLevel
        let factors: [SellFactor]
    }

    /// 計算綜合賣出建議
    static func computeSellRecommendation(
        signal: SignalSummary,
        trailingStopTriggered: Bool,
        nearTrailingStop: Bool,
        foreignStreak: Int?,
        trustStreak: Int?
    ) -> SellRecommendation {
        var score = 50
        var factors: [SellFactor] = []

        // ── 均線交叉 ──
        if let maCross = signal.maCross {
            switch maCross {
            case .deathCross:
                score += 15
                factors.append(SellFactor(name: "均線死叉", points: 15, isBearish: true))
            case .goldenCross:
                score -= 10
                factors.append(SellFactor(name: "均線金叉", points: -10, isBearish: false))
            }
        }

        // ── MACD 交叉 ──
        if let macdSig = signal.macdSignal {
            switch macdSig {
            case .deathCross:
                score += 12
                factors.append(SellFactor(name: "MACD死叉", points: 12, isBearish: true))
            case .goldenCross:
                score -= 8
                factors.append(SellFactor(name: "MACD金叉", points: -8, isBearish: false))
            case .none:
                break
            }
        }

        // ── KDJ 交叉 ──
        if let kdjSig = signal.kdjSignal {
            switch kdjSig {
            case .deathCross:
                score += 10
                factors.append(SellFactor(name: "KD死叉", points: 10, isBearish: true))
            case .goldenCross:
                score -= 6
                factors.append(SellFactor(name: "KD金叉", points: -6, isBearish: false))
            case .none:
                break
            }
        }

        // ── RSI ──
        if let rsiSig = signal.rsiSignal {
            switch rsiSig {
            case .overbought:
                score += 12
                factors.append(SellFactor(name: "RSI超買", points: 12, isBearish: true))
            case .oversold:
                score -= 8
                factors.append(SellFactor(name: "RSI超賣", points: -8, isBearish: false))
            case .neutral:
                break
            }
        }

        // ── 布林通道 ──
        if let bbSig = signal.bollingerSignal {
            switch bbSig {
            case .nearUpper:
                score += 8
                factors.append(SellFactor(name: "觸布林上軌", points: 8, isBearish: true))
            case .nearLower:
                score -= 6
                factors.append(SellFactor(name: "觸布林下軌", points: -6, isBearish: false))
            case .squeeze, .normal:
                break
            }
        }

        // ── 成交量 ──
        if let volSig = signal.volumeSignal {
            switch volSig {
            case .surge:
                // 爆量配合均線空頭 → 偏空
                score += 8
                factors.append(SellFactor(name: "爆量", points: 8, isBearish: true))
            case .shrink:
                score += 3
                factors.append(SellFactor(name: "量縮", points: 3, isBearish: true))
            case .high, .normal:
                break
            }
        }

        // ── 移動停利 ──
        if trailingStopTriggered {
            score += 20
            factors.append(SellFactor(name: "跌破停利線", points: 20, isBearish: true))
        } else if nearTrailingStop {
            score += 10
            factors.append(SellFactor(name: "接近停利線", points: 10, isBearish: true))
        } else {
            score -= 5
            factors.append(SellFactor(name: "安全持有中", points: -5, isBearish: false))
        }

        // ── MA 位置 ──
        if let ma5 = signal.ma5Position {
            if ma5 == .below {
                score += 5
                factors.append(SellFactor(name: "價格在MA5下方", points: 5, isBearish: true))
            } else {
                score -= 3
                factors.append(SellFactor(name: "價格在MA5上方", points: -3, isBearish: false))
            }
        }
        if let ma20 = signal.ma20Position {
            if ma20 == .below {
                score += 5
                factors.append(SellFactor(name: "價格在MA20下方", points: 5, isBearish: true))
            } else {
                score -= 3
                factors.append(SellFactor(name: "價格在MA20上方", points: -3, isBearish: false))
            }
        }

        // ── 法人動態 ──
        if let fs = foreignStreak, abs(fs) >= 3 {
            if fs < 0 {
                score += 5
                factors.append(SellFactor(name: "外資連賣\(abs(fs))日", points: 5, isBearish: true))
            } else {
                score -= 3
                factors.append(SellFactor(name: "外資連買\(fs)日", points: -3, isBearish: false))
            }
        }
        if let ts = trustStreak, abs(ts) >= 3 {
            if ts < 0 {
                score += 5
                factors.append(SellFactor(name: "投信連賣\(abs(ts))日", points: 5, isBearish: true))
            } else {
                score -= 3
                factors.append(SellFactor(name: "投信連買\(ts)日", points: -3, isBearish: false))
            }
        }

        // ── 背離 ──
        for div in signal.divergences {
            switch (div.indicator, div.type) {
            case ("RSI", .bearish):
                score += 10
                factors.append(SellFactor(name: "RSI頂背離", points: 10, isBearish: true))
            case ("MACD", .bearish):
                score += 10
                factors.append(SellFactor(name: "MACD頂背離", points: 10, isBearish: true))
            case ("RSI", .bullish):
                score -= 6
                factors.append(SellFactor(name: "RSI底背離", points: -6, isBearish: false))
            case ("MACD", .bullish):
                score -= 6
                factors.append(SellFactor(name: "MACD底背離", points: -6, isBearish: false))
            default:
                break
            }
        }

        // ── K 線型態 ──
        for pattern in signal.candlestickPatterns {
            guard pattern.direction != .neutral else { continue }
            let points: Int
            switch pattern.reliability {
            case .high:   points = pattern.direction == .bearish ? 8 : -8
            case .medium: points = pattern.direction == .bearish ? 5 : -5
            case .low:    points = pattern.direction == .bearish ? 3 : -3
            }
            score += points
            factors.append(SellFactor(
                name: pattern.pattern.rawValue,
                points: points,
                isBearish: pattern.direction == .bearish
            ))
        }

        // Clamp
        let finalScore = min(100, max(0, score))

        // 決定等級
        let level: SellLevel
        switch finalScore {
        case 70...100: level = .strongSell
        case 50..<70:  level = .considerSell
        case 30..<50:  level = .neutral
        case 10..<30:  level = .holdBullish
        default:       level = .strongHold
        }

        // 排序：偏空在前，分數高在前
        let sorted = factors.sorted { a, b in
            if a.isBearish != b.isBearish { return a.isBearish }
            return abs(a.points) > abs(b.points)
        }

        return SellRecommendation(score: finalScore, level: level, factors: sorted)
    }
}
