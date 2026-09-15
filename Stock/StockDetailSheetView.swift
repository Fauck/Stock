//
//  StockDetailSheetView.swift
//  Stock
//
//  個股分析滿版頁面：K 線走勢 + 技術指標 + 52 週區間
//

import SwiftUI
import SwiftData

struct StockDetailSheetView: View {
    let group: PortfolioGroup
    let signal: TechnicalIndicators.SignalSummary?
    let weekStats: WeekStats?
    let currentPrice: Double?
    let displayName: String
    let highSinceBuy: Double?
    let institutionalData: StockService.InstitutionalSummary?
    let marginData: StockService.MarginTradingSummary?
    let sellRecommendation: TechnicalIndicators.SellRecommendation?
    let journalTarget: JournalTarget?
    let maDeductions: [TechnicalIndicators.MADeductionInfo]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allJournals: [TradeJournal]
    @Query(filter: #Predicate<Investment> { !$0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var allInvestments: [Investment]
    @State private var chartVM: KLineChartViewModel
    @State private var showingTargetStopEdit = false

    /// 動態計算目標/停損（從 @Query 即時讀取，編輯後自動更新）
    private var liveJournalTarget: JournalTarget? {
        let investmentIDs = Set(allInvestments.filter { $0.ticker == group.ticker }.map(\.id))
        let matchingJournals = allJournals.filter { investmentIDs.contains($0.investmentID) }
        var targetPrice: Double? = nil
        var stopLoss: Double? = nil
        for j in matchingJournals {
            if targetPrice == nil, let t = j.targetPrice { targetPrice = t }
            if stopLoss == nil, let s = j.initialStopLoss { stopLoss = s }
            if targetPrice != nil && stopLoss != nil { break }
        }
        if targetPrice == nil && stopLoss == nil { return nil }
        return JournalTarget(targetPrice: targetPrice, stopLoss: stopLoss)
    }

    init(
        group: PortfolioGroup,
        signal: TechnicalIndicators.SignalSummary?,
        weekStats: WeekStats?,
        currentPrice: Double?,
        displayName: String,
        highSinceBuy: Double? = nil,
        institutionalData: StockService.InstitutionalSummary? = nil,
        marginData: StockService.MarginTradingSummary? = nil,
        sellRecommendation: TechnicalIndicators.SellRecommendation? = nil,
        journalTarget: JournalTarget? = nil,
        maDeductions: [TechnicalIndicators.MADeductionInfo] = []
    ) {
        self.group = group
        self.signal = signal
        self.weekStats = weekStats
        self.currentPrice = currentPrice
        self.displayName = displayName
        self.highSinceBuy = highSinceBuy
        self.institutionalData = institutionalData
        self.marginData = marginData
        self.sellRecommendation = sellRecommendation
        self.journalTarget = journalTarget
        self.maDeductions = maDeductions
        self._chartVM = State(initialValue: KLineChartViewModel(group: group))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // K 線走勢圖
                        klineSection

                        // 技術指標信號
                        if let signal {
                            technicalSignalSection(signal)
                        }

                        // 背離信號
                        if let signal, !signal.divergences.isEmpty {
                            divergenceSection(signal.divergences)
                        }

                        // 賣出建議
                        if let rec = sellRecommendation {
                            sellRecommendationSection(rec)
                        }

                        // 目標 / 停損
                        if let price = currentPrice,
                           let jt = liveJournalTarget,
                           (jt.targetPrice != nil || jt.stopLoss != nil) {
                            targetStopSection(currentPrice: price, target: jt, avgCost: group.weightedAverageCost)
                        } else {
                            // 尚未設定，提供設定按鈕
                            Button { showingTargetStopEdit = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "target")
                                        .font(.system(size: 12))
                                    Text("設定目標 / 停損")
                                        .font(.warmDataValue())
                                }
                                .foregroundStyle(AppColor.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(AppColor.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        // 移動停利建議
                        if let price = currentPrice, let high = highSinceBuy, high > 0 {
                            trailingStopSection(currentPrice: price, highSinceBuy: high, avgCost: group.weightedAverageCost)
                        }

                        // 法人買賣超
                        if let inst = institutionalData {
                            institutionalSection(inst)
                        }

                        // 融資融券
                        if let margin = marginData {
                            marginTradingSection(margin)
                        }

                        // 均線扣抵值
                        if !maDeductions.isEmpty {
                            maDeductionSection
                        }

                        // K 線型態（僅供參考）
                        if let signal, !signal.candlestickPatterns.isEmpty {
                            candlestickPatternSection(signal.candlestickPatterns)
                        }

                        // 52 週區間
                        if let stats = weekStats,
                           stats.high52w > stats.low52w {
                            weekStatsSection(stats)
                        }
                        // 壓力/支撐價位
                        if TradingFeeSettings.load().supportResistanceEnabled,
                           let signal, let price = currentPrice {
                            supportResistanceSection(signal: signal, currentPrice: price)
                        }

                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("\(displayName) (\(group.ticker))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .task {
                await chartVM.loadCandles()
            }
            .sheet(isPresented: $showingTargetStopEdit) {
                TargetStopEditSheetInDetail(
                    ticker: group.ticker,
                    journal: latestJournalForTicker(),
                    investment: latestInvestmentForTicker()
                )
            }
        }
    }

    /// 找到此 ticker 最近的 journal（依 investment buyDate 排序取最新）
    private func latestJournalForTicker() -> TradeJournal? {
        let tickerInvestments = allInvestments.filter { $0.ticker == group.ticker }
        for inv in tickerInvestments {
            if let j = allJournals.first(where: { $0.investmentID == inv.id }) {
                return j
            }
        }
        return nil
    }

    /// 找到此 ticker 最近的 investment
    private func latestInvestmentForTicker() -> Investment? {
        allInvestments.first { $0.ticker == group.ticker }
    }

    // MARK: - K 線走勢圖

    private var klineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("K 線走勢")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            KLineChartView(vm: chartVM)
                .frame(minHeight: 320)
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    // MARK: - 技術指標信號

    private func technicalSignalSection(_ signal: TechnicalIndicators.SignalSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("技術指標")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 操作建議（觸發條件摘要）
            let actionSignals = buildActionSignals(signal)
            if !actionSignals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(actionSignals, id: \.text) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(item.color)
                                .frame(width: 14)
                            Text(item.text)
                                .font(.warmSecondaryData())
                                .foregroundStyle(AppColor.textMain)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.background.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
            }

            // 均線 & 交叉
            signalRow(title: "均線") {
                if let ma5 = signal.ma5Position {
                    signalPill(
                        ma5 == .above ? "MA5↑" : "MA5↓",
                        color: ma5 == .above ? AppColor.softUp : AppColor.softDown
                    )
                }
                if let ma20 = signal.ma20Position {
                    signalPill(
                        ma20 == .above ? "MA20↑" : "MA20↓",
                        color: ma20 == .above ? AppColor.softUp : AppColor.softDown
                    )
                }
                if let maCross = signal.maCross {
                    signalPill(
                        maCross.label,
                        color: maCross == .goldenCross ? AppColor.softUp : AppColor.softDown,
                        filled: true
                    )
                }
            }

            // RSI
            signalRow(title: "RSI") {
                if let rsi = signal.rsi {
                    let rsiColor: Color = {
                        if rsi > 80 { return AppColor.softUp }
                        if rsi < 20 { return AppColor.softDown }
                        return AppColor.textSecondary
                    }()
                    signalPill(
                        "RSI \(String(format: "%.0f", rsi))",
                        color: rsiColor
                    )
                    if let rsiSig = signal.rsiSignal, let label = rsiSig.label {
                        signalPill(label, color: rsiSig == .overbought ? AppColor.softUp : AppColor.softDown, filled: true)
                    }
                }
            }

            // KDJ
            signalRow(title: "KDJ") {
                if let k = signal.kdjK, let d = signal.kdjD {
                    signalPill(
                        "K\(String(format: "%.0f", k)) D\(String(format: "%.0f", d))",
                        color: AppColor.textSecondary
                    )
                }
                if let kdjSig = signal.kdjSignal, let label = kdjSig.label {
                    signalPill(label, color: kdjSig == .goldenCross ? AppColor.softUp : AppColor.softDown, filled: true)
                }
            }

            // MACD
            signalRow(title: "MACD") {
                if let dif = signal.macdDIF, let dea = signal.macdDEA {
                    signalPill(
                        "DIF \(String(format: "%.2f", dif))",
                        color: dif >= 0 ? AppColor.softUp : AppColor.softDown
                    )
                    signalPill(
                        "DEA \(String(format: "%.2f", dea))",
                        color: dea >= 0 ? AppColor.softUp : AppColor.softDown
                    )
                }
                if let macdSig = signal.macdSignal, let label = macdSig.label {
                    signalPill(label, color: macdSig == .goldenCross ? AppColor.softUp : AppColor.softDown, filled: true)
                }
            }

            // 布林通道 & 成交量
            signalRow(title: "其他") {
                if let bbSig = signal.bollingerSignal, let label = bbSig.label {
                    signalPill(
                        label,
                        color: bbSig == .nearLower ? AppColor.softDown : (bbSig == .nearUpper ? AppColor.softUp : AppColor.primary),
                        filled: true
                    )
                }
                if let volSig = signal.volumeSignal, let label = volSig.label {
                    let volColor: Color = {
                        switch volSig {
                        case .surge: return AppColor.softUp
                        case .high: return AppColor.secondary
                        case .shrink: return AppColor.textSecondary
                        case .normal: return AppColor.textSecondary
                        }
                    }()
                    signalPill(label, color: volColor, filled: true)
                    if let ratio = signal.volumeRatio {
                        signalPill("量比 \(String(format: "%.1f", ratio))", color: volColor)
                    }
                }
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    /// 指標分類行
    private func signalRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 32, alignment: .leading)
            content()
        }
    }

