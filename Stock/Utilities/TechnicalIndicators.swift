import Foundation

extension Array {
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
}
