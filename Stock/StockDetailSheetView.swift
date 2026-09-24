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
    @State private var selectedDetailTab = 0

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

                VStack(spacing: 0) {
                    // 分頁切換列
                    detailTabBar

                    ScrollView {
                        VStack(spacing: 14) {
                            switch selectedDetailTab {
                            case 0: // K 線
                                klineSection

                            case 1: // 指標
                                if let signal {
                                    technicalSignalSection(signal)
                                    indicatorDashboard(signal)
                                }

                                if let signal, !signal.divergences.isEmpty {
                                    divergenceSection(signal.divergences)
                                }

                                if let signal, !signal.candlestickPatterns.isEmpty {
                                    candlestickPatternSection(signal.candlestickPatterns)
                                }

                                if !maDeductions.isEmpty {
                                    maDeductionSection
                                }

                                if let stats = weekStats,
                                   stats.high52w > stats.low52w {
                                    weekStatsSection(stats)
                                }

                                if TradingFeeSettings.load().supportResistanceEnabled,
                                   let signal, let price = currentPrice {
                                    supportResistanceSection(signal: signal, currentPrice: price)
                                }

                            case 2: // 市場
                                if let inst = institutionalData {
                                    institutionalSection(inst)
                                }

                                if let margin = marginData {
                                    marginTradingSection(margin)
                                }

                                buyScoreSummary

                                if institutionalData == nil && marginData == nil {
                                    noDataPlaceholder("暫無市場資訊")
                                }

                            case 3: // 分析
                                // 持倉損益摘要
                                if let price = currentPrice {
                                    positionSummaryCard(currentPrice: price)
                                }

                                // 交易日誌摘要 + R 倍數預估
                                journalSummaryCard

                                if let rec = sellRecommendation {
                                    sellRecommendationSection(rec)
                                }

                                if let price = currentPrice,
                                   let jt = liveJournalTarget,
                                   (jt.targetPrice != nil || jt.stopLoss != nil) {
                                    targetStopSection(currentPrice: price, target: jt, avgCost: group.weightedAverageCost)
                                } else {
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

                                if let price = currentPrice, let high = highSinceBuy, high > 0 {
                                    trailingStopSection(currentPrice: price, highSinceBuy: high, avgCost: group.weightedAverageCost)
                                }

                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
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

    // MARK: - 分頁切換列

    private var detailTabBar: some View {
        let tabs = ["K線", "指標", "市場", "分析"]
        return HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDetailTab = index
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(selectedDetailTab == index ? AppColor.primary : AppColor.textSecondary)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(selectedDetailTab == index ? AppColor.primary : .clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(AppColor.background)
    }

    // MARK: - 無資料佔位

    private func noDataPlaceholder(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            Text(message)
                .font(.warmBody())
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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

                Spacer()

                // 市場體質 regime pill
                let regimeColor: Color = {
                    switch signal.regime {
                    case .bullish:  return AppColor.softUp
                    case .bearish:  return AppColor.softDown
                    case .sideways: return AppColor.secondary
                    }
                }()
                let regimeIcon: String = {
                    switch signal.regime {
                    case .bullish:  return "arrow.up.right"
                    case .bearish:  return "arrow.down.right"
                    case .sideways: return "arrow.left.arrow.right"
                    }
                }()
                HStack(spacing: 3) {
                    Image(systemName: regimeIcon)
                        .font(.system(size: 8, weight: .bold))
                    Text(signal.regime.label)
                        .font(.warmMicro(.semibold))
                }
                .foregroundStyle(regimeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(regimeColor.opacity(0.12))
                .clipShape(Capsule())
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

    // MARK: - 指標數值儀表板

    private func indicatorDashboard(_ signal: TechnicalIndicators.SignalSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("指標數值")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 2-column grid
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 6) {
                if let rsi = signal.rsi {
                    indicatorCell(
                        "RSI",
                        value: String(format: "%.1f", rsi),
                        color: rsi > 80 ? AppColor.softDown : (rsi < 20 ? AppColor.softUp : AppColor.textMain),
                        gauge: rsi / 100
                    )
                }
                if let k = signal.kdjK, let d = signal.kdjD {
                    indicatorCell(
                        "KDJ",
                        value: "K\(String(format: "%.0f", k)) D\(String(format: "%.0f", d))",
                        color: k > 80 ? AppColor.softDown : (k < 20 ? AppColor.softUp : AppColor.textMain),
                        gauge: k / 100
                    )
                }
                if let dif = signal.macdDIF, let dea = signal.macdDEA {
                    indicatorCell(
                        "MACD",
                        value: "DIF \(String(format: "%.2f", dif))",
                        subtitle: "DEA \(String(format: "%.2f", dea))",
                        color: dif >= dea ? AppColor.softUp : AppColor.softDown
                    )
                }
                if let upper = signal.bollingerUpper,
                   let mid = signal.bollingerMiddle,
                   let lower = signal.bollingerLower {
                    indicatorCell(
                        "布林",
                        value: String(format: "%.1f", mid),
                        subtitle: "\(String(format: "%.0f", lower))–\(String(format: "%.0f", upper))",
                        color: AppColor.textMain
                    )
                }
                if let ma5 = signal.ma5Value, let ma20 = signal.ma20Value {
                    indicatorCell(
                        "均線",
                        value: "MA5 \(String(format: "%.1f", ma5))",
                        subtitle: "MA20 \(String(format: "%.1f", ma20))",
                        color: ma5 >= ma20 ? AppColor.softUp : AppColor.softDown
                    )
                }
                if let ratio = signal.volumeRatio {
                    indicatorCell(
                        "量比",
                        value: String(format: "%.2fx", ratio),
                        color: ratio > 1.5 ? AppColor.softUp : (ratio < 0.5 ? AppColor.softDown : AppColor.textMain),
                        gauge: min(ratio / 3.0, 1.0)
                    )
                }
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    /// 指標數值格子
    private func indicatorCell(
        _ title: String,
        value: String,
        subtitle: String? = nil,
        color: Color,
        gauge: Double? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmDataValue(.semibold))
                .foregroundStyle(color)
            if let subtitle {
                Text(subtitle)
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary)
            }
            if let gauge {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColor.background)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.7))
                            .frame(width: geo.size.width * gauge, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
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
                    VStack(spacing: 3) {
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

                        // 翻轉日提示
                        if let flip = d.flipDay, flip > 0, flip <= 5 {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 7))
                                Text("預計 \(flip) 日後趨勢翻轉")
                                    .font(.warmMicro())
                            }
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
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

    // MARK: - 持倉損益摘要

    private func positionSummaryCard(currentPrice: Double) -> some View {
        let pl = group.unrealizedProfitLoss(currentPrice: currentPrice)
        let retPct = group.returnPercentage(currentPrice: currentPrice)
        let avgCost = group.weightedAverageCost
        let totalCost = avgCost * group.totalQuantity
        let days = group.holdingDays
        let isProfit = pl >= 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "chart.pie")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("持倉摘要")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 主要損益
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%@%,.0f", isProfit ? "+" : "", pl))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.profitLossColor(pl))

                Text(String(format: "(%@%.1f%%)", retPct >= 0 ? "+" : "", retPct))
                    .font(.warmDataValue(.semibold))
                    .foregroundStyle(Color.profitLossColor(retPct))

                Spacer()
            }

            // 明細 grid
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 6) {
                positionMetric("現價", value: String(format: "%.2f", currentPrice))
                positionMetric("均價", value: String(format: "%.2f", avgCost))
                positionMetric("持有天", value: "\(days)")
                positionMetric("張數", value: String(format: "%.0f", group.totalQuantity))
                positionMetric("總成本", value: formatCurrency(totalCost))
                positionMetric("市值", value: formatCurrency(currentPrice * group.totalQuantity))
            }
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .cardShadow()
    }

    private func positionMetric(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmDataValue(.semibold))
                .foregroundStyle(AppColor.textMain)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCurrency(_ value: Double) -> String {
        if abs(value) >= 100_000_000 {
            return String(format: "%.1f億", value / 100_000_000)
        } else if abs(value) >= 10_000 {
            return String(format: "%.1f萬", value / 10_000)
        } else {
            return String(format: "%.0f", value)
        }
    }

    // MARK: - 交易日誌摘要 + R 倍數預估

    private var journalSummaryCard: some View {
        let journal = latestJournalForTicker()

        return Group {
            if let j = journal, (j.hasPlan || j.emotionScore != nil) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.primary)
                        Text("交易日誌")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    // 進場理由
                    if !j.setup.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("進場理由")
                                .font(.warmMicro(.semibold))
                                .foregroundStyle(AppColor.textSecondary)
                            Text(j.setup)
                                .font(.warmSecondaryData())
                                .foregroundStyle(AppColor.textMain)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.background.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
                    }

                    // 方向 + 情緒分數
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: j.direction == "做多" ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(j.direction)
                                .font(.warmSecondaryData(.semibold))
                        }
                        .foregroundStyle(j.direction == "做多" ? AppColor.softUp : AppColor.softDown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((j.direction == "做多" ? AppColor.softUp : AppColor.softDown).opacity(0.1))
                        .clipShape(Capsule())

                        if let emo = j.emotionScore {
                            HStack(spacing: 3) {
                                Text(emotionIcon(emo))
                                    .font(.system(size: 11))
                                Text("情緒 \(emo)/5")
                                    .font(.warmSecondaryData())
                                    .foregroundStyle(AppColor.textMain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColor.background.opacity(0.5))
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    // R 倍數預估
                    if let stopLoss = j.initialStopLoss, let price = currentPrice,
                       stopLoss > 0 {
                        let entryPrice = group.weightedAverageCost
                        let risk = abs(entryPrice - stopLoss)
                        if risk > 0 {
                            let currentR = (price - entryPrice) / risk
                            AppColor.divider.frame(height: 0.5)

                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("目前 R 倍數")
                                        .font(.warmMicro())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text(String(format: "%@%.2fR", currentR >= 0 ? "+" : "", currentR))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.profitLossColor(currentR))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("初始停損")
                                        .font(.warmMicro())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text(String(format: "%.1f", stopLoss))
                                        .font(.warmSecondaryData(.semibold))
                                        .foregroundStyle(AppColor.softDown)
                                }

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("風險 (1R)")
                                        .font(.warmMicro())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text(String(format: "%.1f", risk))
                                        .font(.warmSecondaryData(.semibold))
                                        .foregroundStyle(AppColor.textMain)
                                }
                            }
                            .padding(8)
                            .background(Color.profitLossColor(currentR).opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))

                            HStack(spacing: 4) {
                                Image(systemName: "lightbulb.min")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                                Text(rMultipleInterpretation(currentR))
                                    .font(.warmMicro())
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(AppColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
                .cardShadow()
            }
        }
    }

    private func emotionIcon(_ score: Int) -> String {
        switch score {
        case 1: return "😰"
        case 2: return "😟"
        case 3: return "😐"
        case 4: return "😊"
        case 5: return "🤩"
        default: return "😐"
        }
    }

    private func rMultipleInterpretation(_ r: Double) -> String {
        if r >= 3.0 {
            return "獲利達 \(String(format: "%.1f", r))R，可考慮分批停利保護利潤"
        } else if r >= 2.0 {
            return "獲利達 \(String(format: "%.1f", r))R，已達優質交易水準"
        } else if r >= 1.0 {
            return "獲利達 \(String(format: "%.1f", r))R，可移動停損至損益兩平"
        } else if r >= 0 {
            return "目前獲利 \(String(format: "%.1f", r))R，尚未達 1R 報酬"
        } else if r >= -0.5 {
            return "目前虧損 \(String(format: "%.1f", abs(r)))R，仍在可控範圍"
        } else {
            return "目前虧損 \(String(format: "%.1f", abs(r)))R，注意停損紀律"
        }
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

            // 因子列表（分偏空 / 偏多兩組）
            if !rec.factors.isEmpty {
                let bearish = rec.factors.filter(\.isBearish)
                let bullish = rec.factors.filter { !$0.isBearish }

                if !bearish.isEmpty {
                    sellFactorGroup(title: "賣出信號", factors: bearish, isBearish: true)
                }
                if !bullish.isEmpty {
                    sellFactorGroup(title: "持有信號", factors: bullish, isBearish: false)
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

    private func sellFactorGroup(title: String, factors: [TechnicalIndicators.SellFactor], isBearish: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: isBearish ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isBearish ? AppColor.softDown : AppColor.softUp)
                Text(title)
                    .font(.warmMicro(.semibold))
                    .foregroundStyle(isBearish ? AppColor.softDown : AppColor.softUp)
                Text("(\(factors.count))")
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary)
            }

            let columns = [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 3) {
                ForEach(factors) { factor in
                    HStack(spacing: 3) {
                        Text(factor.name)
                            .font(.warmTertiary())
                            .foregroundStyle(AppColor.textMain)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(factor.points > 0 ? "+\(factor.points)" : "\(factor.points)")
                            .font(.warmTertiary(.semibold))
                            .foregroundStyle(isBearish ? AppColor.softDown : AppColor.softUp)
                    }
                }
            }
        }
        .padding(8)
        .background((isBearish ? AppColor.softDown : AppColor.softUp).opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
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

            // 迷你趨勢圖
            if data.days.count >= 2 {
                institutionalMiniChart(data)
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

            // 迷你趨勢圖
            if data.days.count >= 2 {
                marginMiniChart(data)
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

    // MARK: - 法人迷你趨勢圖

    private func institutionalMiniChart(_ data: StockService.InstitutionalSummary) -> some View {
        let days = Array(data.days.prefix(5).reversed()) // 由舊到新
        let allValues = days.flatMap { [abs($0.foreignNet), abs($0.trustNet)] }
        let maxVal = Double(allValues.max() ?? 1)

        return VStack(alignment: .leading, spacing: 4) {
            // 圖例
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Circle().fill(AppColor.primary).frame(width: 6, height: 6)
                    Text("外資").font(.warmMicro()).foregroundStyle(AppColor.textSecondary)
                }
                HStack(spacing: 3) {
                    Circle().fill(AppColor.secondary).frame(width: 6, height: 6)
                    Text("投信").font(.warmMicro()).foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
            }

            // 長條圖
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 2) {
                        HStack(alignment: .bottom, spacing: 1) {
                            miniBar(value: day.foreignNet, maxVal: maxVal, color: AppColor.primary)
                            miniBar(value: day.trustNet, maxVal: maxVal, color: AppColor.secondary)
                        }
                        Text(formatShortDate(day.date))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 50)
        }
        .padding(8)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
    }

    /// 迷你長條（正=往上、負=往下，以零線為中心）
    private func miniBar(value: Int, maxVal: Double, color: Color) -> some View {
        let ratio = maxVal > 0 ? abs(Double(value)) / maxVal : 0
        let barHeight = max(ratio * 20, 1)
        return VStack(spacing: 0) {
            if value >= 0 {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 8, height: barHeight)
                Rectangle().fill(AppColor.divider).frame(height: 0.5)
                Spacer(minLength: 0).frame(height: 20)
            } else {
                Spacer(minLength: 0).frame(height: 20)
                Rectangle().fill(AppColor.divider).frame(height: 0.5)
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(0.5))
                    .frame(width: 8, height: barHeight)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 融資融券迷你趨勢圖

    private func marginMiniChart(_ data: StockService.MarginTradingSummary) -> some View {
        let days = Array(data.days.prefix(5).reversed()) // 由舊到新
        let allChanges = days.flatMap { [abs($0.marginBuyChange), abs($0.shortSellChange)] }
        let maxVal = Double(allChanges.max() ?? 1)

        return VStack(alignment: .leading, spacing: 4) {
            // 圖例
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Circle().fill(AppColor.softDown).frame(width: 6, height: 6)
                    Text("融資增減").font(.warmMicro()).foregroundStyle(AppColor.textSecondary)
                }
                HStack(spacing: 3) {
                    Circle().fill(AppColor.softUp).frame(width: 6, height: 6)
                    Text("融券增減").font(.warmMicro()).foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
            }

            // 長條圖
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 2) {
                        HStack(alignment: .bottom, spacing: 1) {
                            miniBar(value: day.marginBuyChange, maxVal: maxVal, color: AppColor.softDown)
                            miniBar(value: day.shortSellChange, maxVal: maxVal, color: AppColor.softUp)
                        }
                        Text(formatShortDate(day.date))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 50)
        }
        .padding(8)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
    }

    // MARK: - 買入評分摘要

    private var buyScoreSummary: some View {
        let score: TechnicalIndicators.BuyRecommendation? = {
            guard let sig = signal, let price = currentPrice else { return nil }
            return TechnicalIndicators.computeBuyRecommendation(
                signal: sig,
                week52High: weekStats?.high52w,
                week52Low: weekStats?.low52w,
                currentPrice: price,
                foreignStreak: institutionalData?.foreignStreak,
                trustStreak: institutionalData?.trustStreak,
                foreignCumulativeNet: institutionalData?.foreignCumulativeNet,
                trustCumulativeNet: institutionalData?.trustCumulativeNet,
                marginTotalChange: marginData?.marginBuyTotalChange,
                shortTotalChange: marginData?.shortSellTotalChange,
                regime: sig.regime
            )
        }()

        return Group {
            if let rec = score {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.primary)
                        Text("綜合買入評分")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    // 分數與等級
                    HStack(spacing: 12) {
                        // 環形分數
                        ZStack {
                            Circle()
                                .stroke(AppColor.background, lineWidth: 4)
                                .frame(width: 52, height: 52)
                            Circle()
                                .trim(from: 0, to: Double(rec.score) / 100.0)
                                .stroke(buyScoreColor(rec.level), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 52, height: 52)
                                .rotationEffect(.degrees(-90))
                            Text("\(rec.score)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(buyScoreColor(rec.level))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: rec.level.icon)
                                    .font(.system(size: 12))
                                Text(rec.level.shortLabel)
                                    .font(.warmDataValue(.semibold))
                            }
                            .foregroundStyle(buyScoreColor(rec.level))

                            Text(rec.level.label)
                                .font(.warmMicro())
                                .foregroundStyle(AppColor.textSecondary)
                        }

                        Spacer()
                    }

                    // 因子列表
                    if !rec.factors.isEmpty {
                        AppColor.divider.frame(height: 0.5)
                        let bullish = rec.factors.filter(\.isBullish)
                        let bearish = rec.factors.filter { !$0.isBullish }

                        if !bullish.isEmpty {
                            buyFactorRow(factors: bullish, isBullish: true)
                        }
                        if !bearish.isEmpty {
                            buyFactorRow(factors: bearish, isBullish: false)
                        }
                    }
                }
                .padding(12)
                .background(AppColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
                .cardShadow()
            }
        }
    }

    private func buyFactorRow(factors: [TechnicalIndicators.BuyFactor], isBullish: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: isBullish ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isBullish ? AppColor.softUp : AppColor.softDown)
                Text(isBullish ? "偏多因子" : "偏空因子")
                    .font(.warmMicro(.semibold))
                    .foregroundStyle(isBullish ? AppColor.softUp : AppColor.softDown)
            }

            let columns = [GridItem(.adaptive(minimum: 80), spacing: 4)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(factors) { f in
                    Text("\(f.name) \(f.points > 0 ? "+" : "")\(f.points)")
                        .font(.warmMicro())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isBullish ? AppColor.softUp : AppColor.softDown).opacity(0.1))
                        .foregroundStyle(isBullish ? AppColor.softUp : AppColor.softDown)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func buyScoreColor(_ level: TechnicalIndicators.BuyLevel) -> Color {
        switch level {
        case .strongBuy:   return AppColor.softUp
        case .considerBuy: return AppColor.softUp.opacity(0.7)
        case .neutral:     return AppColor.secondary
        case .cautious:    return AppColor.softDown.opacity(0.7)
        case .avoidBuy:    return AppColor.softDown
        }
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

