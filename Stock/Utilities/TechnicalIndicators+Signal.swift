import Foundation

// MARK: - TechnicalIndicators + Signal Summary Computation

extension TechnicalIndicators {

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
}
