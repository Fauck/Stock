import Foundation

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
                volumeSignal: nil, volumeRatio: nil
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
            volumeRatio: volRatio
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
