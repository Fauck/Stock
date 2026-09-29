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

    // MARK: - ATR (Average True Range)

    /// 計算 True Range
    /// TR = max(H-L, |H-prevClose|, |L-prevClose|)
    static func trueRange(highs: [Double], lows: [Double], closes: [Double]) -> [Double] {
        guard highs.count == lows.count, highs.count == closes.count, highs.count > 1 else {
            return []
        }

        var tr: [Double] = [highs[0] - lows[0]]  // 第一根用 H-L
        for i in 1..<highs.count {
            let hl = highs[i] - lows[i]
            let hc = abs(highs[i] - closes[i - 1])
            let lc = abs(lows[i] - closes[i - 1])
            tr.append(max(hl, hc, lc))
        }
        return tr
    }

    /// ATR (Average True Range) — Wilder's smoothing
    /// - Parameters:
    ///   - highs: 最高價序列（按日期升序）
    ///   - lows: 最低價序列
    ///   - closes: 收盤價序列
    ///   - period: ATR 週期（常用 14）
    /// - Returns: ATR 值陣列，前 period 個為 nil
    static func atr(
        highs: [Double],
        lows: [Double],
        closes: [Double],
        period: Int = 14
    ) -> [Double?] {
        let tr = trueRange(highs: highs, lows: lows, closes: closes)
        guard tr.count >= period else {
            return Array(repeating: nil, count: closes.count)
        }

        var result: [Double?] = Array(repeating: nil, count: tr.count)

        // 初始 ATR = 前 period 個 TR 的 SMA
        let initialATR = tr[0..<period].reduce(0, +) / Double(period)
        result[period - 1] = initialATR

        // Wilder's smoothing: ATR = (prevATR * (period-1) + TR) / period
        var prev = initialATR
        for i in period..<tr.count {
            let val = (prev * Double(period - 1) + tr[i]) / Double(period)
            result[i] = val
            prev = val
        }

        return result
    }

    // MARK: - ADX (Average Directional Index)

    /// ADX/DMI 指標結果
    struct ADXResult: Sendable {
        let adx: Double      // ADX 趨勢強度 (0~100)
        let plusDI: Double    // +DI 上升趨勢指標
        let minusDI: Double   // -DI 下降趨勢指標
    }

    /// ADX 趨勢強度信號
    enum ADXSignal: Sendable {
        case strongTrend    // ADX ≥ 25，趨勢明確
        case weakTrend      // ADX < 25，趨勢不明
        case trendStrengthening  // ADX 上升中
        case trendWeakening      // ADX 下降中

        var label: String {
            switch self {
            case .strongTrend: return "趨勢強"
            case .weakTrend: return "趨勢弱"
            case .trendStrengthening: return "趨勢增強"
            case .trendWeakening: return "趨勢減弱"
            }
        }
    }

    /// ADX (Average Directional Index) — 趨勢強度指標
    /// - Parameters:
    ///   - highs: 最高價序列（按日期升序）
    ///   - lows: 最低價序列
    ///   - closes: 收盤價序列
    ///   - period: ADX 週期（常用 14）
    /// - Returns: ADX 結果陣列，前面資料不足的部分為 nil
    static func adx(
        highs: [Double],
        lows: [Double],
        closes: [Double],
        period: Int = 14
    ) -> [ADXResult?] {
        let count = highs.count
        guard count == lows.count, count == closes.count, count > period + period else {
            return Array(repeating: nil, count: count)
        }

        // Step 1: 計算 +DM 和 -DM
        var plusDM: [Double] = [0]
        var minusDM: [Double] = [0]
        for i in 1..<count {
            let upMove = highs[i] - highs[i - 1]
            let downMove = lows[i - 1] - lows[i]

            if upMove > downMove && upMove > 0 {
                plusDM.append(upMove)
            } else {
                plusDM.append(0)
            }

            if downMove > upMove && downMove > 0 {
                minusDM.append(downMove)
            } else {
                minusDM.append(0)
            }
        }

        // Step 2: 計算 TR
        let tr = trueRange(highs: highs, lows: lows, closes: closes)
        guard tr.count == count else {
            return Array(repeating: nil, count: count)
        }

        // Step 3: Wilder's smoothing for TR, +DM, -DM
        guard count >= period else {
            return Array(repeating: nil, count: count)
        }

        var smoothTR = tr[0..<period].reduce(0, +)
        var smoothPlusDM = plusDM[0..<period].reduce(0, +)
        var smoothMinusDM = minusDM[0..<period].reduce(0, +)

        // Step 4: 計算 +DI, -DI, DX
        var dxValues: [Double] = []
        var result: [ADXResult?] = Array(repeating: nil, count: count)

        for i in (period - 1)..<count {
            if i > period - 1 {
                smoothTR = smoothTR - (smoothTR / Double(period)) + tr[i]
                smoothPlusDM = smoothPlusDM - (smoothPlusDM / Double(period)) + plusDM[i]
                smoothMinusDM = smoothMinusDM - (smoothMinusDM / Double(period)) + minusDM[i]
            }

            let pDI = smoothTR > 0 ? (smoothPlusDM / smoothTR) * 100 : 0
            let mDI = smoothTR > 0 ? (smoothMinusDM / smoothTR) * 100 : 0
            let diSum = pDI + mDI
            let dx = diSum > 0 ? abs(pDI - mDI) / diSum * 100 : 0
            dxValues.append(dx)

            // Step 5: ADX = DX 的 period 日 Wilder's smoothing
            if dxValues.count >= period {
                let adxVal: Double
                if dxValues.count == period {
                    // 初始 ADX = 前 period 個 DX 的 SMA
                    adxVal = dxValues.reduce(0, +) / Double(period)
                } else {
                    // Wilder's smoothing
                    let prevADX = result[i - 1]?.adx ?? (dxValues.dropLast().suffix(period).reduce(0, +) / Double(period))
                    adxVal = (prevADX * Double(period - 1) + dx) / Double(period)
                }
                result[i] = ADXResult(adx: adxVal, plusDI: pDI, minusDI: mDI)
            }
        }

        return result
    }

    // MARK: - Volume Profile (Historical Approximation)

    /// 單一價格層級的成交量統計
    struct VolumeProfileLevel: Sendable {
        let priceLow: Double   // 此 bin 下限
        let priceHigh: Double  // 此 bin 上限
        let priceMid: Double   // 中心價
        let volume: Double     // 估算量
        let percentage: Double // 佔總量 %
    }

    /// Volume Profile 計算結果
    struct VolumeProfileResult: Sendable {
        let levels: [VolumeProfileLevel]  // 由低到高排序
        let pocIndex: Int                 // Point of Control（最大量）索引
        let pocPrice: Double              // POC 中心價
        let valueAreaHigh: Double         // Value Area 上限（70%）
        let valueAreaLow: Double          // Value Area 下限（70%）
        let totalVolume: Double
    }

    /// 用日 K 資料模擬 Volume Profile
    /// 將每根 K 棒的成交量均勻分配到 High~Low 價格範圍覆蓋的 bin 中
    /// - Parameters:
    ///   - highs: 最高價序列
    ///   - lows: 最低價序列
    ///   - closes: 收盤價序列
    ///   - volumes: 成交量序列
    ///   - binCount: 價格分層數（預設 30）
    ///   - valueAreaPercent: Value Area 佔比（預設 0.70）
    /// - Returns: VolumeProfileResult，如資料不足則 nil
    static func volumeProfile(
        highs: [Double],
        lows: [Double],
        closes: [Double],
        volumes: [Double],
        binCount: Int = 30,
        valueAreaPercent: Double = 0.70
    ) -> VolumeProfileResult? {
        let count = min(highs.count, lows.count, closes.count, volumes.count)
        guard count > 1, binCount > 0 else { return nil }

        // 找全域價格範圍
        let globalHigh = highs[0..<count].max() ?? 0
        let globalLow = lows[0..<count].min() ?? 0
        guard globalHigh > globalLow else { return nil }

        let binSize = (globalHigh - globalLow) / Double(binCount)
        guard binSize > 0 else { return nil }

        // 累計各 bin 的成交量
        var binVolumes = [Double](repeating: 0, count: binCount)

        for i in 0..<count {
            let h = highs[i]
            let l = lows[i]
            let vol = volumes[i]
            guard h > l, vol > 0 else { continue }

            // 找出此 K 棒覆蓋的 bin 範圍
            let startBin = max(0, Int((l - globalLow) / binSize))
            let endBin = min(binCount - 1, Int((h - globalLow) / binSize))
            let coveredBins = max(1, endBin - startBin + 1)
            let volPerBin = vol / Double(coveredBins)

            for b in startBin...endBin {
                binVolumes[b] += volPerBin
            }
        }

        let totalVolume = binVolumes.reduce(0, +)
        guard totalVolume > 0 else { return nil }

        // 建構 levels
        var levels: [VolumeProfileLevel] = []
        for b in 0..<binCount {
            let pLow = globalLow + Double(b) * binSize
            let pHigh = pLow + binSize
            let pMid = (pLow + pHigh) / 2.0
            levels.append(VolumeProfileLevel(
                priceLow: pLow,
                priceHigh: pHigh,
                priceMid: pMid,
                volume: binVolumes[b],
                percentage: binVolumes[b] / totalVolume * 100
            ))
        }

        // POC = 最大量 bin
        let pocIndex = binVolumes.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0

        // Value Area：從 POC 向兩側擴展直到佔比 ≥ 70%
        let targetVolume = totalVolume * valueAreaPercent
        var accumulatedVolume = binVolumes[pocIndex]
        var vaLow = pocIndex
        var vaHigh = pocIndex

        while accumulatedVolume < targetVolume {
            let canGoDown = vaLow > 0
            let canGoUp = vaHigh < binCount - 1

            if !canGoDown && !canGoUp { break }

            let downVol = canGoDown ? binVolumes[vaLow - 1] : -1
            let upVol = canGoUp ? binVolumes[vaHigh + 1] : -1

            if downVol >= upVol {
                vaLow -= 1
                accumulatedVolume += binVolumes[vaLow]
            } else {
                vaHigh += 1
                accumulatedVolume += binVolumes[vaHigh]
            }
        }

        return VolumeProfileResult(
            levels: levels,
            pocIndex: pocIndex,
            pocPrice: levels[pocIndex].priceMid,
            valueAreaHigh: levels[vaHigh].priceHigh,
            valueAreaLow: levels[vaLow].priceLow,
            totalVolume: totalVolume
        )
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
        /// 市場狀態（多頭/空頭/盤整）
        let regime: MarketRegime
        /// ATR 值（波動幅度）
        let atr: Double?
        /// ATR 佔收盤價百分比（波動率）
        let atrPercent: Double?
        /// ADX 趨勢強度
        let adx: Double?
        /// +DI（上升方向指標）
        let plusDI: Double?
        /// -DI（下降方向指標）
        let minusDI: Double?
        /// ADX 信號
        let adxSignal: ADXSignal?
    }

    // MARK: - 均線扣抵值

    /// 均線扣抵方向預判
    enum DeductionTrend: String, Sendable {
        case up   = "趨升"
        case down = "趨降"
        case flat = "持平"
    }

    /// 單日扣抵值快照
    struct DeductionPoint: Sendable {
        let dayOffset: Int        // 0=今天, 1=明天, ...
        let deductionPrice: Double
        let trend: DeductionTrend
    }

    /// 單條均線的扣抵值分析
    struct MADeductionInfo: Sendable, Identifiable {
        let period: Int
        let deductionPrice: Double   // N 日前即將被踢出的收盤價
        let currentMA: Double
        let currentPrice: Double
        let trend: DeductionTrend
        /// 扣抵價與現價的差距百分比（正=現價高於扣抵價→均線趨升）
        let gapPercent: Double
        /// 未來數日的扣抵值走勢（index 0 = 今天，1 = 明天 …）
        let futureDeductions: [DeductionPoint]
        /// 翻轉日（未來第幾天趨勢方向改變，nil = 期間內不翻轉）
        let flipDay: Int?

        var id: Int { period }
        var periodLabel: String { "MA\(period)" }
    }

    /// 計算多條均線的扣抵值分析（含未來走勢）
    /// - Parameters:
    ///   - closes: 歷史收盤價陣列（由舊到新）
    ///   - currentPrice: 最新收盤價
    ///   - periods: 要分析的 MA 週期（預設 10/20/60）
    ///   - forecastDays: 預測未來幾天的扣抵值（預設 5）
    /// - Returns: 各週期的扣抵值資訊（資料不足的週期會被略過）
    static func computeMADeductions(
        closes: [Double],
        currentPrice: Double,
        periods: [Int] = [10, 20, 60],
        forecastDays: Int = 5
    ) -> [MADeductionInfo] {
        var results: [MADeductionInfo] = []
        let threshold: Double = 0.5  // ±0.5% 內視為持平

        for period in periods {
            guard closes.count >= period else { continue }

            // 今天的扣抵值
            let deductionPrice = closes[closes.count - period]

            // 計算目前 MA
            let recentCloses = Array(closes.suffix(period))
            let currentMA = recentCloses.reduce(0, +) / Double(period)

            // 差距百分比
            let gap = currentPrice - deductionPrice
            let gapPercent = deductionPrice > 0 ? (gap / deductionPrice) * 100 : 0

            let trend: DeductionTrend
            if gapPercent > threshold {
                trend = .up
            } else if gapPercent < -threshold {
                trend = .down
            } else {
                trend = .flat
            }

            // 未來 N 日扣抵值走勢
            var futurePoints: [DeductionPoint] = []
            var flipDay: Int? = nil
            let todayTrend = trend

            for dayOffset in 0..<forecastDays {
                let idx = closes.count - period + dayOffset
                guard idx >= 0, idx < closes.count else { break }

                let futureDeduction = closes[idx]
                let futureGap = currentPrice - futureDeduction
                let futureGapPct = futureDeduction > 0 ? (futureGap / futureDeduction) * 100 : 0

                let futureTrend: DeductionTrend
                if futureGapPct > threshold {
                    futureTrend = .up
                } else if futureGapPct < -threshold {
                    futureTrend = .down
                } else {
                    futureTrend = .flat
                }

                futurePoints.append(DeductionPoint(
                    dayOffset: dayOffset,
                    deductionPrice: futureDeduction,
                    trend: futureTrend
                ))

                // 偵測翻轉：從趨升變趨降、或從趨降變趨升
                if flipDay == nil, dayOffset > 0 {
                    let isFlip: Bool
                    switch (todayTrend, futureTrend) {
                    case (.up, .down), (.down, .up):
                        isFlip = true
                    case (.flat, .up), (.flat, .down):
                        isFlip = true
                    default:
                        isFlip = false
                    }
                    if isFlip { flipDay = dayOffset }
                }
            }

            results.append(MADeductionInfo(
                period: period,
                deductionPrice: deductionPrice,
                currentMA: currentMA,
                currentPrice: currentPrice,
                trend: trend,
                gapPercent: gapPercent,
                futureDeductions: futurePoints,
                flipDay: flipDay
            ))
        }

        return results
    }

    // MARK: - 市場狀態

    /// 市場狀態分類（基於 MA20 斜率與價格位置）
    enum MarketRegime: String, Sendable {
        case bullish  = "多頭"   // MA20 向上 + 收盤 > MA20
        case bearish  = "空頭"   // MA20 向下 + 收盤 < MA20
        case sideways = "盤整"   // 其餘

        var label: String { rawValue }
    }

    /// 根據 MA20 斜率與收盤價位置判斷市場狀態
    static func detectRegime(closes: [Double], ma20Values: [Double?]) -> MarketRegime {
        // 需要至少 5 個有效 MA20 值
        let validMA = ma20Values.compactMap { $0 }
        guard validMA.count >= 5, let lastClose = closes.last else {
            return .sideways
        }

        let recent5 = Array(validMA.suffix(5))
        let firstMA = recent5[0]
        let lastMA = recent5[4]

        guard firstMA > 0 else { return .sideways }

        let slopePct = (lastMA - firstMA) / firstMA * 100  // 百分比

        if slopePct > 0.5 && lastClose > lastMA {
            return .bullish
        } else if slopePct < -0.5 && lastClose < lastMA {
            return .bearish
        } else {
            return .sideways
        }
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
                candlestickPatterns: [],
                regime: .sideways,
                atr: nil, atrPercent: nil,
                adx: nil, plusDI: nil, minusDI: nil, adxSignal: nil
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

        // ── 市場狀態偵測 ──
        let regime = detectRegime(closes: closes, ma20Values: maLongValues)

        // ── ATR ──
        let atrValues = atr(highs: highs, lows: lows, closes: closes, period: settings.atrPeriod)
        let latestATR = atrValues.last ?? nil
        let latestATRPercent: Double?
        if let a = latestATR, lastClose > 0 {
            latestATRPercent = a / lastClose * 100
        } else {
            latestATRPercent = nil
        }

        // ── ADX ──
        let adxValues = adx(highs: highs, lows: lows, closes: closes, period: settings.adxPeriod)
        let latestADX = adxValues.last ?? nil
        let adxSig: ADXSignal?
        if let adxResult = latestADX {
            if adxResult.adx >= settings.adxStrongThreshold {
                // ADX 趨勢方向判斷
                if adxValues.count >= 2,
                   let prev = adxValues[adxValues.count - 2] {
                    adxSig = adxResult.adx > prev.adx ? .trendStrengthening : .strongTrend
                } else {
                    adxSig = .strongTrend
                }
            } else {
                if adxValues.count >= 2,
                   let prev = adxValues[adxValues.count - 2] {
                    adxSig = adxResult.adx < prev.adx ? .trendWeakening : .weakTrend
                } else {
                    adxSig = .weakTrend
                }
            }
        } else {
            adxSig = nil
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
            candlestickPatterns: candlestickPatterns,
            regime: regime,
            atr: latestATR,
            atrPercent: latestATRPercent,
            adx: latestADX?.adx,
            plusDI: latestADX?.plusDI,
            minusDI: latestADX?.minusDI,
            adxSignal: adxSig
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
        trustStreak: Int?,
        foreignCumulativeNet: Int? = nil,
        trustCumulativeNet: Int? = nil,
        marginTotalChange: Int? = nil,
        shortTotalChange: Int? = nil,
        regime: MarketRegime = .sideways,
        settings: BuyScoreSettings = .load()
    ) -> SellRecommendation {
        var factors: [SellFactor] = []

        // ── 分組小計 ──
        var trendGroup = 0       // 趨勢組：MA cross, MACD cross
        var momentumGroup = 0    // 動量組：KDJ, RSI
        var volatilityGroup = 0  // 波動組：布林, 成交量
        var flowGroup = 0        // 籌碼組：法人
        var structureGroup = 0   // 結構組：背離, K 線型態
        var positionGroup = 0    // 位置組：MA5/MA20 位置
        var trailingGroup = 0    // 停利組：移動停利

        // ── 趨勢組：均線交叉 ──
        if let maCross = signal.maCross {
            switch maCross {
            case .deathCross:
                trendGroup += 15
                factors.append(SellFactor(name: "均線死叉", points: 15, isBearish: true))
            case .goldenCross:
                trendGroup -= 10
                factors.append(SellFactor(name: "均線金叉", points: -10, isBearish: false))
            }
        }

        // ── 趨勢組：MACD 交叉 ──
        if let macdSig = signal.macdSignal {
            switch macdSig {
            case .deathCross:
                trendGroup += 12
                factors.append(SellFactor(name: "MACD死叉", points: 12, isBearish: true))
            case .goldenCross:
                trendGroup -= 8
                factors.append(SellFactor(name: "MACD金叉", points: -8, isBearish: false))
            case .none:
                break
            }
        }

        // ── 動量組：KDJ 交叉 ──
        if let kdjSig = signal.kdjSignal {
            switch kdjSig {
            case .deathCross:
                momentumGroup += 10
                factors.append(SellFactor(name: "KD死叉", points: 10, isBearish: true))
            case .goldenCross:
                momentumGroup -= 6
                factors.append(SellFactor(name: "KD金叉", points: -6, isBearish: false))
            case .none:
                break
            }
        }

        // ── 動量組：RSI（盤整時打折）──
        if let rsiSig = signal.rsiSignal {
            let discount = regime == .sideways ? Double(settings.sidewaysDiscountPct) / 100.0 : 1.0
            switch rsiSig {
            case .overbought:
                let pts = Int(12.0 * discount)
                momentumGroup += pts
                factors.append(SellFactor(name: "RSI超買", points: pts, isBearish: true))
            case .oversold:
                let pts = Int(-8.0 * discount)
                momentumGroup += pts
                factors.append(SellFactor(name: "RSI超賣", points: pts, isBearish: false))
            case .neutral:
                break
            }
        }

        // ── 波動組：布林通道 ──
        if let bbSig = signal.bollingerSignal {
            switch bbSig {
            case .nearUpper:
                volatilityGroup += 8
                factors.append(SellFactor(name: "觸布林上軌", points: 8, isBearish: true))
            case .nearLower:
                volatilityGroup -= 6
                factors.append(SellFactor(name: "觸布林下軌", points: -6, isBearish: false))
            case .squeeze, .normal:
                break
            }
        }

        // ── 波動組：成交量 ──
        if let volSig = signal.volumeSignal {
            switch volSig {
            case .surge:
                volatilityGroup += 8
                factors.append(SellFactor(name: "爆量", points: 8, isBearish: true))
            case .shrink:
                volatilityGroup += 3
                factors.append(SellFactor(name: "量縮", points: 3, isBearish: true))
            case .high, .normal:
                break
            }
        }

        // ── 停利組：移動停利 ──
        if trailingStopTriggered {
            trailingGroup += 20
            factors.append(SellFactor(name: "跌破停利線", points: 20, isBearish: true))
        } else if nearTrailingStop {
            trailingGroup += 10
            factors.append(SellFactor(name: "接近停利線", points: 10, isBearish: true))
        } else {
            trailingGroup -= 5
            factors.append(SellFactor(name: "安全持有中", points: -5, isBearish: false))
        }

        // ── 位置組：MA 位置 ──
        if let ma5 = signal.ma5Position {
            if ma5 == .below {
                positionGroup += 5
                factors.append(SellFactor(name: "價格在MA5下方", points: 5, isBearish: true))
            } else {
                positionGroup -= 3
                factors.append(SellFactor(name: "價格在MA5上方", points: -3, isBearish: false))
            }
        }
        if let ma20 = signal.ma20Position {
            if ma20 == .below {
                positionGroup += 5
                factors.append(SellFactor(name: "價格在MA20下方", points: 5, isBearish: true))
            } else {
                positionGroup -= 3
                factors.append(SellFactor(name: "價格在MA20上方", points: -3, isBearish: false))
            }
        }

        // ── 籌碼組：法人動態 ──
        if let fs = foreignStreak, abs(fs) >= 3 {
            if fs < 0 {
                flowGroup += 5
                factors.append(SellFactor(name: "外資連賣\(abs(fs))日", points: 5, isBearish: true))
            } else {
                flowGroup -= 3
                factors.append(SellFactor(name: "外資連買\(fs)日", points: -3, isBearish: false))
            }
        }
        if let ts = trustStreak, abs(ts) >= 3 {
            if ts < 0 {
                flowGroup += 5
                factors.append(SellFactor(name: "投信連賣\(abs(ts))日", points: 5, isBearish: true))
            } else {
                flowGroup -= 3
                factors.append(SellFactor(name: "投信連買\(ts)日", points: -3, isBearish: false))
            }
        }

        // ── 籌碼組：法人累計淨買超（賣出角度：大量買超偏多持有，大量賣超偏空）──
        if let fcn = foreignCumulativeNet {
            if fcn <= -settings.foreignCumulativeLargeThreshold {
                flowGroup += settings.foreignCumulativeLargePoints
                factors.append(SellFactor(name: "外資累計賣超\(abs(fcn))張", points: settings.foreignCumulativeLargePoints, isBearish: true))
            } else if fcn <= -settings.foreignCumulativeSmallThreshold {
                flowGroup += settings.foreignCumulativeSmallPoints
                factors.append(SellFactor(name: "外資累計賣超\(abs(fcn))張", points: settings.foreignCumulativeSmallPoints, isBearish: true))
            } else if fcn >= settings.foreignCumulativeLargeThreshold {
                flowGroup -= settings.foreignCumulativeLargePoints
                factors.append(SellFactor(name: "外資累計買超\(fcn)張", points: -settings.foreignCumulativeLargePoints, isBearish: false))
            } else if fcn >= settings.foreignCumulativeSmallThreshold {
                flowGroup -= settings.foreignCumulativeSmallPoints
                factors.append(SellFactor(name: "外資累計買超\(fcn)張", points: -settings.foreignCumulativeSmallPoints, isBearish: false))
            }
        }
        if let tcn = trustCumulativeNet {
            if tcn <= -settings.trustCumulativeLargeThreshold {
                flowGroup += settings.trustCumulativeLargePoints
                factors.append(SellFactor(name: "投信累計賣超\(abs(tcn))張", points: settings.trustCumulativeLargePoints, isBearish: true))
            } else if tcn <= -settings.trustCumulativeSmallThreshold {
                flowGroup += settings.trustCumulativeSmallPoints
                factors.append(SellFactor(name: "投信累計賣超\(abs(tcn))張", points: settings.trustCumulativeSmallPoints, isBearish: true))
            } else if tcn >= settings.trustCumulativeLargeThreshold {
                flowGroup -= settings.trustCumulativeLargePoints
                factors.append(SellFactor(name: "投信累計買超\(tcn)張", points: -settings.trustCumulativeLargePoints, isBearish: false))
            } else if tcn >= settings.trustCumulativeSmallThreshold {
                flowGroup -= settings.trustCumulativeSmallPoints
                factors.append(SellFactor(name: "投信累計買超\(tcn)張", points: -settings.trustCumulativeSmallPoints, isBearish: false))
            }
        }

        // ── 籌碼組：融資融券（賣出角度）──
        if let mc = marginTotalChange, abs(mc) >= settings.marginChangeThreshold {
            if mc > 0 {
                // 融資增加 = 散戶追多 → 賣出加分（偏空）
                let pts = abs(settings.marginIncreasePoints)
                flowGroup += pts
                factors.append(SellFactor(name: "融資增加\(mc)張", points: pts, isBearish: true))
            } else {
                // 融資減少 = 賣壓釋放 → 賣出減分（偏多）
                let pts = abs(settings.marginDecreasePoints)
                flowGroup -= pts
                factors.append(SellFactor(name: "融資減少\(abs(mc))張", points: -pts, isBearish: false))
            }
        }
        if let sc = shortTotalChange, abs(sc) >= settings.marginChangeThreshold {
            if sc > 0 {
                // 融券增加 = 軋空潛力 → 賣出減分（偏多）
                let pts = abs(settings.shortIncreasePoints)
                flowGroup -= pts
                factors.append(SellFactor(name: "融券增加\(sc)張", points: -pts, isBearish: false))
            } else {
                // 融券減少 = 回補完畢 → 賣出加分（偏空）
                let pts = abs(settings.shortDecreasePoints)
                flowGroup += pts
                factors.append(SellFactor(name: "融券減少\(abs(sc))張", points: pts, isBearish: true))
            }
        }

        // ── 結構組：背離 ──
        for div in signal.divergences {
            switch (div.indicator, div.type) {
            case ("RSI", .bearish):
                structureGroup += 10
                factors.append(SellFactor(name: "RSI頂背離", points: 10, isBearish: true))
            case ("MACD", .bearish):
                structureGroup += 10
                factors.append(SellFactor(name: "MACD頂背離", points: 10, isBearish: true))
            case ("RSI", .bullish):
                structureGroup -= 6
                factors.append(SellFactor(name: "RSI底背離", points: -6, isBearish: false))
            case ("MACD", .bullish):
                structureGroup -= 6
                factors.append(SellFactor(name: "MACD底背離", points: -6, isBearish: false))
            default:
                break
            }
        }

        // ── 結構組：K 線型態 ──
        for pattern in signal.candlestickPatterns {
            guard pattern.direction != .neutral else { continue }
            let points: Int
            switch pattern.reliability {
            case .high:   points = pattern.direction == .bearish ? 8 : -8
            case .medium: points = pattern.direction == .bearish ? 5 : -5
            case .low:    points = pattern.direction == .bearish ? 3 : -3
            }
            structureGroup += points
            factors.append(SellFactor(
                name: pattern.pattern.rawValue,
                points: points,
                isBearish: pattern.direction == .bearish
            ))
        }

        // ── 分組上限（去相關化）──
        let cap = settings.trendGroupCap
        let mCap = settings.momentumGroupCap
        let cappedTrend = min(cap, max(-cap, trendGroup))
        let cappedMomentum = min(mCap, max(-mCap, momentumGroup))

        if cappedTrend != trendGroup {
            let diff = cappedTrend - trendGroup
            factors.append(SellFactor(name: "趨勢組上限", points: diff, isBearish: diff > 0))
        }
        if cappedMomentum != momentumGroup {
            let diff = cappedMomentum - momentumGroup
            factors.append(SellFactor(name: "動量組上限", points: diff, isBearish: diff > 0))
        }

        let score = 50 + cappedTrend + cappedMomentum + volatilityGroup + flowGroup + structureGroup + positionGroup + trailingGroup

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

    // MARK: - Buy Recommendation

    /// 買入建議等級
    enum BuyLevel: Sendable {
        case strongBuy      // ≥ 70
        case considerBuy    // 50–69
        case neutral        // 30–49
        case cautious       // 10–29
        case avoidBuy       // < 10

        var label: String {
            switch self {
            case .strongBuy:   return "強烈建議買入"
            case .considerBuy: return "建議考慮買入"
            case .neutral:     return "觀望"
            case .cautious:    return "偏空謹慎"
            case .avoidBuy:    return "暫不建議買入"
            }
        }

        var shortLabel: String {
            switch self {
            case .strongBuy:   return "建議買入"
            case .considerBuy: return "考慮買入"
            case .neutral:     return "觀望"
            case .cautious:    return "謹慎"
            case .avoidBuy:    return "不宜買入"
            }
        }

        var icon: String {
            switch self {
            case .strongBuy:   return "checkmark.shield.fill"
            case .considerBuy: return "hand.thumbsup"
            case .neutral:     return "minus.circle"
            case .cautious:    return "exclamationmark.circle.fill"
            case .avoidBuy:    return "exclamationmark.triangle.fill"
            }
        }
    }

    /// 買入影響因子
    struct BuyFactor: Sendable, Identifiable {
        let id = UUID()
        let name: String      // e.g. "均線金叉"
        let points: Int       // e.g. +12 or -8
        let isBullish: Bool   // true = 偏多（加分）, false = 偏空（扣分）
    }

    /// 買入建議結果
    struct BuyRecommendation: Sendable {
        let score: Int              // 0–100
        let level: BuyLevel
        let factors: [BuyFactor]
    }

    /// 計算綜合買入建議
    static func computeBuyRecommendation(
        signal: SignalSummary,
        week52High: Double?,
        week52Low: Double?,
        currentPrice: Double,
        foreignStreak: Int?,
        trustStreak: Int?,
        foreignCumulativeNet: Int? = nil,
        trustCumulativeNet: Int? = nil,
        marginTotalChange: Int? = nil,
        shortTotalChange: Int? = nil,
        regime: MarketRegime = .sideways,
        settings: BuyScoreSettings = .load()
    ) -> BuyRecommendation {
        var factors: [BuyFactor] = []

        // ── 分組小計 ──
        var trendGroup = 0       // 趨勢組：MA cross, MACD cross, DIF
        var momentumGroup = 0    // 動量組：KDJ, RSI
        var volatilityGroup = 0  // 波動組：布林, 成交量
        var flowGroup = 0        // 籌碼組：法人
        var structureGroup = 0   // 結構組：背離, K 線型態, 52 週
        var positionGroup = 0    // 位置組：MA5/MA20 位置

        // ── 趨勢組：均線交叉 ──
        if let maCross = signal.maCross {
            switch maCross {
            case .goldenCross:
                trendGroup += settings.maGoldenCrossPoints
                factors.append(BuyFactor(name: "均線金叉", points: settings.maGoldenCrossPoints, isBullish: true))
            case .deathCross:
                trendGroup += settings.maDeathCrossPoints
                factors.append(BuyFactor(name: "均線死叉", points: settings.maDeathCrossPoints, isBullish: false))
            }
        }

        // ── 趨勢組：MACD 交叉 ──
        if let macdSig = signal.macdSignal {
            switch macdSig {
            case .goldenCross:
                trendGroup += settings.macdGoldenCrossPoints
                factors.append(BuyFactor(name: "MACD金叉", points: settings.macdGoldenCrossPoints, isBullish: true))
            case .deathCross:
                trendGroup += settings.macdDeathCrossPoints
                factors.append(BuyFactor(name: "MACD死叉", points: settings.macdDeathCrossPoints, isBullish: false))
            case .none:
                break
            }
        }

        // ── 趨勢組：MACD DIF 方向 ──
        if let dif = signal.macdDIF {
            if dif > 0 {
                trendGroup += settings.macdPositivePoints
                factors.append(BuyFactor(name: "DIF > 0", points: settings.macdPositivePoints, isBullish: true))
            } else if dif < 0 {
                trendGroup += settings.macdNegativePoints
                factors.append(BuyFactor(name: "DIF < 0", points: settings.macdNegativePoints, isBullish: false))
            }
        }

        // ── 動量組：KDJ 交叉 ──
        if let kdjSig = signal.kdjSignal {
            switch kdjSig {
            case .goldenCross:
                momentumGroup += settings.kdjGoldenCrossPoints
                factors.append(BuyFactor(name: "KD金叉", points: settings.kdjGoldenCrossPoints, isBullish: true))
            case .deathCross:
                momentumGroup += settings.kdjDeathCrossPoints
                factors.append(BuyFactor(name: "KD死叉", points: settings.kdjDeathCrossPoints, isBullish: false))
            case .none:
                break
            }
        }

        // ── 動量組：KDJ 超買超賣（盤整時打折）──
        if let k = signal.kdjK {
            let discount = regime == .sideways ? Double(settings.sidewaysDiscountPct) / 100.0 : 1.0
            if k < 20 {
                let pts = Int(Double(settings.kdjOversoldPoints) * discount)
                momentumGroup += pts
                factors.append(BuyFactor(name: "KD超賣", points: pts, isBullish: true))
            } else if k > 80 {
                let pts = Int(Double(settings.kdjOverboughtPoints) * discount)
                momentumGroup += pts
                factors.append(BuyFactor(name: "KD超買", points: pts, isBullish: false))
            }
        }

        // ── 動量組：RSI（盤整時打折）──
        if let rsiSig = signal.rsiSignal {
            let discount = regime == .sideways ? Double(settings.sidewaysDiscountPct) / 100.0 : 1.0
            switch rsiSig {
            case .oversold:
                let pts = Int(Double(settings.rsiOversoldPoints) * discount)
                momentumGroup += pts
                factors.append(BuyFactor(name: "RSI超賣", points: pts, isBullish: true))
            case .overbought:
                let pts = Int(Double(settings.rsiOverboughtPoints) * discount)
                momentumGroup += pts
                factors.append(BuyFactor(name: "RSI超買", points: pts, isBullish: false))
            case .neutral:
                break
            }
        }

        // ── 波動組：布林通道 ──
        if let bbSig = signal.bollingerSignal {
            switch bbSig {
            case .nearLower:
                volatilityGroup += settings.bollingerLowerPoints
                factors.append(BuyFactor(name: "觸布林下軌", points: settings.bollingerLowerPoints, isBullish: true))
            case .nearUpper:
                volatilityGroup += settings.bollingerUpperPoints
                factors.append(BuyFactor(name: "觸布林上軌", points: settings.bollingerUpperPoints, isBullish: false))
            case .squeeze, .normal:
                break
            }
        }

        // ── 波動組：成交量 ──
        if let volSig = signal.volumeSignal {
            switch volSig {
            case .surge, .high:
                volatilityGroup += settings.volumeSurgePoints
                factors.append(BuyFactor(name: "量增", points: settings.volumeSurgePoints, isBullish: true))
            case .shrink:
                volatilityGroup += settings.volumeShrinkPoints
                factors.append(BuyFactor(name: "量縮", points: settings.volumeShrinkPoints, isBullish: false))
            case .normal:
                break
            }
        }

        // ── 位置組：MA 位置 ──
        if let ma5 = signal.ma5Position {
            if ma5 == .above {
                positionGroup += settings.aboveMA5Points
                factors.append(BuyFactor(name: "價格在MA5上方", points: settings.aboveMA5Points, isBullish: true))
            } else {
                positionGroup += settings.belowMA5Points
                factors.append(BuyFactor(name: "價格在MA5下方", points: settings.belowMA5Points, isBullish: false))
            }
        }
        if let ma20 = signal.ma20Position {
            if ma20 == .above {
                positionGroup += settings.aboveMA20Points
                factors.append(BuyFactor(name: "價格在MA20上方", points: settings.aboveMA20Points, isBullish: true))
            } else {
                positionGroup += settings.belowMA20Points
                factors.append(BuyFactor(name: "價格在MA20下方", points: settings.belowMA20Points, isBullish: false))
            }
        }

        // ── 籌碼組：法人動態 ──
        if let fs = foreignStreak, abs(fs) >= 3 {
            if fs > 0 {
                flowGroup += settings.foreignBuyStreakPoints
                factors.append(BuyFactor(name: "外資連買\(fs)日", points: settings.foreignBuyStreakPoints, isBullish: true))
            } else {
                flowGroup += settings.foreignSellStreakPoints
                factors.append(BuyFactor(name: "外資連賣\(abs(fs))日", points: settings.foreignSellStreakPoints, isBullish: false))
            }
        }
        if let ts = trustStreak, abs(ts) >= 3 {
            if ts > 0 {
                flowGroup += settings.trustBuyStreakPoints
                factors.append(BuyFactor(name: "投信連買\(ts)日", points: settings.trustBuyStreakPoints, isBullish: true))
            } else {
                flowGroup += settings.trustSellStreakPoints
                factors.append(BuyFactor(name: "投信連賣\(abs(ts))日", points: settings.trustSellStreakPoints, isBullish: false))
            }
        }

        // ── 籌碼組：法人累計淨買超 ──
        if let fcn = foreignCumulativeNet {
            if fcn >= settings.foreignCumulativeLargeThreshold {
                flowGroup += settings.foreignCumulativeLargePoints
                factors.append(BuyFactor(name: "外資累計買超\(fcn)張", points: settings.foreignCumulativeLargePoints, isBullish: true))
            } else if fcn >= settings.foreignCumulativeSmallThreshold {
                flowGroup += settings.foreignCumulativeSmallPoints
                factors.append(BuyFactor(name: "外資累計買超\(fcn)張", points: settings.foreignCumulativeSmallPoints, isBullish: true))
            } else if fcn <= -settings.foreignCumulativeLargeThreshold {
                flowGroup -= settings.foreignCumulativeLargePoints
                factors.append(BuyFactor(name: "外資累計賣超\(abs(fcn))張", points: -settings.foreignCumulativeLargePoints, isBullish: false))
            } else if fcn <= -settings.foreignCumulativeSmallThreshold {
                flowGroup -= settings.foreignCumulativeSmallPoints
                factors.append(BuyFactor(name: "外資累計賣超\(abs(fcn))張", points: -settings.foreignCumulativeSmallPoints, isBullish: false))
            }
        }
        if let tcn = trustCumulativeNet {
            if tcn >= settings.trustCumulativeLargeThreshold {
                flowGroup += settings.trustCumulativeLargePoints
                factors.append(BuyFactor(name: "投信累計買超\(tcn)張", points: settings.trustCumulativeLargePoints, isBullish: true))
            } else if tcn >= settings.trustCumulativeSmallThreshold {
                flowGroup += settings.trustCumulativeSmallPoints
                factors.append(BuyFactor(name: "投信累計買超\(tcn)張", points: settings.trustCumulativeSmallPoints, isBullish: true))
            } else if tcn <= -settings.trustCumulativeLargeThreshold {
                flowGroup -= settings.trustCumulativeLargePoints
                factors.append(BuyFactor(name: "投信累計賣超\(abs(tcn))張", points: -settings.trustCumulativeLargePoints, isBullish: false))
            } else if tcn <= -settings.trustCumulativeSmallThreshold {
                flowGroup -= settings.trustCumulativeSmallPoints
                factors.append(BuyFactor(name: "投信累計賣超\(abs(tcn))張", points: -settings.trustCumulativeSmallPoints, isBullish: false))
            }
        }

        // ── 籌碼組：融資融券（買入角度）──
        if let mc = marginTotalChange, abs(mc) >= settings.marginChangeThreshold {
            if mc > 0 {
                // 融資增加 = 散戶追多 → 買入扣分（偏空）
                flowGroup += settings.marginIncreasePoints
                factors.append(BuyFactor(name: "融資增加\(mc)張", points: settings.marginIncreasePoints, isBullish: false))
            } else {
                // 融資減少 = 賣壓釋放 → 買入加分（偏多）
                flowGroup += settings.marginDecreasePoints
                factors.append(BuyFactor(name: "融資減少\(abs(mc))張", points: settings.marginDecreasePoints, isBullish: true))
            }
        }
        if let sc = shortTotalChange, abs(sc) >= settings.marginChangeThreshold {
            if sc > 0 {
                // 融券增加 = 軋空潛力 → 買入加分（偏多）
                flowGroup += settings.shortIncreasePoints
                factors.append(BuyFactor(name: "融券增加\(sc)張", points: settings.shortIncreasePoints, isBullish: true))
            } else {
                // 融券減少 = 回補完畢 → 買入扣分（偏空）
                flowGroup += settings.shortDecreasePoints
                factors.append(BuyFactor(name: "融券減少\(abs(sc))張", points: settings.shortDecreasePoints, isBullish: false))
            }
        }

        // ── 結構組：背離 ──
        for div in signal.divergences {
            switch (div.indicator, div.type) {
            case ("RSI", .bullish):
                structureGroup += settings.rsiBullishDivPoints
                factors.append(BuyFactor(name: "RSI底背離", points: settings.rsiBullishDivPoints, isBullish: true))
            case ("MACD", .bullish):
                structureGroup += settings.macdBullishDivPoints
                factors.append(BuyFactor(name: "MACD底背離", points: settings.macdBullishDivPoints, isBullish: true))
            case ("RSI", .bearish):
                structureGroup += settings.rsiBearishDivPoints
                factors.append(BuyFactor(name: "RSI頂背離", points: settings.rsiBearishDivPoints, isBullish: false))
            case ("MACD", .bearish):
                structureGroup += settings.macdBearishDivPoints
                factors.append(BuyFactor(name: "MACD頂背離", points: settings.macdBearishDivPoints, isBullish: false))
            default:
                break
            }
        }

        // ── 結構組：K 線型態 ──
        for pattern in signal.candlestickPatterns {
            guard pattern.direction != .neutral else { continue }
            let pts: Int
            switch (pattern.reliability, pattern.direction) {
            case (.high, .bullish):   pts = settings.candleHighBullishPoints
            case (.high, .bearish):   pts = settings.candleHighBearishPoints
            case (.medium, .bullish): pts = settings.candleMedBullishPoints
            case (.medium, .bearish): pts = settings.candleMedBearishPoints
            case (.low, .bullish):    pts = settings.candleLowBullishPoints
            case (.low, .bearish):    pts = settings.candleLowBearishPoints
            default:                  pts = 0
            }
            structureGroup += pts
            factors.append(BuyFactor(
                name: pattern.pattern.rawValue,
                points: pts,
                isBullish: pattern.direction == .bullish
            ))
        }

        // ── 結構組：52 週位置 ──
        if let low52 = week52Low, let high52 = week52High, high52 > low52, currentPrice > 0 {
            let range52 = high52 - low52
            let positionPct = (currentPrice - low52) / range52
            if positionPct <= 0.15 {
                structureGroup += settings.near52WeekLowPoints
                factors.append(BuyFactor(name: "接近52週低點", points: settings.near52WeekLowPoints, isBullish: true))
            } else if positionPct >= 0.85 {
                structureGroup += settings.near52WeekHighPoints
                factors.append(BuyFactor(name: "接近52週高點", points: settings.near52WeekHighPoints, isBullish: false))
            }
        }

        // ── 分組上限（去相關化）──
        let cap = settings.trendGroupCap
        let mCap = settings.momentumGroupCap
        let cappedTrend = min(cap, max(-cap, trendGroup))
        let cappedMomentum = min(mCap, max(-mCap, momentumGroup))

        // 如果被壓縮，記錄壓縮因子
        if cappedTrend != trendGroup {
            let diff = cappedTrend - trendGroup
            factors.append(BuyFactor(name: "趨勢組上限", points: diff, isBullish: diff > 0))
        }
        if cappedMomentum != momentumGroup {
            let diff = cappedMomentum - momentumGroup
            factors.append(BuyFactor(name: "動量組上限", points: diff, isBullish: diff > 0))
        }

        let score = 50 + cappedTrend + cappedMomentum + volatilityGroup + flowGroup + structureGroup + positionGroup

        // Clamp
        let finalScore = min(100, max(0, score))

        // 決定等級
        let level: BuyLevel
        switch finalScore {
        case 70...100: level = .strongBuy
        case 50..<70:  level = .considerBuy
        case 30..<50:  level = .neutral
        case 10..<30:  level = .cautious
        default:       level = .avoidBuy
        }

        // 排序：偏多在前，絕對值大在前
        let sorted = factors.sorted { a, b in
            if a.isBullish != b.isBullish { return a.isBullish }
            return abs(a.points) > abs(b.points)
        }

        return BuyRecommendation(score: finalScore, level: level, factors: sorted)
    }
}
