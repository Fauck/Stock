//
//  StockDetailSheetView.swift
//  Stock
//
//  個股分析滿版頁面：K 線走勢 + 技術指標 + 52 週區間
//

import SwiftUI

struct StockDetailSheetView: View {
    let group: PortfolioGroup
    let signal: TechnicalIndicators.SignalSummary?
    let weekStats: PortfolioListViewModel.WeekStats?
    let currentPrice: Double?
    let displayName: String
    let highSinceBuy: Double?
    let institutionalData: StockService.InstitutionalSummary?

    @Environment(\.dismiss) private var dismiss
    @State private var chartVM: KLineChartViewModel

    init(
        group: PortfolioGroup,
        signal: TechnicalIndicators.SignalSummary?,
        weekStats: PortfolioListViewModel.WeekStats?,
        currentPrice: Double?,
        displayName: String,
        highSinceBuy: Double? = nil,
        institutionalData: StockService.InstitutionalSummary? = nil
    ) {
        self.group = group
        self.signal = signal
        self.weekStats = weekStats
        self.currentPrice = currentPrice
        self.displayName = displayName
        self.highSinceBuy = highSinceBuy
        self.institutionalData = institutionalData
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

                        // 移動停利建議
                        if let price = currentPrice, let high = highSinceBuy, high > 0 {
                            trailingStopSection(currentPrice: price, highSinceBuy: high, avgCost: group.weightedAverageCost)
                        }

                        // 法人買賣超
                        if let inst = institutionalData {
                            institutionalSection(inst)
                        }

                        // 52 週區間
                        if let stats = weekStats,
                           stats.high52w > stats.low52w {
                            weekStatsSection(stats)
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
        }
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColor.textMain)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.background.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // 均線 & 交叉
            signalRow(title: "均線") {
                if let ma5 = signal.ma5Position {
                    signalPill(
                        ma5 == .above ? "MA5↑" : "MA5↓",
                        color: ma5 == .above ? AppColor.secondary : AppColor.softDown
                    )
                }
                if let ma20 = signal.ma20Position {
                    signalPill(
                        ma20 == .above ? "MA20↑" : "MA20↓",
                        color: ma20 == .above ? AppColor.secondary : AppColor.softDown
                    )
                }
                if let maCross = signal.maCross {
                    signalPill(
                        maCross.label,
                        color: maCross == .goldenCross ? AppColor.secondary : AppColor.softDown,
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
                    signalPill(label, color: kdjSig == .goldenCross ? AppColor.secondary : AppColor.softDown, filled: true)
                }
            }

            // MACD
            signalRow(title: "MACD") {
                if let dif = signal.macdDIF, let dea = signal.macdDEA {
                    signalPill(
                        "DIF \(String(format: "%.2f", dif))",
                        color: dif >= 0 ? AppColor.secondary : AppColor.softDown
                    )
                    signalPill(
                        "DEA \(String(format: "%.2f", dea))",
                        color: dea >= 0 ? AppColor.secondary : AppColor.softDown
                    )
                }
                if let macdSig = signal.macdSignal, let label = macdSig.label {
                    signalPill(label, color: macdSig == .goldenCross ? AppColor.secondary : AppColor.softDown, filled: true)
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    /// 指標分類行
    private func signalRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 32, alignment: .leading)
            content()
        }
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
            items.append(ActionSignalItem(text: "均線金叉：短期均線上穿長期均線，趨勢轉多", icon: "arrow.up.circle.fill", color: AppColor.secondary))
        }
        if let macdSig = signal.macdSignal, macdSig == .goldenCross {
            items.append(ActionSignalItem(text: "MACD 金叉：DIF 上穿 DEA，動能轉強", icon: "arrow.up.circle.fill", color: AppColor.secondary))
        }
        if let kdjSig = signal.kdjSignal, kdjSig == .goldenCross {
            items.append(ActionSignalItem(text: "KD 金叉：短線動能回升，可留意加碼", icon: "arrow.up.circle.fill", color: AppColor.secondary))
        }
        if let rsiSig = signal.rsiSignal, rsiSig == .oversold {
            items.append(ActionSignalItem(text: "RSI 超賣：短線或已超跌，注意反彈機會", icon: "arrow.up.circle.fill", color: AppColor.secondary))
        }
        if let bbSig = signal.bollingerSignal, bbSig == .nearLower {
            items.append(ActionSignalItem(text: "觸及布林下軌：價格接近支撐帶，留意止跌反彈", icon: "arrow.up.circle.fill", color: AppColor.secondary))
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

        return items
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
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", high))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textMain)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("停利線")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", stopPrice))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(statusColor)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("現價")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "$%.1f", currentPrice))
                        .font(.warmCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textMain)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("回撤")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
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
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textMain)
                } else if nearStop {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text(String(format: "接近停利線（距 %.1f%%），密切留意", marginPct))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textMain)
                } else {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.secondary)
                    Text(String(format: "安全持有中，距停利線 %.1f%%", marginPct))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textMain)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(statusColor.opacity(0.10))
            )
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
                .font(.system(size: 9, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .padding(.vertical, 3)
                }
            }
            .padding(8)
            .background(AppColor.background.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func streakBadge(label: String, streak: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
            if abs(streak) >= 2 {
                Text("連\(streak > 0 ? "買" : "賣")\(abs(streak))日")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((streak > 0 ? AppColor.secondary : AppColor.softDown).opacity(0.15))
                    .foregroundStyle(streak > 0 ? AppColor.secondary : AppColor.softDown)
                    .clipShape(Capsule())
            } else if streak != 0 {
                Text(streak > 0 ? "買超" : "賣超")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(streak > 0 ? AppColor.secondary : AppColor.softDown)
            } else {
                Text("—")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            }
        }
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

    // MARK: - 52 週區間

    private func weekStatsSection(_ stats: PortfolioListViewModel.WeekStats) -> some View {
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "%@ $%.2f (%d%%)", label, value, Int(percentile * 100)))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(barColor)
                Spacer()
                Text(String(format: "$%.1f 高", high))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
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
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(filled ? color : color.opacity(0.12))
            .foregroundStyle(filled ? .white : color)
            .clipShape(Capsule())
    }
}
