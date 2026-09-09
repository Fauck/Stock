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

    @State private var vm = SoldRecordsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

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
            }
            .onChange(of: allSoldInvestments) { _, newValue in
                vm.allSoldInvestments = newValue
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
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
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

                // 月度損益柱狀圖
                if !vm.monthlyPLData.isEmpty {
                    monthlyChartCard
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
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 月度損益柱狀圖

    private var monthlyChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("月度損益")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            Chart(vm.monthlyPLData) { month in
                if month.profit > 0 {
                    BarMark(
                        x: .value("月份", month.label),
                        y: .value("獲利", month.profit)
                    )
                    .foregroundStyle(AppColor.softUp.opacity(0.8))
                }
                if month.loss < 0 {
                    BarMark(
                        x: .value("月份", month.label),
                        y: .value("虧損", month.loss)
                    )
                    .foregroundStyle(AppColor.softDown.opacity(0.8))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(AppColor.divider)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Self.abbreviatedAmount(v))
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .cardStyle()
    }

    /// 金額縮寫（千/萬）
    private static func abbreviatedAmount(_ value: Double) -> String {
        let abs = Swift.abs(value)
        let sign = value < 0 ? "-" : ""
        if abs >= 10_000 {
            return "\(sign)\(String(format: "%.0f", value / 10_000))萬"
        } else if abs >= 1_000 {
            return "\(sign)\(String(format: "%.0f", value / 1_000))千"
        } else {
            return "\(sign)\(String(format: "%.0f", value))"
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
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }

            ForEach(vm.tickerSummaries) { summary in
                HStack(spacing: 8) {
                    // 標的名稱
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColor.textMain)
                            .lineLimit(1)
                        Text("\(summary.tradeCount)筆 · 勝率\(String(format: "%.0f", summary.winRate))%")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(minWidth: 80, alignment: .leading)

                    Spacer()

                    // 損益條
                    tickerPLBar(pl: summary.totalPL)

                    // 損益金額
                    Text(String(format: "%@$%.0f", summary.totalPL >= 0 ? "+" : "", summary.totalPL))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
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
}

#Preview {
    SoldRecordsView()
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
