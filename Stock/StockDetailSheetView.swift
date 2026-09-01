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

    @Environment(\.dismiss) private var dismiss
    @State private var chartVM: KLineChartViewModel

    init(
        group: PortfolioGroup,
        signal: TechnicalIndicators.SignalSummary?,
        weekStats: PortfolioListViewModel.WeekStats?,
        currentPrice: Double?,
        displayName: String
    ) {
        self.group = group
        self.signal = signal
        self.weekStats = weekStats
        self.currentPrice = currentPrice
        self.displayName = displayName
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("技術指標")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 信號標籤列
            HStack(spacing: 6) {
                // MA5 相對位置
                if let ma5 = signal.ma5Position {
                    signalPill(
                        ma5 == .above ? "MA5↑" : "MA5↓",
                        color: ma5 == .above ? AppColor.secondary : AppColor.softDown
                    )
                }

                // MA20 相對位置
                if let ma20 = signal.ma20Position {
                    signalPill(
                        ma20 == .above ? "MA20↑" : "MA20↓",
                        color: ma20 == .above ? AppColor.secondary : AppColor.softDown
                    )
                }

                // RSI
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

                // KDJ
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
        }
        .padding(12)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
