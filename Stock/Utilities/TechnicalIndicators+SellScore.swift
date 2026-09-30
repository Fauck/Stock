import Foundation

// MARK: - TechnicalIndicators + Sell Recommendation

extension TechnicalIndicators {

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
}
