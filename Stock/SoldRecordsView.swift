//
//  SoldRecordsView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - 已賣出紀錄頁面（日誌風格）

struct SoldRecordsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Investment> { $0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var allSoldInvestments: [Investment]

    @Query(filter: #Predicate<Investment> { !$0.isClosed })
    private var openInvestments: [Investment]

    @State private var vm = SoldRecordsViewModel()
    @State private var unrealizedVM = UnrealizedPnLChartViewModel()
    @State private var selectedSegment: PnLSegment = .realized

    // 未實現損益自訂日期暫存
    @State private var unrealizedCustomStart: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var unrealizedCustomEnd: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    switch selectedSegment {
                    case .realized:
                        realizedContent
                    case .unrealized:
                        unrealizedContent
                    }
                }
            }
            .navigationTitle("已實現損益")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("確認刪除", isPresented: $vm.showingDeleteAlert, presenting: vm.investmentToDelete) { _ in
                Button("刪除", role: .destructive) {
                    withAnimation {
                        vm.deleteConfirmed(context: modelContext)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: { investment in
                if investment.isPartialSellRecord {
                    Text("確定要刪除 \(StockMapping.displayName(for: investment.ticker)) 的賣出紀錄嗎？賣出數量將歸還至原始買入紀錄。")
                } else {
                    Text("確定要刪除 \(StockMapping.displayName(for: investment.ticker)) 的已平倉紀錄嗎？")
                }
            }
            .alert("刪除失敗", isPresented: $vm.showingDeleteError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(vm.deleteErrorMessage ?? "發生未知錯誤")
            }
            .onAppear {
                vm.allSoldInvestments = allSoldInvestments
                unrealizedVM.openInvestments = openInvestments
            }
            .onChange(of: allSoldInvestments) { _, newValue in
                vm.allSoldInvestments = newValue
            }
            .onChange(of: openInvestments) { _, newValue in
                unrealizedVM.openInvestments = newValue
            }
            .onChange(of: selectedSegment) { _, newValue in
                if newValue == .unrealized && unrealizedVM.chartData.isEmpty && !unrealizedVM.openInvestments.isEmpty {
                    Task { await unrealizedVM.loadCandleData() }
                }
            }
        }
    }

    // MARK: - 分頁切換

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(PnLSegment.allCases) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(.warmSubheadline())
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedSegment == segment
                                ? AppColor.primary
                                : AppColor.cardBackground
                        )
                        .foregroundStyle(
                            selectedSegment == segment
                                ? .white
                                : AppColor.textMain
                        )
                }
            }
        }
        .clipShape(Capsule())
        .rowShadow()
    }

    // MARK: - 已實現損益內容

    private var realizedContent: some View {
        VStack(spacing: 0) {
            filterBar

            if vm.filteredInvestments.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                recordsList
            }
        }
    }

    // MARK: - 空狀態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.primary.opacity(0.3))
            Text("無賣出紀錄")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Text("在選定的時間區間內沒有已平倉的交易紀錄")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.warmDataValue())
                Text("試試調整篩選條件")
                    .font(.warmCaption())
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppColor.primary.opacity(0.08))
            .clipShape(Capsule())
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
                                .rowShadow()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)

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
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 8)
        .background(AppColor.cardBackground)
        .smallShadow()
    }

    // MARK: - 紀錄列表

    private var recordsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 損益總覽
                profitLossSummaryCard
                    .padding(.horizontal, 16)

                // 交易統計
                if vm.recordCount >= 2 {
                    tradeStatsCard
                        .padding(.horizontal, 16)
                }

                // 累計損益曲線
                if !vm.cumulativeData.isEmpty {
                    cumulativeChart
                        .padding(.horizontal, 16)
                }

                // 月度/季度損益柱狀圖
                if !vm.periodData.isEmpty {
                    periodChart
                        .padding(.horizontal, 16)
                }

                // 依標的彙總
                if !vm.tickerSummaries.isEmpty {
                    tickerSummaryCard
                        .padding(.horizontal, 16)
                }

                // 個別紀錄
                sectionHeader("交易明細", icon: "list.bullet.rectangle")
                    .padding(.horizontal, 16)

                ForEach(vm.filteredInvestments) { investment in
                    soldRecordCard(for: investment)
                        .contextMenu {
                            Button(role: .destructive) {
                                vm.confirmDelete(investment)
                            } label: {
                                Label("刪除紀錄", systemImage: "trash")
                            }
                        }
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.warmCaption2())
                .foregroundStyle(AppColor.primary)
            Text(title)
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - 損益總覽卡片

    private var profitLossSummaryCard: some View {
        VStack(spacing: 12) {
            // 總損益（最醒目）
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總已實現損益")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text("\(vm.totalPL >= 0 ? "+" : "")$\(vm.totalPL, specifier: "%.0f")")
                        .font(.warmLargeNumber())
                        .foregroundStyle(Color.profitLossColor(vm.totalPL))
                }
                Spacer()
                Image(systemName: vm.totalPL >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.profitLossColor(vm.totalPL).opacity(0.3))
            }

            AppColor.divider.frame(height: 1)

            HStack {
                Text("總賣出金額")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.0f", vm.totalSellAmount))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }
            HStack {
                Text("總成本金額")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.0f", vm.totalCostAmount))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }
            HStack {
                Text("交易筆數")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("\(vm.recordCount) 筆")
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }
        }
        .cardStyle()
    }

    // MARK: - 交易統計卡片

    private var tradeStatsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("交易統計")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            // 勝率 + 盈虧比
            HStack(spacing: 0) {
                statCell(title: "勝率", value: String(format: "%.0f%%", vm.winRate),
                         color: vm.winRate >= 50 ? AppColor.softUp : AppColor.softDown)
                statCell(title: "盈虧比", value: vm.profitLossRatio > 0 ? String(format: "1:%.1f", vm.profitLossRatio) : "-",
                         color: vm.profitLossRatio >= 1 ? AppColor.softUp : (vm.profitLossRatio > 0 ? AppColor.softDown : AppColor.textSecondary))
                statCell(title: "勝 / 負", value: "\(vm.winCount) / \(vm.lossCount)",
                         color: AppColor.textMain)
            }

            AppColor.divider.frame(height: 1)

            // 平均獲利/虧損 + 最大連虧
            HStack(spacing: 0) {
                statCell(title: "平均獲利", value: String(format: "+$%.0f", vm.avgProfit),
                         color: AppColor.softUp)
                statCell(title: "平均虧損", value: String(format: "-$%.0f", vm.avgLoss),
                         color: AppColor.softDown)
                statCell(title: "最大連虧", value: "\(vm.maxConsecutiveLosses) 筆",
                         color: vm.maxConsecutiveLosses >= 3 ? AppColor.softDown : AppColor.textMain)
            }

            AppColor.divider.frame(height: 1)

            // 最大單筆 + 持有天數
            HStack(spacing: 0) {
                statCell(title: "最大獲利", value: String(format: "+$%.0f", vm.maxSingleProfit),
                         color: AppColor.softUp)
                statCell(title: "最大虧損", value: String(format: "$%.0f", vm.maxSingleLoss),
                         color: AppColor.softDown)
                statCell(title: "持有天(勝/負)",
                         value: "\(vm.avgHoldingDaysWin) / \(vm.avgHoldingDaysLoss)",
                         color: AppColor.textMain)
            }
        }
        .cardStyle()
    }

    private func statCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmDataValue(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
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

                // 明細列表
                periodDetailList(data: data)
            }
        }
        .cardStyle()
    }

    // MARK: - 期間明細列表

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

    // MARK: - 依標的彙總

    private var tickerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("標的彙總")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("依損益排序")
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.textSecondary)
            }

            ForEach(vm.tickerSummaries) { summary in
                HStack(spacing: 8) {
                    // 標的名稱
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.displayName)
                            .font(.warmDataValue(.semibold))
                            .foregroundStyle(AppColor.textMain)
                            .lineLimit(1)
                        Text("\(summary.tradeCount)筆 · 勝率\(String(format: "%.0f", summary.winRate))%")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(minWidth: 80, alignment: .leading)

                    Spacer()

                    // 損益條
                    tickerPLBar(pl: summary.totalPL)

                    // 損益金額
                    Text(String(format: "%@$%.0f", summary.totalPL >= 0 ? "+" : "", summary.totalPL))
                        .font(.warmDataValue(.bold))
                        .foregroundStyle(Color.profitLossColor(summary.totalPL))
                        .frame(minWidth: 70, alignment: .trailing)
                }
                .padding(.vertical, 2)

                if summary.id != vm.tickerSummaries.last?.id {
                    AppColor.divider.frame(height: 0.5)
                }
            }
        }
        .cardStyle()
    }

    /// 標的損益水平條
    private func tickerPLBar(pl: Double) -> some View {
        let maxPL = vm.tickerSummaries.map { abs($0.totalPL) }.max() ?? 1
        let ratio = min(abs(pl) / maxPL, 1.0)
        let color: Color = pl >= 0 ? AppColor.softUp : AppColor.softDown

        return GeometryReader { geo in
            let barWidth = geo.size.width * ratio
            ZStack(alignment: pl >= 0 ? .leading : .trailing) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColor.divider)
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.6))
                    .frame(width: max(barWidth, 2), height: 6)
            }
        }
        .frame(height: 6)
        .frame(maxWidth: 80)
    }

    // MARK: - 單筆已賣出紀錄卡片

    private func soldRecordCard(for investment: Investment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標的名稱 + 大盤狀態 + 賣出日期
            HStack {
                Text(StockMapping.displayName(for: investment.ticker))
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                if let mc = investment.buyMarketConditionEnum {
                    Text("買:\(mc.rawValue)")
                        .font(.warmCaption2())
                        .fontWeight(.medium)
                        .foregroundStyle(mc.color)
                }
                if let mc = investment.sellMarketConditionEnum {
                    Text("賣:\(mc.rawValue)")
                        .font(.warmCaption2())
                        .fontWeight(.medium)
                        .foregroundStyle(mc.color)
                }
                Spacer()
                if let sellDate = investment.sellDate {
                    Text(vm.formattedDate(sellDate))
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            // 買賣資訊
            HStack {
                WarmInfoBadge(title: "買入價", value: String(format: "$%.2f", investment.buyPrice))
                Spacer()
                if let sp = investment.sellPrice {
                    WarmInfoBadge(title: "賣出價", value: String(format: "$%.2f", sp))
                }
                Spacer()
                if let sq = investment.sellQuantity {
                    WarmInfoBadge(title: "數量", value: String(format: "%.0f 股", sq))
                }
                Spacer()
                WarmInfoBadge(title: "持有", value: "\(investment.holdingDays) 天")
            }

            // 損益顯示
            AppColor.divider.frame(height: 1)

            HStack {
                let fees = TradingFeeSettings.load()
                let pl = investment.realizedProfitLoss(fees: fees)
                let pct = investment.realizedReturnPercentage(fees: fees)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                        .font(.warmSubheadline())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.profitLossColor(pl))
                    Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                        .font(.warmCaption())
                        .foregroundStyle(Color.profitLossColor(pct))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 未實現損益內容

    private var unrealizedContent: some View {
        Group {
            if unrealizedVM.openInvestments.isEmpty {
                VStack {
                    Spacer()
                    unrealizedEmptyState
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        unrealizedFilterBar
                        unrealizedSummaryCard
                        unrealizedChart
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - 未實現空狀態

    private var unrealizedEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.textSecondary.opacity(0.4))
            Text("尚無持有中部位")
                .font(.warmSubheadline())
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.warmDataValue())
                Text("前往「行事曆」頁籤新增買入紀錄")
                    .font(.warmCaption())
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppColor.primary.opacity(0.08))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - 未實現日期篩選

    private var unrealizedFilterBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFilterOption.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                unrealizedVM.selectedFilter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    unrealizedVM.selectedFilter == option
                                        ? AppColor.primary
                                        : AppColor.cardBackground
                                )
                                .foregroundStyle(
                                    unrealizedVM.selectedFilter == option
                                        ? .white
                                        : AppColor.textMain
                                )
                                .clipShape(Capsule())
                                .rowShadow()
                        }
                    }
                }
            }

            if unrealizedVM.selectedFilter == .custom {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("起始日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $unrealizedCustomStart, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("結束日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $unrealizedCustomEnd, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                    Button {
                        unrealizedVM.customStartDate = unrealizedCustomStart
                        unrealizedVM.customEndDate = unrealizedCustomEnd
                    } label: {
                        Text("確認")
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColor.primary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 未實現摘要卡片

    private var unrealizedSummaryCard: some View {
        let s = unrealizedVM.summary
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(AppColor.primary)
                Text("持倉摘要")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Text("\(s.positionCount) 檔持有")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            AppColor.divider.frame(height: 1)

            HStack {
                Text("未實現損益")
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("\(s.currentPnL >= 0 ? "+" : "")$\(s.currentPnL, specifier: "%.0f")")
                    .font(.warmLargeNumber())
                    .foregroundStyle(Color.profitLossColor(s.currentPnL))
            }

            HStack(spacing: 0) {
                statBadge(title: "報酬率",
                          value: String(format: "%.1f%%", s.returnPct),
                          color: Color.profitLossColor(s.returnPct))
                Spacer()
                statBadge(title: "區間高點",
                          value: formatAmount(s.peakPnL),
                          color: AppColor.softUp)
                Spacer()
                statBadge(title: "區間低點",
                          value: formatAmount(s.troughPnL),
                          color: AppColor.softDown)
                Spacer()
                statBadge(title: "投入成本",
                          value: formatAmount(s.totalCost),
                          color: AppColor.textMain)
            }
        }
        .cardStyle()
    }

    // MARK: - 未實現損益走勢圖

    private var unrealizedChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.primary)
                Text("未實現損益走勢")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                if unrealizedVM.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if unrealizedVM.isLoading && unrealizedVM.chartData.isEmpty {
                ProgressView("載入歷史資料中...")
                    .font(.warmCaption())
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                let data = unrealizedVM.chartData

                if data.isEmpty {
                    Text("無歷史資料")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Chart {
                        ForEach(data) { point in
                            LineMark(
                                x: .value("日期", point.date),
                                y: .value("未實現損益", point.totalUnrealizedPnL)
                            )
                            .foregroundStyle(AppColor.primary)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("日期", point.date),
                                yStart: .value("零線", 0),
                                yEnd: .value("未實現損益", point.totalUnrealizedPnL)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        (point.totalUnrealizedPnL >= 0
                                            ? AppColor.softUp : AppColor.softDown).opacity(0.3),
                                        (point.totalUnrealizedPnL >= 0
                                            ? AppColor.softUp : AppColor.softDown).opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }

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
        }
        .cardStyle()
    }

    // MARK: - 共用元件

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
    SoldRecordsView()
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