    // MARK: - 背離信號卡片

    private func divergenceSection(_ divergences: [TechnicalIndicators.DivergenceSignal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("背離信號")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            ForEach(divergences) { div in
                let isBearish = div.type == .bearish
                let typeLabel = isBearish ? "頂背離" : "底背離"
                let color: Color = isBearish ? AppColor.softDown : AppColor.softUp
                let icon = isBearish ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                let description = isBearish
                    ? "價格創新高但\(div.indicator)未跟上，動能衰減"
                    : "價格創新低但\(div.indicator)未跟下，動能回升"

                VStack(alignment: .leading, spacing: 6) {
                    // 標題行
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundStyle(color)
                        Text("\(div.indicator) \(typeLabel)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(color)
                        Spacer()
                        Text("\(div.barsAgo) 日前起")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    // 數據對比
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("股價")
                                .font(.warmMicro())
                                .foregroundStyle(AppColor.textSecondary)
                            HStack(spacing: 4) {
                                Text(String(format: "%.1f", div.pricePoint1))
                                    .font(.warmSecondaryData())
                                    .foregroundStyle(AppColor.textMain)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(AppColor.textSecondary)
                                Text(String(format: "%.1f", div.pricePoint2))
                                    .font(.warmSecondaryData(.semibold))
                                    .foregroundStyle(AppColor.textMain)
                                let priceDir = div.pricePoint2 >= div.pricePoint1
                                Image(systemName: priceDir ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(priceDir ? AppColor.softUp : AppColor.softDown)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(div.indicator)
                                .font(.warmMicro())
                                .foregroundStyle(AppColor.textSecondary)
                            HStack(spacing: 4) {
                                Text(div.indicator == "RSI"
                                     ? String(format: "%.1f", div.indicatorPoint1)
                                     : String(format: "%.2f", div.indicatorPoint1))
                                    .font(.warmSecondaryData())
                                    .foregroundStyle(AppColor.textMain)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(AppColor.textSecondary)
                                Text(div.indicator == "RSI"
                                     ? String(format: "%.1f", div.indicatorPoint2)
                                     : String(format: "%.2f", div.indicatorPoint2))
                                    .font(.warmSecondaryData(.semibold))
                                    .foregroundStyle(AppColor.textMain)
                                let indDir = div.indicatorPoint2 >= div.indicatorPoint1
                                Image(systemName: indDir ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(indDir ? AppColor.softUp : AppColor.softDown)
                            }
                        }
                    }

                    // 說明
                    Text(description)
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    // MARK: - 均線扣抵值卡片

    private var maDeductionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.warmMicro(.semibold))
                    .foregroundStyle(AppColor.primary)
                Text("均線扣抵值")
                    .font(.warmTertiary(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 表格
            VStack(spacing: 6) {
                // 表頭
                HStack {
                    Text("均線")
                        .frame(width: 50, alignment: .leading)
                    Text("扣抵價")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("現價")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("預判")
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.warmTertiary())
                .foregroundStyle(AppColor.textSecondary)

                AppColor.divider.frame(height: 0.5)

                ForEach(maDeductions) { d in
                    HStack {
                        Text(d.periodLabel)
                            .font(.warmSecondaryData(.semibold))
                            .foregroundStyle(AppColor.textMain)
                            .frame(width: 50, alignment: .leading)

                        Text(formatDeductionPrice(d.deductionPrice))
                            .font(.warmSecondaryData())
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(formatDeductionPrice(d.currentPrice))
                            .font(.warmSecondaryData(.semibold))
                            .foregroundStyle(AppColor.textMain)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        HStack(spacing: 3) {
                            Image(systemName: deductionIcon(d.trend))
                                .font(.system(size: 7))
                            Text(d.trend.rawValue)
                                .font(.warmSecondaryData(.semibold))
                        }
                        .foregroundStyle(deductionColor(d.trend))
                        .frame(width: 70, alignment: .trailing)
                    }
                }
            }

            // 未來走勢圖
            AppColor.divider.frame(height: 0.5)

            ForEach(maDeductions) { d in
                if d.futureDeductions.count >= 2 {
                    DeductionForecastChart(info: d)
                }
            }

            // 解讀
            if let key = maDeductions.first(where: { $0.period == 20 }) ?? maDeductions.first {
                AppColor.divider.frame(height: 0.5)
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "lightbulb.min")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(.top, 1)
                    Text(deductionInterpretation(key))
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .cardShadow()
    }

    private func deductionIcon(_ trend: TechnicalIndicators.DeductionTrend) -> String {
        switch trend {
        case .up:   return "arrowtriangle.up.fill"
        case .down: return "arrowtriangle.down.fill"
        case .flat: return "minus"
        }
    }

    private func deductionColor(_ trend: TechnicalIndicators.DeductionTrend) -> Color {
        switch trend {
        case .up:   return AppColor.softUp
        case .down: return AppColor.softDown
        case .flat: return AppColor.textSecondary
        }
    }

    private func formatDeductionPrice(_ price: Double) -> String {
        if price >= 100 {
            return String(format: "%.0f", price)
        } else if price >= 10 {
            return String(format: "%.1f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }

    private func deductionInterpretation(_ d: TechnicalIndicators.MADeductionInfo) -> String {
        let gap = String(format: "%.1f%%", abs(d.gapPercent))
        switch d.trend {
        case .up:
            return "\(d.periodLabel) 扣抵價 \(formatDeductionPrice(d.deductionPrice)) 低於現價（差距 \(gap)），均線近期有上彎動能"
        case .down:
            return "\(d.periodLabel) 扣抵價 \(formatDeductionPrice(d.deductionPrice)) 高於現價（差距 \(gap)），均線近期有下彎壓力"
        case .flat:
            return "\(d.periodLabel) 扣抵價與現價接近，均線走勢持平"
        }
    }

    // MARK: - K 線型態卡片

    private func candlestickPatternSection(
        _ patterns: [TechnicalIndicators.CandlestickSignal]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("K 線型態（僅供參考）")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            ForEach(patterns) { pattern in
                let isBearish = pattern.direction == .bearish
                let isNeutral = pattern.direction == .neutral
                let color: Color = isNeutral
                    ? AppColor.primary
                    : (isBearish ? AppColor.softDown : AppColor.softUp)
                let icon = isNeutral
                    ? "minus.circle.fill"
                    : (isBearish ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                let dirLabel = isNeutral ? "中性" : (isBearish ? "偏空" : "偏多")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundStyle(color)
                        Text(pattern.pattern.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(color)
                        Spacer()
                        Text("可靠度: \(pattern.reliability.rawValue)")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("方向")
                                .font(.warmMicro())
                                .foregroundStyle(AppColor.textSecondary)
                            Text(dirLabel)
                                .font(.warmSecondaryData(.semibold))
                                .foregroundStyle(color)
                        }
                        HStack(spacing: 4) {
                            Text("位置")
                                .font(.warmMicro())
                                .foregroundStyle(AppColor.textSecondary)
                            Text(pattern.barsAgo == 0 ? "最新" : "\(pattern.barsAgo) 日前")
                                .font(.warmSecondaryData())
                                .foregroundStyle(AppColor.textMain)
                        }
                    }

                    Text(pattern.description)
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    // MARK: - 賣出建議卡片

    private func sellRecommendationSection(_ rec: TechnicalIndicators.SellRecommendation) -> some View {
        let level = rec.level
        let levelColor: Color = {
            switch level {
            case .strongSell: return AppColor.softDown
            case .considerSell: return .orange
            case .neutral: return AppColor.textSecondary
            case .holdBullish, .strongHold: return AppColor.softUp
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("賣出建議")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 分數與等級
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: level.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(levelColor)
                    Text(level.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(levelColor)
                    Spacer()
                    Text("\(rec.score)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(levelColor)
                    + Text(" / 100")
                        .font(.warmDataValue())
                        .foregroundStyle(AppColor.textSecondary)
                }

                // 進度條
                GeometryReader { geo in
                    let width = geo.size.width
                    let fillWidth = width * CGFloat(rec.score) / 100

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColor.divider)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(levelColor)
                            .frame(width: max(0, fillWidth), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(10)
            .background(levelColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))

            // 因子列表
            if !rec.factors.isEmpty {
                let columns = [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                    ForEach(rec.factors) { factor in
                        HStack(spacing: 4) {
                            Image(systemName: factor.isBearish ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(factor.isBearish ? AppColor.softDown : AppColor.softUp)
                            Text(factor.name)
                                .font(.warmTertiary())
                                .foregroundStyle(AppColor.textMain)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(factor.points > 0 ? "+\(factor.points)" : "\(factor.points)")
                                .font(.warmTertiary(.semibold))
                                .foregroundStyle(factor.isBearish ? AppColor.softDown : AppColor.softUp)
                        }
                    }
                }
            }

            // 免責聲明
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                Text("此建議僅供參考，不構成投資建議")
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary.opacity(0.6))
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    // MARK: - 操作建議信號

    private struct ActionSignalItem: Hashable {
        let text: String
        let icon: String
        let color: Color

        func hash(into hasher: inout Hasher) {
            hasher.combine(text)
        }
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.text == rhs.text
        }
    }

    private func buildActionSignals(_ signal: TechnicalIndicators.SignalSummary) -> [ActionSignalItem] {
        var items: [ActionSignalItem] = []

        // 加碼信號（偏多）
        if let maCross = signal.maCross, maCross == .goldenCross {
            items.append(ActionSignalItem(text: "均線金叉：短期均線上穿長期均線，趨勢轉多", icon: "arrow.up.circle.fill", color: AppColor.softUp))
        }
        if let macdSig = signal.macdSignal, macdSig == .goldenCross {
            items.append(ActionSignalItem(text: "MACD 金叉：DIF 上穿 DEA，動能轉強", icon: "arrow.up.circle.fill", color: AppColor.softUp))
        }
        if let kdjSig = signal.kdjSignal, kdjSig == .goldenCross {
            items.append(ActionSignalItem(text: "KD 金叉：短線動能回升，可留意加碼", icon: "arrow.up.circle.fill", color: AppColor.softUp))
        }
        if let rsiSig = signal.rsiSignal, rsiSig == .oversold {
            items.append(ActionSignalItem(text: "RSI 超賣：短線或已超跌，注意反彈機會", icon: "arrow.up.circle.fill", color: AppColor.softUp))
        }
        if let bbSig = signal.bollingerSignal, bbSig == .nearLower {
            items.append(ActionSignalItem(text: "觸及布林下軌：價格接近支撐帶，留意止跌反彈", icon: "arrow.up.circle.fill", color: AppColor.softUp))
        }

        // 壞出信號（偏空）
        if let maCross = signal.maCross, maCross == .deathCross {
            items.append(ActionSignalItem(text: "均線死叉：短期均線下穿長期均線，趨勢轉空", icon: "arrow.down.circle.fill", color: AppColor.softDown))
        }
        if let macdSig = signal.macdSignal, macdSig == .deathCross {
            items.append(ActionSignalItem(text: "MACD 死叉：DIF 下穿 DEA，動能轉弱", icon: "arrow.down.circle.fill", color: AppColor.softDown))
        }
        if let kdjSig = signal.kdjSignal, kdjSig == .deathCross {
            items.append(ActionSignalItem(text: "KD 死叉：短線動能轉弱，注意減碼", icon: "arrow.down.circle.fill", color: AppColor.softDown))
        }
        if let rsiSig = signal.rsiSignal, rsiSig == .overbought {
            items.append(ActionSignalItem(text: "RSI 超買：短線或已過熱，注意回檔風險", icon: "arrow.down.circle.fill", color: AppColor.softDown))
        }
        if let bbSig = signal.bollingerSignal, bbSig == .nearUpper {
            items.append(ActionSignalItem(text: "觸及布林上軌：價格接近壓力帶，留意回落", icon: "arrow.down.circle.fill", color: AppColor.softDown))
        }

        // 中性警示
        if let bbSig = signal.bollingerSignal, bbSig == .squeeze {
            items.append(ActionSignalItem(text: "布林帶收窄：波動率降低，可能即將變盤", icon: "exclamationmark.triangle.fill", color: AppColor.primary))
        }
        if let volSig = signal.volumeSignal {
            switch volSig {
            case .surge:
                items.append(ActionSignalItem(text: "成交量爆量：量能突增，需配合價格方向判斷", icon: "exclamationmark.triangle.fill", color: AppColor.softUp))
            case .high:
                items.append(ActionSignalItem(text: "成交量放大：量能高於平均，關注主力動向", icon: "exclamationmark.triangle.fill", color: AppColor.secondary))
            case .shrink:
                items.append(ActionSignalItem(text: "成交量萎縮：市場觀望，留意突破方向", icon: "exclamationmark.triangle.fill", color: AppColor.textSecondary))
            case .normal:
                break
            }
        }

        // 背離信號
        for div in signal.divergences {
            switch div.type {
            case .bearish:
                items.append(ActionSignalItem(
                    text: "\(div.indicator) 頂背離：價格創新高但\(div.indicator)未跟上，注意反轉風險",
                    icon: "arrow.down.circle.fill",
                    color: AppColor.softDown
                ))
            case .bullish:
                items.append(ActionSignalItem(
                    text: "\(div.indicator) 底背離：價格創新低但\(div.indicator)未跟下，留意反彈",
                    icon: "arrow.up.circle.fill",
                    color: AppColor.softUp
                ))
            }
        }

        // K 線型態
        for pattern in signal.candlestickPatterns {
            let icon: String
            let color: Color
            switch pattern.direction {
            case .bullish:
                icon = "arrow.up.circle.fill"
                color = AppColor.softUp
            case .bearish:
                icon = "arrow.down.circle.fill"
                color = AppColor.softDown
            case .neutral:
                icon = "exclamationmark.triangle.fill"
                color = AppColor.primary
            }
            items.append(ActionSignalItem(
                text: "\(pattern.pattern.rawValue)：\(pattern.description)",
                icon: icon,
                color: color
            ))
        }

        return items
    }

    // MARK: - 壓力/支撐價位

    /// 壓力/支撐項目
    private struct SRLevel: Identifiable {
        let id = UUID()
        let label: String       // "MA5", "布林上軌" 等
        let price: Double
        let isResistance: Bool  // true=壓力, false=支撐
    }

    private func supportResistanceSection(signal: TechnicalIndicators.SignalSummary, currentPrice: Double) -> some View {
        // 收集所有壓力/支撐價位
        var levels: [SRLevel] = []

        if let ma5 = signal.ma5Value {
            levels.append(SRLevel(label: "MA5", price: ma5, isResistance: ma5 > currentPrice))
        }
        if let ma20 = signal.ma20Value {
            levels.append(SRLevel(label: "MA20", price: ma20, isResistance: ma20 > currentPrice))
        }
        if let upper = signal.bollingerUpper {
            levels.append(SRLevel(label: "布林上軌", price: upper, isResistance: true))
        }
        if let middle = signal.bollingerMiddle {
            levels.append(SRLevel(label: "布林中軌", price: middle, isResistance: middle > currentPrice))
        }
        if let lower = signal.bollingerLower {
            levels.append(SRLevel(label: "布林下軌", price: lower, isResistance: false))
        }
        if let high20 = signal.recentHigh20 {
            levels.append(SRLevel(label: "近20日高", price: high20, isResistance: true))
        }
        if let low20 = signal.recentLow20 {
            levels.append(SRLevel(label: "近20日低", price: low20, isResistance: false))
        }
        if let stats = weekStats {
            if stats.high52w > 0 {
                levels.append(SRLevel(label: "52W高", price: stats.high52w, isResistance: true))
            }
            if stats.low52w > 0 {
                levels.append(SRLevel(label: "52W低", price: stats.low52w, isResistance: false))
            }
        }

        // 分為壓力（高於現價）和支撐（低於現價），依距離排序
        let resistanceLevels = levels
            .filter { $0.price > currentPrice }
            .sorted { $0.price < $1.price }  // 由近到遠
        let supportLevels = levels
            .filter { $0.price <= currentPrice }
            .sorted { $0.price > $1.price }  // 由近到遠

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.and.down.text.horizontal")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("壓力 / 支撐")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
            }

            // 目前價格
            HStack {
                Text("目前價格")
                    .font(.warmSecondaryData())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "%.2f", currentPrice))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.primary)
            }
            .padding(.bottom, 2)

            // 壓力區
            if !resistanceLevels.isEmpty {
                srGroupView(title: "壓力", levels: resistanceLevels, currentPrice: currentPrice, isResistance: true)
            }

            // 支撐區
            if !supportLevels.isEmpty {
                srGroupView(title: "支撐", levels: supportLevels, currentPrice: currentPrice, isResistance: false)
            }
        }
        .cardStyle()
    }

    private func srGroupView(title: String, levels: [SRLevel], currentPrice: Double, isResistance: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.warmTertiary(.semibold))
                .foregroundStyle(isResistance ? AppColor.softUp : AppColor.softDown)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((isResistance ? AppColor.softUp : AppColor.softDown).opacity(0.12))
                .clipShape(Capsule())

            ForEach(levels) { level in
                HStack(spacing: 0) {
                    Text(level.label)
                        .font(.warmSecondaryData())
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 70, alignment: .leading)
                    Spacer()
                    Text(String(format: "%.2f", level.price))
                        .font(.warmDataValue(.semibold))
                        .foregroundStyle(isResistance ? AppColor.softUp : AppColor.softDown)
                    let pct = (level.price - currentPrice) / currentPrice * 100
                    Text(String(format: "%+.1f%%", pct))
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 55, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - 目標 / 停損

    private func targetStopSection(currentPrice: Double, target jt: JournalTarget, avgCost: Double) -> some View {
        let tp = jt.targetPrice
        let sl = jt.stopLoss

        // 距離百分比
        let distToTarget: Double? = tp.map { ($0 - currentPrice) / currentPrice * 100 }
        let distToStop: Double? = sl.map { (currentPrice - $0) / currentPrice * 100 }

        // 風險報酬比（R:R）
        let riskReward: Double? = {
            guard let t = tp, let s = sl, t > currentPrice, currentPrice > s else { return nil }
            return (t - currentPrice) / (currentPrice - s)
        }()

        // 進度條位置（0 = 停損, 1 = 目標）
        let progressRatio: Double? = {
            guard let t = tp, let s = sl, t > s else { return nil }
            return min(max((currentPrice - s) / (t - s), 0), 1)
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("目標 / 停損")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Button { showingTargetStopEdit = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                        Text("編輯")
                            .font(.warmTertiary())
                    }
                    .foregroundStyle(AppColor.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColor.primary.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // 價格列
            HStack(spacing: 0) {
                if let sl {
                    VStack(spacing: 2) {
                        Text("停損價")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: "$%.1f", sl))
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.softDown)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 2) {
                    Text("現價")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", currentPrice))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textMain)
                }
                .frame(maxWidth: .infinity)

                if let tp {
                    VStack(spacing: 2) {
                        Text("目標價")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: "$%.1f", tp))
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.softUp)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 2) {
                    Text("均價")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", avgCost))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textMain)
                }
                .frame(maxWidth: .infinity)
            }

            // 進度條（只有同時有 target 和 stop 才顯示）
            if let ratio = progressRatio {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColor.divider)
                                .frame(height: 8)
                            // 填充
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [AppColor.softDown, .orange, AppColor.softUp],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * ratio, height: 8)
                            // 現價指標
                            Circle()
                                .fill(AppColor.textMain)
                                .frame(width: 12, height: 12)
                                .offset(x: geo.size.width * ratio - 6)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text("停損")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.softDown)
                        Spacer()
                        Text("目標")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.softUp)
                    }
                }
            }

            // 距離 & R:R
            HStack(spacing: 0) {
                if let d = distToTarget {
                    VStack(spacing: 2) {
                        Text("距目標")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: "%@%.1f%%", d >= 0 ? "+" : "", d))
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(d > 0 ? AppColor.softUp : AppColor.softDown)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let d = distToStop {
                    VStack(spacing: 2) {
                        Text("距停損")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: "%@%.1f%%", d >= 0 ? "+" : "", d))
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(d > 0 ? AppColor.textSecondary : AppColor.softDown)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let rr = riskReward {
                    VStack(spacing: 2) {
                        Text("風險報酬比")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: "1:%.1f", rr))
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(rr >= 2 ? AppColor.softUp : (rr >= 1 ? .orange : AppColor.softDown))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    // MARK: - 移動停利建議

    private func trailingStopSection(currentPrice: Double, highSinceBuy high: Double, avgCost: Double) -> some View {
        let fees = TradingFeeSettings.load()
        let pct = fees.trailingStopPct
        let rawStop = high * (1 - pct / 100)
        // 停利線不低於買入均價（保本下限）
        let stopPrice = max(rawStop, avgCost)
        let drawdownPct = (high - currentPrice) / high * 100
        let marginPct = (currentPrice - stopPrice) / stopPrice * 100

        // 狀態判斷
        let breached = currentPrice <= stopPrice
        let nearStop = !breached && currentPrice <= stopPrice * 1.03
        let statusColor: Color = breached ? AppColor.softDown : (nearStop ? .orange : AppColor.secondary)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "shield.checkered")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text(String(format: "移動停利（回撤 %.0f%%）", pct))
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 數據列
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("最高價")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", high))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textMain)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("停利線")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", stopPrice))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(statusColor)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("現價")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", currentPrice))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textMain)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("回撤")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "↓%.1f%%", drawdownPct))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(statusColor)
                }
                .frame(maxWidth: .infinity)
            }

