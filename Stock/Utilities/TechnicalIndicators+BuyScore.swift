import Foundation

// MARK: - TechnicalIndicators + Buy Recommendation

extension TechnicalIndicators {

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
