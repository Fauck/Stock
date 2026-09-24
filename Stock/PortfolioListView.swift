//
//  PortfolioListView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 庫存列表視圖：卡片式設計，溫暖日誌風格
struct PortfolioListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Investment> { !$0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var investments: [Investment]

    @Query private var allJournals: [TradeJournal]

    @State private var vm = PortfolioListViewModel()
    @State private var marketInfoExpanded: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                Group {
                    if investments.isEmpty {
                        emptyState
                    } else {
                        portfolioList
                    }
                }
            }
            .navigationTitle("持有庫存")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $vm.showingSellSheet) {
                if let investment = vm.selectedInvestment {
                    SellView(investment: investment)
                }
            }
            .sheet(isPresented: $vm.showingGroupSellSheet) {
                if let group = vm.selectedGroup {
                    GroupSellView(group: group)
                }
            }
            .sheet(isPresented: $vm.showingStockDetailSheet) {
                if let group = vm.selectedGroupForDetail {
                    StockDetailSheetView(
                        group: group,
                        signal: vm.technicalSignals[group.ticker],
                        weekStats: vm.weekStats[group.ticker],
                        currentPrice: vm.currentPrice(for: group.ticker),
                        displayName: vm.displayName(for: group.ticker),
                        highSinceBuy: vm.highSinceBuy[group.ticker],
                        institutionalData: vm.institutionalData[group.ticker],
                        marginData: vm.marginData[group.ticker],
                        sellRecommendation: vm.sellRecommendation(for: group.ticker, avgCost: group.weightedAverageCost),
                        journalTarget: vm.journalTargets[group.ticker],
                        maDeductions: vm.maDeductions[group.ticker] ?? []
                    )
                }
            }
            .alert("確認刪除", isPresented: $vm.showingDeleteAlert, presenting: vm.investmentToDelete) { _ in
                Button("刪除", role: .destructive) {
                    withAnimation {
                        vm.deleteConfirmed(context: modelContext)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: { investment in
                Text("確定要刪除 \(StockMapping.displayName(for: investment.ticker)) 的買入紀錄嗎？相關的部分賣出紀錄也會一併刪除。")
            }
            .alert("刪除失敗", isPresented: $vm.showingDeleteError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(vm.deleteErrorMessage ?? "發生未知錯誤")
            }
            .onAppear {
                vm.investments = investments
                vm.journals = allJournals
                vm.buildJournalTargets()
                vm.loadData()
            }
            .onChange(of: investments) { _, newValue in
                vm.investments = newValue
                vm.buildJournalTargets()
                // 資料更新時重新載入（含首次 @Query 載入完成時）
                if !newValue.isEmpty && !vm.hasAnyPrice {
                    vm.loadData()
                }
            }
            .onChange(of: allJournals) { _, newValue in
                vm.journals = newValue
                vm.buildJournalTargets()
            }
        }
    }

    // MARK: - 空狀態

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf")
                .font(.system(size: 50))
                .foregroundStyle(AppColor.primary.opacity(0.4))
            Text("尚無持有部位")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)

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
    }

    // MARK: - 庫存列表

    private var portfolioList: some View {
        ScrollView {
            VStack(spacing: 10) {
                // 總覽卡片
                totalSummaryCard
                    .padding(.horizontal)

                // 各標的卡片
                ForEach(vm.groups) { group in
                    groupCard(for: group)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
        .keyboardDismissable()
    }

    // MARK: - 總覽卡片

    private var totalSummaryCard: some View {
        let isLoading = vm.isFetchingPrices || vm.isFetchingSignals || vm.isFetchingWeekStats || vm.isFetchingInstitutional

        return VStack(spacing: 14) {
            // ── 標題列 ──
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundStyle(AppColor.primary)
                Text("投資總覽")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Button {
                    vm.loadData(forceRefresh: true)
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .disabled(isLoading)
            }

            // ── 三欄 Metric Grid ──
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                dashboardMetricCell(
                    title: "持有檔數",
                    value: "\(vm.groups.count)",
                    color: AppColor.primary
                )
                dashboardMetricCell(
                    title: "總成本",
                    value: String(format: "$%.0f", vm.totalCost),
                    color: AppColor.textMain
                )
                if vm.hasAnyPrice {
                    dashboardMetricCell(
                        title: "總市值",
                        value: String(format: "$%.0f", vm.totalMarketValue),
                        color: AppColor.textMain
                    )
                } else {
                    dashboardMetricCell(
                        title: "總市值",
                        value: "--",
                        color: AppColor.textSecondary.opacity(0.5)
                    )
                }
            }

            // ── 損益主區 ──
            if vm.hasAnyPrice {
                VStack(spacing: 6) {
                    Text("未實現損益")
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.textSecondary)

                    HStack(spacing: 8) {
                        Text("\(vm.totalPL >= 0 ? "+" : "")$\(vm.totalPL, specifier: "%.0f")")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.profitLossColor(vm.totalPL))
                            .contentTransition(.numericText())
                        Text("(\(vm.totalReturnPct >= 0 ? "+" : "")\(vm.totalReturnPct, specifier: "%.1f")%)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.profitLossColor(vm.totalPL))
                            .contentTransition(.numericText())
                    }

                    // 微型報酬率進度條
                    GeometryReader { geo in
                        let maxWidth = geo.size.width
                        let pct = min(1.0, abs(vm.totalReturnPct) / 50.0)
                        let barWidth = maxWidth * pct
                        let barColor = vm.totalPL >= 0 ? AppColor.softUp : AppColor.softDown

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColor.divider)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor.opacity(0.6))
                                .frame(width: max(0, barWidth), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)

                // ── 本日增減 ──
                if let dailyChange = vm.totalDailyPLChange {
                    HStack(spacing: 0) {
                        dashDivider
                        Text("  本日增減  ")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)
                        dashDivider
                    }
                    .padding(.horizontal, 8)

                    Text("\(dailyChange >= 0 ? "+" : "")$\(dailyChange, specifier: "%.0f")")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.profitLossColor(dailyChange))
                        .contentTransition(.numericText())
                }
            }
        }
        .cardStyle()
    }

    /// Dashboard metric 格子
    private func dashboardMetricCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(.warmTertiary())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.l)
        .background(AppColor.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
    }

    /// 虛線分隔線
    private var dashDivider: some View {
        AppColor.divider
            .frame(height: 1)
    }

    // MARK: - 群組卡片

    private func groupCard(for group: PortfolioGroup) -> some View {
        let isExpanded = vm.isExpanded(group.ticker)
        let currentPrice = vm.currentPrice(for: group.ticker)
        let fees = TradingFeeSettings.load()
        let pl: Double? = currentPrice.map { group.unrealizedProfitLoss(currentPrice: $0, fees: fees) }
        // 損益色帶色
        let accentColor: Color = {
            guard let pl else { return AppColor.divider }
            return Color.profitLossColor(pl)
        }()

        return HStack(spacing: 0) {
            // ── 左側損益色帶（加寬至 4pt，全高）──
            RoundedRectangle(cornerRadius: AppRadius.micro)
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 0) {
                // ── 摘要列（始終顯示）──
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    // ── 身份列：名稱 + 代號 ｜ Sparkline + 持有天數 + 分析 ──
                    HStack(alignment: .center, spacing: AppSpacing.s) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(vm.displayName(for: group.ticker))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColor.primary)
                                .lineLimit(1)
                            Text(group.ticker)
                                .font(.warmMicro())
                                .foregroundStyle(AppColor.textSecondary)
                        }

                        Spacer(minLength: AppSpacing.m)

                        // 7 日迷你走勢線
                        if let sparkData = vm.sparklineData[group.ticker],
                           sparkData.count >= 2 {
                            SparklineView(data: sparkData)
                        }

                        Text("\(group.holdingDays)天")
                            .font(.warmMicro())
                            .foregroundStyle(AppColor.textSecondary)

                        // 個股分析
                        Button { vm.openStockDetail(group) } label: {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColor.primary)
                                .frame(width: 28, height: 28)
                                .background(AppColor.primary.opacity(0.10))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    // ── 績效列：現價 + 元資料 ｜ 損益金額 + 報酬率 ──
                    HStack(alignment: .top, spacing: AppSpacing.ml) {
                        // 左側：現價 + 股數·均價·漲跌
                        VStack(alignment: .leading, spacing: 3) {
                            if let price = currentPrice {
                                Text(String(format: "$%.2f", price))
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColor.textMain)
                                    .contentTransition(.numericText())
                            } else {
                                Text("--")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColor.textSecondary.opacity(0.3))
                            }

                            HStack(spacing: AppSpacing.s) {
                                HStack(spacing: 0) {
                                    Text(String(format: "%.0f股", group.totalQuantity))
                                        .foregroundStyle(AppColor.textMain)
                                    Text("｜")
                                        .foregroundStyle(AppColor.divider)
                                    Text(String(format: "均%.2f", group.weightedAverageCost))
                                        .foregroundStyle(AppColor.textSecondary)
                                }

                                if let change = vm.dailyChangePoints[group.ticker],
                                   let changePct = vm.dailyChangePercents[group.ticker] {
                                    HStack(spacing: 2) {
                                        Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                            .font(.system(size: 7))
                                        Text(String(format: "%.2f(%.1f%%)", abs(change), abs(changePct)))
                                            .contentTransition(.numericText())
                                    }
                                    .foregroundStyle(Color.profitLossColor(change))
                                }
                            }
                            .font(.warmTertiary())
                            .lineLimit(1)
                        }

                        Spacer(minLength: AppSpacing.m)

                        // 右側：損益金額 + 報酬率
                        if let price = currentPrice {
                            let plVal = group.unrealizedProfitLoss(currentPrice: price, fees: fees)
                            let pctVal = group.returnPercentage(currentPrice: price, fees: fees)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(String(format: "%@$%.0f", plVal >= 0 ? "+" : "", plVal))
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.profitLossColor(plVal))
                                    .contentTransition(.numericText())
                                Text(String(format: "%@%.1f%%", pctVal >= 0 ? "+" : "", pctVal))
                                    .font(.warmSecondaryData(.semibold))
                                    .foregroundStyle(Color.profitLossColor(plVal).opacity(0.85))
                                    .contentTransition(.numericText())
                            }
                        }
                    }

                    // 技術信號標籤列（僅警示型 pills）
                    if let signal = vm.technicalSignals[group.ticker] {
                        FlowLayout(spacing: AppSpacing.xs) {
                            compactSignalBadges(signal, ticker: group.ticker, avgCost: group.weightedAverageCost)
                        }
                    }
                }
                .padding(.leading, AppSpacing.l)
                .padding(.trailing, AppSpacing.lg)
                .padding(.vertical, AppSpacing.l)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.toggleExpanded(group.ticker)
                    }
                }

                // ── 展開的詳細內容 ──
                if isExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        AppColor.divider.frame(height: 1)
                            .padding(.horizontal, AppSpacing.lg)

                        // ━━ 持倉概覽 ━━
                        sectionHeader("持倉概覽")

                        if let price = currentPrice {
                            let plVal = group.unrealizedProfitLoss(currentPrice: price, fees: fees)
                            let pctVal = group.returnPercentage(currentPrice: price, fees: fees)
                            let marketValue = price * group.totalQuantity

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ], spacing: 10) {
                                expandedMetricCell(title: "市值", value: String(format: "$%.0f", marketValue), color: AppColor.textMain)
                                expandedMetricCell(title: "成本", value: String(format: "$%.0f", group.totalInvested), color: AppColor.textMain)
                                expandedMetricCell(
                                    title: "損益",
                                    value: String(format: "%@$%.0f", plVal >= 0 ? "+" : "", plVal),
                                    subtitle: String(format: "%@%.1f%%", pctVal >= 0 ? "+" : "", pctVal),
                                    color: Color.profitLossColor(plVal)
                                )
                            }
                            .padding(.horizontal, AppSpacing.lg)

                            // 本日增減
                            if let dailyChange = vm.dailyPLChange(for: group.ticker, quantity: group.totalQuantity) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.warmMicro())
                                        .foregroundStyle(AppColor.secondary)
                                    Text("本日增減")
                                        .font(.warmTertiary())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Spacer()
                                    Text(String(format: "%@$%.0f", dailyChange >= 0 ? "+" : "", dailyChange))
                                        .font(.warmSecondaryData(.bold))
                                        .foregroundStyle(Color.profitLossColor(dailyChange))
                                        .contentTransition(.numericText())
                                }
                                .padding(.horizontal, AppSpacing.lg)
                            }
                        }

                        // ━━ 風控狀態 ━━
                        if let price = currentPrice {
                            let hasRiskData = (vm.highSinceBuy[group.ticker] ?? 0) > 0 || vm.journalTargets[group.ticker] != nil
                            if hasRiskData {
                                sectionHeader("風控狀態")
                                riskControlSection(ticker: group.ticker, currentPrice: price, avgCost: group.weightedAverageCost)
                            }
                        }

                        // ━━ 市場資訊（可收合）━━
                        let hasInst = vm.institutionalData[group.ticker] != nil
                        let hasSignal = vm.technicalSignals[group.ticker] != nil
                        let hasMargin = vm.marginData[group.ticker] != nil
                        if hasInst || hasSignal || hasMargin {
                            collapsibleSectionHeader("市場資訊", ticker: group.ticker)

                            if marketInfoExpanded.contains(group.ticker) {
                                if let inst = vm.institutionalData[group.ticker] {
                                    institutionalBanner(inst)
                                        .padding(.horizontal, AppSpacing.lg)
                                }

                                if let margin = vm.marginData[group.ticker] {
                                    marginBanner(margin)
                                        .padding(.horizontal, AppSpacing.lg)
                                }

                                if let signal = vm.technicalSignals[group.ticker] {
                                    expandedSignalSummary(signal, ticker: group.ticker)
                                        .padding(.horizontal, AppSpacing.lg)
                                }
                            }
                        }

                        // ━━ 操作 ━━
                        sectionHeader("操作")

                        HStack(spacing: AppSpacing.m) {
                            // 現價手動修正
                            HStack(spacing: AppSpacing.s) {
                                Image(systemName: "pencil.line")
                                    .font(.warmTertiary())
                                    .foregroundStyle(AppColor.primary)
                                TextField(
                                    "現價",
                                    text: Binding(
                                        get: { vm.priceBinding(for: group.ticker) },
                                        set: { vm.setPrice($0, for: group.ticker) }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .font(.warmDataValue())
                            }
                            .padding(.horizontal, AppSpacing.l)
                            .padding(.vertical, 7)
                            .background(AppColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
                            .frame(maxWidth: 110)

                            Spacer()

                            // 整批賣出
                            Button { vm.selectGroupForSell(group) } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "rectangle.stack.fill")
                                        .font(.system(size: 8))
                                    Text("整批賣出")
                                }
                                .font(.warmTertiary(.semibold))
                                .padding(.horizontal, AppSpacing.l)
                                .padding(.vertical, 7)
                                .foregroundStyle(AppColor.softUp)
                                .background(AppColor.softUp.opacity(0.10))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)

                        // ━━ 買入明細 ━━
                        sectionHeader("買入明細")

                        VStack(spacing: 6) {
                            ForEach(group.investments) { investment in
                                detailRow(for: investment, currentPrice: currentPrice)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            vm.confirmDelete(investment)
                                        } label: {
                                            Label("刪除紀錄", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    .padding(.bottom, AppSpacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .cardShadow()
    }

    // MARK: - 區段標題

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(.warmTertiary(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            VStack { AppColor.divider.frame(height: 0.5) }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xs)
    }

    private func collapsibleSectionHeader(_ title: String, ticker: String) -> some View {
        let isExpanded = marketInfoExpanded.contains(ticker)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    marketInfoExpanded.remove(ticker)
                } else {
                    marketInfoExpanded.insert(ticker)
                }
            }
        } label: {
            HStack(spacing: AppSpacing.m) {
                Image(systemName: "building.columns")
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.primary)
                Text(title)
                    .font(.warmTertiary(.semibold))
                    .foregroundStyle(AppColor.textMain)

                Spacer()

                Text(isExpanded ? "收合" : "點擊展開")
                    .font(.warmMicro())
                    .foregroundStyle(AppColor.primary.opacity(0.7))

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColor.primary)
            }
            .padding(.horizontal, AppSpacing.ml)
            .padding(.vertical, AppSpacing.m)
            .background(AppColor.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 風控區段

    @ViewBuilder
    private func riskControlSection(ticker: String, currentPrice: Double, avgCost: Double) -> some View {
        let hasTrailingStop = vm.highSinceBuy[ticker] != nil && (vm.highSinceBuy[ticker] ?? 0) > 0
        let hasTargets = vm.journalTargets[ticker] != nil

        if hasTrailingStop || hasTargets {
            VStack(alignment: .leading, spacing: 6) {
                // 移動停利
                if let high = vm.highSinceBuy[ticker], high > 0 {
                    let pct = TradingFeeSettings.load().trailingStopPct
                    let rawStop = high * (1 - pct / 100)
                    let stopPrice = max(rawStop, avgCost)
                    let drawdownPct = (high - currentPrice) / high * 100

                    if currentPrice <= stopPrice {
                        trailingStopPill(
                            icon: "exclamationmark.triangle.fill",
                            color: AppColor.softDown,
                            text: String(format: "已跌破停利線 $%.1f（最高 $%.1f ↓%.1f%%）", stopPrice, high, drawdownPct)
                        )
                    } else if currentPrice <= stopPrice * 1.03 {
                        trailingStopPill(
                            icon: "exclamationmark.circle.fill",
                            color: .orange,
                            text: String(format: "接近停利線 $%.1f（最高 $%.1f ↓%.1f%%）", stopPrice, high, drawdownPct)
                        )
                    } else {
                        trailingStopPill(
                            icon: "shield.checkered",
                            color: AppColor.textSecondary,
                            text: String(format: "停利參考 $%.1f（最高 $%.1f）", stopPrice, high)
                        )
                    }
                }

                // 目標價 / 停損價
                if let jt = vm.journalTargets[ticker] {
                    HStack(spacing: 12) {
                        if let tp = jt.targetPrice, tp > 0 {
                            let distPct = (tp - currentPrice) / currentPrice * 100
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "target")
                                    .font(.warmMicro())
                                    .foregroundStyle(AppColor.secondary)
                                Text(String(format: "目標 $%.0f", tp))
                                    .font(.warmTertiary())
                                    .foregroundStyle(AppColor.textMain)
                                Text(String(format: "(%@%.1f%%)", distPct >= 0 ? "+" : "", distPct))
                                    .font(.warmMicro())
                                    .foregroundStyle(distPct >= 0 ? AppColor.secondary : AppColor.softDown)
                            }
                        }
                        if let sl = jt.stopLoss, sl > 0 {
                            let distPct = (currentPrice - sl) / currentPrice * 100
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "exclamationmark.shield")
                                    .font(.warmMicro())
                                    .foregroundStyle(AppColor.softDown)
                                Text(String(format: "停損 $%.0f", sl))
                                    .font(.warmTertiary())
                                    .foregroundStyle(AppColor.textMain)
                                Text(String(format: "(-%@%.1f%%)", distPct >= 0 ? "" : "+", abs(distPct)))
                                    .font(.warmMicro())
                                    .foregroundStyle(distPct > 5 ? AppColor.textSecondary : AppColor.softDown)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    /// 展開區塊的數據格子
    private func expandedMetricCell(title: String, value: String, subtitle: String? = nil, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmDataValue(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(.warmMicro(.semibold))
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.m)
        .background(AppColor.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
    }

    // MARK: - 展開後的單筆紀錄

    private func detailRow(for investment: Investment, currentPrice: Double?) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(vm.formattedDate(investment.buyDate))
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        Text("\(investment.holdingDays) 天")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                    HStack(spacing: 8) {
                        Text(String(format: "$%.2f", investment.buyPrice))
                            .font(.warmCaption())
                        Text("×")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: "%.0f 股", investment.quantity))
                            .font(.warmCaption())
                        Text(String(format: "$%.0f", investment.totalCost))
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                    }
                }
                Spacer()
                // 右側：單筆損益 + 賣出按鈕
                VStack(alignment: .trailing, spacing: 4) {
                    if let price = currentPrice {
                        let fees = TradingFeeSettings.load()
                        let pl = investment.unrealizedProfitLoss(currentPrice: price, fees: fees)
                        let pct = investment.returnPercentage(currentPrice: price, fees: fees)
                        Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                            .font(.warmCaption2())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.profitLossColor(pl))
                        Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%")
                            .font(.warmCaption2())
                            .foregroundStyle(Color.profitLossColor(pct))
                    }
                    Button {
                        vm.selectForSell(investment)
                    } label: {
                        Text("單筆賣出")
                            .font(.warmCaption2())
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColor.softUp.opacity(0.15))
                            .foregroundStyle(AppColor.softUp)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(AppSpacing.l)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
    }

    // MARK: - 技術指標信號顯示

    /// 摺疊狀態下的警示徽章（僅顯示需要行動的信號）
    @ViewBuilder
    private func compactSignalBadges(_ signal: TechnicalIndicators.SignalSummary, ticker: String, avgCost: Double) -> some View {
        // 賣出建議（偏空等級）
        if let rec = vm.sellRecommendation(for: ticker, avgCost: avgCost) {
            switch rec.level {
            case .strongSell:
                signalPill(rec.level.shortLabel, color: AppColor.softDown, filled: true)
            case .considerSell:
                signalPill(rec.level.shortLabel, color: .orange, filled: true)
            default:
                EmptyView()
            }
        }
        // 移動停利跌破 / 接近
        if let price = vm.currentPrice(for: ticker),
           let high = vm.highSinceBuy[ticker], high > 0 {
            let pct = TradingFeeSettings.load().trailingStopPct
            let rawStop = high * (1 - pct / 100)
            let stopPrice = max(rawStop, avgCost)
            if price <= stopPrice {
                signalPill("跌破停利", color: AppColor.softDown, filled: true)
            } else if price <= stopPrice * 1.03 {
                signalPill("接近停利", color: .orange, filled: true)
            }
        }
        // 停損跌破 / 接近
        if let price = vm.currentPrice(for: ticker),
           let jt = vm.journalTargets[ticker],
           let sl = jt.stopLoss, sl > 0 {
            if price <= sl {
                signalPill("跌破停損", color: AppColor.softDown, filled: true)
            } else if (price - sl) / sl * 100 <= 3 {
                signalPill("接近停損", color: .orange, filled: true)
            }
        }
        // 目標達成 / 接近
        if let price = vm.currentPrice(for: ticker),
           let jt = vm.journalTargets[ticker],
           let tp = jt.targetPrice, tp > 0 {
            if price >= tp {
                signalPill("達標", color: AppColor.softUp, filled: true)
            } else if (tp - price) / price * 100 <= 3 {
                signalPill("接近目標", color: AppColor.softUp)
            }
        }
    }

    /// 展開狀態下的關鍵信號摘要（精簡 pills 行）
    @ViewBuilder
    private func expandedSignalSummary(_ signal: TechnicalIndicators.SignalSummary, ticker: String) -> some View {
        FlowLayout(spacing: 4) {
            // 均線交叉
            if let maCross = signal.maCross {
                signalPill(maCross.label, color: maCross == .goldenCross ? AppColor.softUp : AppColor.softDown)
            }
            // MACD 交叉
            if let macdSig = signal.macdSignal, let label = macdSig.label {
                signalPill(label, color: macdSig == .goldenCross ? AppColor.softUp : AppColor.softDown)
            }
            // KD 交叉
            if let kdjSig = signal.kdjSignal, let label = kdjSig.label {
                signalPill(label, color: kdjSig == .goldenCross ? AppColor.softUp : AppColor.softDown)
            }
            // RSI 超買超賣
            if let rsiSig = signal.rsiSignal, let label = rsiSig.label {
                signalPill(label, color: rsiSig == .overbought ? AppColor.softUp : AppColor.softDown)
            }
            // 52 週位置警示
            if let stats = vm.weekStats[ticker],
               let price = vm.currentPrice(for: ticker),
               stats.high52w > stats.low52w {
                let pct = (price - stats.low52w) / (stats.high52w - stats.low52w)
                if pct >= 0.95 {
                    signalPill("近52W高", color: AppColor.softUp)
                } else if pct <= 0.05 {
                    signalPill("近52W低", color: AppColor.softDown)
                }
            }
            // 布林通道
            if let bbSig = signal.bollingerSignal, let label = bbSig.label {
                signalPill(label, color: bbSig == .nearLower ? AppColor.softDown : (bbSig == .nearUpper ? AppColor.softUp : AppColor.primary))
            }
            // 量能異動
            if let volSig = signal.volumeSignal, let label = volSig.label {
                signalPill(label, color: volSig == .surge ? AppColor.softUp : (volSig == .shrink ? AppColor.textSecondary : AppColor.secondary))
            }
        }
    }

    /// 展開狀態下的完整技術指標信號
    private func technicalSignalView(_ signal: TechnicalIndicators.SignalSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("技術指標")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                if vm.isFetchingSignals {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // 信號標籤列
            HStack(spacing: 6) {
                // MA5 相對位置
                if let ma5 = signal.ma5Position {
                    signalPill(
                        ma5 == .above ? "MA5↑" : "MA5↓",
                        color: ma5 == .above ? AppColor.softUp : AppColor.softDown
                    )
                }

                // MA20 相對位置
                if let ma20 = signal.ma20Position {
                    signalPill(
                        ma20 == .above ? "MA20↑" : "MA20↓",
                        color: ma20 == .above ? AppColor.softUp : AppColor.softDown
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
                    signalPill(label, color: kdjSig == .goldenCross ? AppColor.softUp : AppColor.softDown, filled: true)
                }
            }
        }
        .padding(AppSpacing.l)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
    }

    // MARK: - 52 週區間顯示

    /// 展開狀態下的 52 週高低點區間
    private func weekStatsView(
        stats: WeekStats,
        currentPrice: Double?,
        avgCost: Double
    ) -> some View {
        let range = stats.high52w - stats.low52w

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("52週區間")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                if vm.isFetchingWeekStats {
                    ProgressView()
                        .scaleEffect(0.6)
                }
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
            let avgPct = min(1, max(0, (avgCost - stats.low52w) / range))
            rangeBar(
                label: "均價",
                value: avgCost,
                percentile: avgPct,
                low: stats.low52w,
                high: stats.high52w
            )
        }
        .padding(AppSpacing.l)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
    }

    /// 52 週區間進度條
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
            // 標籤列：低 ... 百分位 ... 高
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

            // 進度條
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let dotX = trackWidth * percentile

                ZStack(alignment: .leading) {
                    // 底部軌道
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColor.divider)
                        .frame(height: 4)

                    // 填色
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(0.5))
                        .frame(width: max(0, dotX), height: 4)

                    // 圓點標記
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

    // MARK: - 法人買賣超摘要

    private func institutionalBanner(_ data: StockService.InstitutionalSummary) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text(String(format: "法人動態（%@）", String(data.latestDate.suffix(4).prefix(2) + "/" + data.latestDate.suffix(2))))
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                if vm.isFetchingInstitutional {
                    ProgressView().scaleEffect(0.5)
                }
            }
            HStack(spacing: 0) {
                institutionalCell(label: "外資", value: data.latestForeignNet, streak: data.foreignStreak)
                institutionalCell(label: "投信", value: data.latestTrustNet, streak: data.trustStreak)
                institutionalCell(label: "自營", value: data.latestDealerNet, streak: nil)
                institutionalCell(label: "合計", value: data.latestTotalNet, streak: data.totalStreak)
            }
        }
        .padding(AppSpacing.l)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
    }

    private func institutionalCell(label: String, value: Int, streak: Int?) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Text(label)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text("\(value >= 0 ? "+" : "")\(value)")
                .font(.warmTertiary(.semibold))
                .foregroundStyle(Color.profitLossColor(Double(value)))
            if let streak, abs(streak) >= 2 {
                Text("連\(streak > 0 ? "買" : "賣")\(abs(streak))日")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(streak > 0 ? AppColor.secondary : AppColor.softDown)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 融資融券摘要

    private func marginBanner(_ data: StockService.MarginTradingSummary) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "banknote")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text(String(format: "融資融券（%@）", {
                    guard let d = data.days.first?.date, d.count == 8 else { return "" }
                    let mm = d[d.index(d.startIndex, offsetBy: 4)..<d.index(d.startIndex, offsetBy: 6)]
                    let dd = d[d.index(d.startIndex, offsetBy: 6)..<d.endIndex]
                    return "\(mm)/\(dd)"
                }()))
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                if vm.isFetchingMargin {
                    ProgressView().scaleEffect(0.5)
                }
            }
            HStack(spacing: 0) {
                marginBannerCell(label: "融資餘額", value: data.latestMarginBalance, isBalance: true)
                marginBannerCell(label: "融資增減", value: data.days.first?.marginBuyChange ?? 0, isBalance: false)
                marginBannerCell(label: "融券餘額", value: data.latestShortBalance, isBalance: true)
                marginBannerCell(label: "融券增減", value: data.days.first?.shortSellChange ?? 0, isBalance: false)
            }
        }
        .padding(AppSpacing.l)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
    }

    private func marginBannerCell(label: String, value: Int, isBalance: Bool) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Text(label)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            if isBalance {
                Text(formatCompactBanner(value))
                    .font(.warmTertiary(.semibold))
                    .foregroundStyle(AppColor.textMain)
            } else {
                Text("\(value >= 0 ? "+" : "")\(value)")
                    .font(.warmTertiary(.semibold))
                    .foregroundStyle(Color.profitLossColor(Double(value)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCompactBanner(_ value: Int) -> String {
        if abs(value) >= 10000 {
            return String(format: "%.1f萬", Double(value) / 10000.0)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func trailingStopPill(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: icon)
                .font(.warmCaption2())
                .foregroundStyle(color)
            Text(text)
                .font(.warmTertiary())
                .foregroundStyle(AppColor.textMain)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }

    /// 信號膠囊標籤
    private func signalPill(_ text: String, color: Color, filled: Bool = false) -> some View {
        Text(text)
            .font(.warmTertiary())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(filled ? color : color.opacity(0.12))
            .foregroundStyle(filled ? .white : color)
            .clipShape(Capsule())
    }
}

// MARK: - Flow Layout（自動換行佈局）

/// 水平排列子視圖，空間不足時自動換行
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

// MARK: - Sparkline View

/// 微型走勢線（7 日收盤價折線圖）
private struct SparklineView: View {
    let data: [Double]

    var body: some View {
        Canvas { context, size in
            guard data.count >= 2 else { return }
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = maxVal - minVal
            guard range > 0 else { return }

            let stepX = size.width / CGFloat(data.count - 1)

            var path = Path()
            for (i, value) in data.enumerated() {
                let x = stepX * CGFloat(i)
                let y = size.height - (CGFloat((value - minVal) / range) * size.height)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let isUp = (data.last ?? 0) >= (data.first ?? 0)
            let color = isUp ? AppColor.softUp : AppColor.softDown
            context.stroke(path, with: .color(color), lineWidth: 1.2)
        }
        .frame(width: 40, height: 20)
    }
}

#Preview {
    PortfolioListView()
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
