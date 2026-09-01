//
//  PnLChartView.swift
//  Stock
//
//  Created by bokmacdev on 2026/9/1.
//

import SwiftUI
import SwiftData
import Charts

/// 損益走勢圖：累計已實現損益曲線 + 月度/季度柱狀圖
struct PnLChartView: View {
    @Query(filter: #Predicate<Investment> { $0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var soldInvestments: [Investment]

    @State private var vm = PnLChartViewModel()

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if vm.allSoldInvestments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        filterBar
                        summaryCard
                        cumulativeChart
                        periodChart
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("損益走勢圖")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { vm.allSoldInvestments = soldInvestments }
        .onChange(of: soldInvestments) { vm.allSoldInvestments = soldInvestments }
    }

    // MARK: - 空狀態

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.textSecondary.opacity(0.4))
            Text("尚無已實現損益紀錄")
                .font(.warmSubheadline())
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 日期篩選列

    private var filterBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFilterOption.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                vm.selectedFilter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    vm.selectedFilter == option
                                        ? AppColor.primary
                                        : AppColor.cardBackground
                                )
                                .foregroundStyle(
                                    vm.selectedFilter == option
                                        ? .white
                                        : AppColor.textMain
                                )
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                        }
                    }
                }
            }

            if vm.selectedFilter == .custom {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("起始日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $vm.customStartDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("結束日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $vm.customEndDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 摘要卡片

    private var summaryCard: some View {
        let s = vm.summary
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(AppColor.primary)
                Text("績效摘要")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Text("\(s.tradeCount) 筆交易")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            AppColor.divider.frame(height: 1)

            // 總損益（大字）
            HStack {
                Text("累計損益")
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("\(s.totalPnL >= 0 ? "+" : "")$\(s.totalPnL, specifier: "%.0f")")
                    .font(.warmLargeNumber())
                    .foregroundStyle(Color.profitLossColor(s.totalPnL))
            }

            // 統計列
            HStack(spacing: 0) {
                statBadge(title: "勝率", value: String(format: "%.1f%%", s.winRate),
                          color: s.winRate >= 50 ? AppColor.softUp : AppColor.softDown)
                Spacer()
                statBadge(title: "最大獲利", value: String(format: "+$%.0f", s.bestTrade),
                          color: AppColor.softUp)
                Spacer()
                statBadge(title: "最大虧損", value: String(format: "$%.0f", s.worstTrade),
                          color: AppColor.softDown)
                Spacer()
                statBadge(title: "平均損益", value: String(format: "$%.0f", s.avgPnL),
                          color: Color.profitLossColor(s.avgPnL))
            }
        }
        .cardStyle()
    }

    private func statBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.warmCaption2())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmCaption())
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }

    // MARK: - 累計損益曲線

    private var cumulativeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.primary)
                Text("累計損益曲線")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
            }

            let data = vm.cumulativeData

            if data.isEmpty {
                Text("篩選區間內無資料")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("累計損益", point.cumulativePnL)
                        )
                        .foregroundStyle(AppColor.primary)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("日期", point.date),
                            yStart: .value("零線", 0),
                            yEnd: .value("累計損益", point.cumulativePnL)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    (point.cumulativePnL >= 0 ? AppColor.softUp : AppColor.softDown).opacity(0.3),
                                    (point.cumulativePnL >= 0 ? AppColor.softUp : AppColor.softDown).opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // 零線
                    RuleMark(y: .value("零線", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatAmount(v))
                                    .font(.warmCaption2())
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColor.divider)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatChartDate(date))
                                    .font(.warmCaption2())
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColor.divider)
                    }
                }
                .frame(height: 220)
            }
        }
        .cardStyle()
    }

    // MARK: - 月度/季度柱狀圖

    private var periodChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.primary)
                Text("損益分佈")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()

                // 月度/季度切換
                HStack(spacing: 0) {
                    ForEach(PeriodMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.periodMode = mode
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.warmCaption2())
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    vm.periodMode == mode
                                        ? AppColor.primary
                                        : Color.clear
                                )
                                .foregroundStyle(
                                    vm.periodMode == mode
                                        ? .white
                                        : AppColor.textMain
                                )
                        }
                    }
                }
                .background(AppColor.background)
                .clipShape(Capsule())
            }

            let data = vm.periodData

            if data.isEmpty {
                Text("篩選區間內無資料")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(data) { period in
                        BarMark(
                            x: .value("期間", period.label),
                            y: .value("損益", period.pnl)
                        )
                        .foregroundStyle(period.pnl >= 0 ? AppColor.softUp : AppColor.softDown)
                        .cornerRadius(4)
                    }

                    // 零線
                    RuleMark(y: .value("零線", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatAmount(v))
                                    .font(.warmCaption2())
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColor.divider)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.warmCaption2())
                                    .foregroundStyle(AppColor.textSecondary)
                                    .rotationEffect(.degrees(-30))
                            }
                        }
                    }
                }
                .frame(height: 220)

                // 月度明細列表
                periodDetailList(data: data)
            }
        }
        .cardStyle()
    }

    // MARK: - 月度明細列表

    private func periodDetailList(data: [PeriodPnL]) -> some View {
        VStack(spacing: 0) {
            AppColor.divider.frame(height: 1)
                .padding(.vertical, 8)

            ForEach(data) { period in
                HStack {
                    Text(period.label)
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textMain)
                        .frame(width: 60, alignment: .leading)

                    // 勝率條
                    let winRate = period.tradeCount > 0
                        ? Double(period.winCount) / Double(period.tradeCount)
                        : 0
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            if winRate > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColor.softUp.opacity(0.6))
                                    .frame(width: max(geo.size.width * winRate, 2))
                            }
                            if winRate < 1 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColor.softDown.opacity(0.4))
                                    .frame(width: max(geo.size.width * (1 - winRate), 2))
                            }
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 60)

                    Text("\(period.winCount)/\(period.tradeCount)")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 35, alignment: .center)

                    Spacer()

                    Text("\(period.pnl >= 0 ? "+" : "")$\(period.pnl, specifier: "%.0f")")
                        .font(.warmCaption())
                        .fontWeight(.medium)
                        .foregroundStyle(Color.profitLossColor(period.pnl))
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 格式化工具

    private func formatAmount(_ value: Double) -> String {
        let abs = Swift.abs(value)
        let sign = value < 0 ? "-" : ""
        if abs >= 10000 {
            return "\(sign)\(String(format: "%.1f", abs / 10000))萬"
        } else if abs >= 1000 {
            return "\(sign)\(String(format: "%.1f", abs / 1000))K"
        } else {
            return "\(sign)\(String(format: "%.0f", abs))"
        }
    }

    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func formatChartDate(_ date: Date) -> String {
        Self.chartDateFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        PnLChartView()
    }
}