            // 狀態訊息
            HStack(spacing: 6) {
                if breached {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.softDown)
                    Text(String(format: "現價已跌破停利線，建議停利出場"))
                        .font(.warmSecondaryData())
                        .foregroundStyle(AppColor.textMain)
                } else if nearStop {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text(String(format: "接近停利線（距 %.1f%%），密切留意", marginPct))
                        .font(.warmSecondaryData())
                        .foregroundStyle(AppColor.textMain)
                } else {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.secondary)
                    Text(String(format: "安全持有中，距停利線 %.1f%%", marginPct))
                        .font(.warmSecondaryData())
                        .foregroundStyle(AppColor.textMain)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous)
                    .fill(statusColor.opacity(0.10))
            )
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    // MARK: - 法人買賣超

    private func institutionalSection(_ data: StockService.InstitutionalSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("三大法人買賣超（張）")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 連續天數摘要
            HStack(spacing: 12) {
                streakBadge(label: "外資", streak: data.foreignStreak)
                streakBadge(label: "投信", streak: data.trustStreak)
                streakBadge(label: "合計", streak: data.totalStreak)
                Spacer()
            }

            // 累計淨買超摘要
            if data.days.count > 1 {
                HStack(spacing: 8) {
                    cumulativeLabel("外資", value: data.foreignCumulativeNet)
                    cumulativeLabel("投信", value: data.trustCumulativeNet)
                    cumulativeLabel("合計", value: data.totalCumulativeNet)
                    Spacer()
                }
            }

            // 最近 N 日表格
            VStack(spacing: 0) {
                // 表頭
                HStack(spacing: 0) {
                    Text("日期")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("外資")
                        .frame(maxWidth: .infinity)
                    Text("投信")
                        .frame(maxWidth: .infinity)
                    Text("自營")
                        .frame(maxWidth: .infinity)
                    Text("合計")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.warmMicro(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.vertical, 4)

                AppColor.divider.frame(height: 1)

                // 資料列
                ForEach(Array(data.days.enumerated()), id: \.offset) { _, day in
                    HStack(spacing: 0) {
                        Text(formatShortDate(day.date))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(AppColor.textSecondary)
                        netText(day.foreignNet)
                            .frame(maxWidth: .infinity)
                        netText(day.trustNet)
                            .frame(maxWidth: .infinity)
                        netText(day.dealerNet)
                            .frame(maxWidth: .infinity)
                        netText(day.totalNet)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.warmMicro())
                    .padding(.vertical, 3)
                }
            }
            .padding(8)
            .background(AppColor.background.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    private func streakBadge(label: String, streak: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            if abs(streak) >= 2 {
                Text("連\(streak > 0 ? "買" : "賣")\(abs(streak))日")
                    .font(.warmMicro(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((streak > 0 ? AppColor.softUp : AppColor.softDown).opacity(0.15))
                    .foregroundStyle(streak > 0 ? AppColor.softUp : AppColor.softDown)
                    .clipShape(Capsule())
            } else if streak != 0 {
                Text(streak > 0 ? "買超" : "賣超")
                    .font(.warmMicro())
                    .foregroundStyle(streak > 0 ? AppColor.softUp : AppColor.softDown)
            } else {
                Text("—")
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            }
        }
    }

    /// 法人累計淨買超標籤
    private func cumulativeLabel(_ label: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text("\(value > 0 ? "+" : "")\(value)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.profitLossColor(Double(value)))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(AppColor.cardBackground)
        .clipShape(Capsule())
    }

    private func netText(_ value: Int) -> Text {
        Text("\(value >= 0 ? "+" : "")\(value)")
            .foregroundColor(Color.profitLossColor(Double(value)))
    }

    private func formatShortDate(_ dateStr: String) -> String {
        // "yyyyMMdd" → "MM/dd"
        guard dateStr.count == 8 else { return dateStr }
        let mm = dateStr[dateStr.index(dateStr.startIndex, offsetBy: 4)..<dateStr.index(dateStr.startIndex, offsetBy: 6)]
        let dd = dateStr[dateStr.index(dateStr.startIndex, offsetBy: 6)..<dateStr.endIndex]
        return "\(mm)/\(dd)"
    }

    // MARK: - 融資融券卡片

    private func marginTradingSection(_ data: StockService.MarginTradingSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題
            HStack(spacing: 4) {
                Image(systemName: "banknote")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("融資融券")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 餘額摘要
            HStack(spacing: 12) {
                marginBalanceLabel("融資餘額", value: data.latestMarginBalance)
                marginBalanceLabel("融券餘額", value: data.latestShortBalance)
                if data.latestMarginBalance > 0 {
                    let ratio = Double(data.latestShortBalance) / Double(data.latestMarginBalance) * 100
                    marginBalanceLabel("券資比", text: String(format: "%.1f%%", ratio))
                }
                Spacer()
            }

            // 連續增減趨勢
            HStack(spacing: 12) {
                marginStreakBadge(label: "融資", streak: data.marginStreak)
                marginStreakBadge(label: "融券", streak: data.shortStreak)
                Spacer()
            }

            // 累計增減
            if data.days.count > 1 {
                HStack(spacing: 8) {
                    cumulativeLabel("融資增減", value: data.marginBuyTotalChange)
                    cumulativeLabel("融券增減", value: data.shortSellTotalChange)
                    Spacer()
                }
            }

            // 最近 N 日表格
            VStack(spacing: 0) {
                // 表頭
                HStack(spacing: 0) {
                    Text("日期")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("融資餘額")
                        .frame(maxWidth: .infinity)
                    Text("融資增減")
                        .frame(maxWidth: .infinity)
                    Text("融券餘額")
                        .frame(maxWidth: .infinity)
                    Text("融券增減")
                        .frame(maxWidth: .infinity)
                    Text("互抵")
                        .frame(width: 40)
                }
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.bottom, 4)

                Divider()

                ForEach(data.days, id: \.date) { day in
                    HStack(spacing: 0) {
                        Text(formatShortDate(day.date))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatCompact(day.marginBuyBalance))
                            .frame(maxWidth: .infinity)
                        marginChangeText(day.marginBuyChange)
                            .frame(maxWidth: .infinity)
                        Text(formatCompact(day.shortSellBalance))
                            .frame(maxWidth: .infinity)
                        marginChangeText(day.shortSellChange)
                            .frame(maxWidth: .infinity)
                        Text("\(day.dayTradeOffset)")
                            .frame(width: 40)
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColor.textMain)
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    /// 融資融券餘額標籤
    private func marginBalanceLabel(_ label: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text(formatCompact(value))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColor.textMain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(AppColor.cardBackground)
        .clipShape(Capsule())
    }

    /// 融資融券餘額標籤（文字版）
    private func marginBalanceLabel(_ label: String, text: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColor.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(AppColor.cardBackground)
        .clipShape(Capsule())
    }

    /// 融資融券連續增減 badge
    private func marginStreakBadge(label: String, streak: Int) -> some View {
        Group {
            if abs(streak) >= 2 {
                let isIncrease = streak > 0
                let text = isIncrease ? "\(label)連增\(streak)日" : "\(label)連減\(abs(streak))日"
                // 融資增=散戶追多(偏空)，融資減=賣壓釋放(偏多)
                // 融券增=軋空潛力(偏多)，融券減=回補完畢(偏空)
                let isBullish = (label == "融資" && !isIncrease) || (label == "融券" && isIncrease)
                let color: Color = isBullish ? AppColor.softUp : AppColor.softDown
                Text(text)
                    .font(.warmMicro(.semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Text("—")
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            }
        }
    }

    /// 融資融券增減文字（帶正負號與顏色）
    private func marginChangeText(_ value: Int) -> Text {
        Text("\(value >= 0 ? "+" : "")\(value)")
            .foregroundColor(Color.profitLossColor(Double(value)))
    }

    /// 數字格式化（大數字簡寫）
    private func formatCompact(_ value: Int) -> String {
        if abs(value) >= 10000 {
            return String(format: "%.1f萬", Double(value) / 10000.0)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - 52 週區間

    private func weekStatsSection(_ stats: WeekStats) -> some View {
        let range = stats.high52w - stats.low52w

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("52 週區間")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 現價位置
            if let price = currentPrice {
                let pct = min(1, max(0, (price - stats.low52w) / range))
                rangeBar(
                    label: "現價",
                    value: price,
                    percentile: pct,
                    low: stats.low52w,
                    high: stats.high52w
                )
            }

            // 買入均價位置
            let avgPct = min(1, max(0, (group.weightedAverageCost - stats.low52w) / range))
            rangeBar(
                label: "均價",
                value: group.weightedAverageCost,
                percentile: avgPct,
                low: stats.low52w,
                high: stats.high52w
            )
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    // MARK: - Helpers

    private func rangeBar(
        label: String,
        value: Double,
        percentile: Double,
        low: Double,
        high: Double
    ) -> some View {
        let barColor: Color = {
            if percentile > 0.7 { return AppColor.softUp }
            if percentile < 0.3 { return AppColor.softDown }
            return AppColor.primary
        }()

        return VStack(spacing: 4) {
            HStack {
                Text(String(format: "低 $%.1f", low))
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "%@ $%.2f (%d%%)", label, value, Int(percentile * 100)))
                    .font(.warmMicro(.semibold))
                    .foregroundStyle(barColor)
                Spacer()
                Text(String(format: "$%.1f 高", high))
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary)
            }

            GeometryReader { geo in
                let trackWidth = geo.size.width
                let dotX = trackWidth * percentile

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColor.divider)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(0.5))
                        .frame(width: max(0, dotX), height: 4)

                    Circle()
                        .fill(barColor)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: max(0, min(dotX - 4, trackWidth - 8)))
                }
            }
            .frame(height: 8)
        }
    }

    private func signalPill(_ text: String, color: Color, filled: Bool = false) -> some View {
        Text(text)
            .font(.warmMicro())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(filled ? color : color.opacity(0.12))
            .foregroundStyle(filled ? .white : color)
            .clipShape(Capsule())
    }
}
// MARK: - 目標 / 停損編輯 Sheet（分析頁面用）

private struct TargetStopEditSheetInDetail: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let ticker: String
    let journal: TradeJournal?
    let investment: Investment?

    @State private var targetPriceText: String = ""
    @State private var stopLossText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(StockMapping.displayName(for: ticker))
                                .font(.warmTitle())
                                .foregroundStyle(AppColor.textMain)
                            Text(ticker)
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        Spacer()
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.softUp)
                            Text("目標價")
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        TextField("未設定", text: $targetPriceText)
                            .keyboardType(.decimalPad)
                            .font(.warmBody())
                            .padding(10)
                            .background(AppColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.slash")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.softDown)
                            Text("初始停損價")
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        TextField("未設定", text: $stopLossText)
                            .keyboardType(.decimalPad)
                            .font(.warmBody())
                            .padding(10)
                            .background(AppColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
                    }
                    .cardStyle()

                    Spacer()

                    Button { save() } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("儲存")
                        }
                        .font(.warmHeadline())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
                    }
                }
                .padding(16)
            }
            .navigationTitle("編輯目標 / 停損")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        if let j = journal {
            if let t = j.targetPrice { targetPriceText = String(format: "%.2f", t) }
            if let s = j.initialStopLoss { stopLossText = String(format: "%.2f", s) }
        }
    }

    private func save() {
        let target = Double(targetPriceText)
        let stopLoss = Double(stopLossText)

        if let journal {
            journal.targetPrice = target
            journal.initialStopLoss = stopLoss
        } else if let investment {
            let journal = TradeJournal(
                investmentID: investment.id,
                initialStopLoss: stopLoss,
                targetPrice: target
            )
            modelContext.insert(journal)
        }
        dismiss()
    }
}

