import Foundation

// MARK: - TechnicalIndicators + Divergence & Candlestick Patterns

extension TechnicalIndicators {

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
        case threeWhiteSoldiers = "三白兵"
        case threeBlackCrows = "三黑鴉"
        case piercingLine = "刺穿線"
        case darkCloudCover = "烏雲蓋頂"
        case counterattack = "反擊線"
        case tweezersBottom = "平頭底"
        case tweezersTop = "平頭頂"
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
        ma20Values: [Double?],
        maxResults: Int = 3
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

            // 三白兵：連續 3 根陽線，收盤遞增，開盤在前根實體內，上影線短
            let range1 = candleRange(highs[i - 1], lows[i - 1])
            let range2 = candleRange(highs[i], lows[i])
            let h1 = highs[i - 1], h2 = highs[i]

            if isBullishCandle(o0, c0) && isBullishCandle(o1, c1) && isBullishCandle(o2, c2)
                && range0 > 0 && range1 > 0 && range2 > 0
                && body0 >= range0 * 0.5 && body1 >= range1 * 0.5 && body2 >= range2 * 0.5
                && c1 > c0 && c2 > c1
                && o1 >= o0 && o1 <= c0
                && o2 >= o1 && o2 <= c1
                && upperShadow(o0, c0, h0) <= body0 * 0.3
                && upperShadow(o1, c1, h1) <= body1 * 0.3
                && upperShadow(o2, c2, h2) <= body2 * 0.3
                && isDowntrend(index: i - 2, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .threeWhiteSoldiers,
                    direction: .bullish,
                    reliability: .high,
                    barsAgo: barsAgo,
                    description: "連續三根陽線收盤遞增，強烈底部反轉訊號"
                ))
            }

            // 三黑鴉：連續 3 根陰線，收盤遞減，開盤在前根實體內，下影線短
            if !isBullishCandle(o0, c0) && !isBullishCandle(o1, c1) && !isBullishCandle(o2, c2)
                && range0 > 0 && range1 > 0 && range2 > 0
                && body0 >= range0 * 0.5 && body1 >= range1 * 0.5 && body2 >= range2 * 0.5
                && c1 < c0 && c2 < c1
                && o1 <= o0 && o1 >= c0
                && o2 <= o1 && o2 >= c1
                && lowerShadow(o0, c0, l0) <= body0 * 0.3
                && lowerShadow(o1, c1, lows[i - 1]) <= body1 * 0.3
                && lowerShadow(o2, c2, lows[i]) <= body2 * 0.3
                && isUptrend(index: i - 2, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .threeBlackCrows,
                    direction: .bearish,
                    reliability: .high,
                    barsAgo: barsAgo,
                    description: "連續三根陰線收盤遞減，強烈頂部反轉訊號"
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

        // ── 兩根型態（刺穿線 / 烏雲蓋頂 / 反擊線 / 平頭底 / 平頭頂）──
        for i in max(scanStart, 1)..<count {
            let barsAgo = count - 1 - i
            let prevO = opens[i - 1], prevC = closes[i - 1]
            let prevH = highs[i - 1], prevL = lows[i - 1]
            let curO = opens[i], curC = closes[i]
            let curH = highs[i], curL = lows[i]

            let prevBody = bodySize(prevO, prevC)
            let curBody = bodySize(curO, curC)
            let prevRange = candleRange(prevH, prevL)
            let prevBodyMid = (max(prevO, prevC) + min(prevO, prevC)) / 2

            // 刺穿線：前根大陰線 → 後根陽線跳空低開 → 收在前根實體中點以上但不超過前根開盤
            if prevRange > 0 && prevBody >= prevRange * 0.5
                && !isBullishCandle(prevO, prevC)
                && isBullishCandle(curO, curC)
                && curO < prevL                        // 跳空低開
                && curC > prevBodyMid                   // 收在前根實體中點以上
                && curC < prevO                         // 未超過前根開盤
                && isDowntrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .piercingLine,
                    direction: .bullish,
                    reliability: .medium,
                    barsAgo: barsAgo,
                    description: "陰線後跳空低開收回實體一半以上，底部反轉訊號"
                ))
            }

            // 烏雲蓋頂：前根大陽線 → 後根陰線跳空高開 → 收在前根實體中點以下但不低於前根開盤
            if prevRange > 0 && prevBody >= prevRange * 0.5
                && isBullishCandle(prevO, prevC)
                && !isBullishCandle(curO, curC)
                && curO > prevH                        // 跳空高開
                && curC < prevBodyMid                   // 收在前根實體中點以下
                && curC > prevO                         // 未低於前根開盤
                && isUptrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .darkCloudCover,
                    direction: .bearish,
                    reliability: .medium,
                    barsAgo: barsAgo,
                    description: "陽線後跳空高開收跌至實體一半以下，頂部反轉訊號"
                ))
            }

            // 反擊線（多頭）：前陰 + 後陽，兩根收盤價幾乎相同
            let closeTolerance = max(prevC, curC) * 0.002  // 0.2% 容差
            if !isBullishCandle(prevO, prevC) && isBullishCandle(curO, curC)
                && prevBody > 0 && curBody > 0
                && abs(prevC - curC) <= closeTolerance
                && isDowntrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .counterattack,
                    direction: .bullish,
                    reliability: .medium,
                    barsAgo: barsAgo,
                    description: "陰線後陽線收在相同價位，多頭反擊訊號"
                ))
            }

            // 反擊線（空頭）：前陽 + 後陰，兩根收盤價幾乎相同
            if isBullishCandle(prevO, prevC) && !isBullishCandle(curO, curC)
                && prevBody > 0 && curBody > 0
                && abs(prevC - curC) <= closeTolerance
                && isUptrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .counterattack,
                    direction: .bearish,
                    reliability: .medium,
                    barsAgo: barsAgo,
                    description: "陽線後陰線收在相同價位，空頭反擊訊號"
                ))
            }

            // 平頭底：兩根最低價幾乎相同，前陰後任意，非十字星
            let lowTolerance = max(prevL, curL) * 0.001   // 0.1% 容差
            let prevRange2 = candleRange(prevH, prevL)
            let curRange = candleRange(curH, curL)
            if abs(prevL - curL) <= lowTolerance
                && !isBullishCandle(prevO, prevC)
                && prevRange2 > 0 && curRange > 0
                && prevBody >= prevRange2 * 0.1           // 非十字星
                && curBody >= curRange * 0.1              // 非十字星
                && isDowntrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .tweezersBottom,
                    direction: .bullish,
                    reliability: .medium,
                    barsAgo: barsAgo,
                    description: "兩根K棒最低價相同，底部支撐反轉訊號"
                ))
            }

            // 平頭頂：兩根最高價幾乎相同，前陽後任意，非十字星
            let highTolerance = max(prevH, curH) * 0.001  // 0.1% 容差
            if abs(prevH - curH) <= highTolerance
                && isBullishCandle(prevO, prevC)
                && prevRange2 > 0 && curRange > 0
                && prevBody >= prevRange2 * 0.1           // 非十字星
                && curBody >= curRange * 0.1              // 非十字星
                && isUptrend(index: i - 1, ma5: ma5Values, ma20: ma20Values, closes: closes) {
                signals.append(CandlestickSignal(
                    pattern: .tweezersTop,
                    direction: .bearish,
                    reliability: .medium,
                    barsAgo: barsAgo,
                    description: "兩根K棒最高價相同，頂部壓力反轉訊號"
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
        return Array(sorted.prefix(maxResults))
    }
}
