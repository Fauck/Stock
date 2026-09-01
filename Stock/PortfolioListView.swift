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

    @State private var vm = PortfolioListViewModel()

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
                        displayName: vm.displayName(for: group.ticker)
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
            .onAppear {
                vm.investments = investments
                vm.fetchAllPrices()
                vm.fetchTechnicalSignals()
                vm.fetchWeekStats()
            }
            .onChange(of: investments) { _, newValue in
                vm.investments = newValue
                // 資料更新時重新拉取即時價（含首次 @Query 載入完成時）
                if !newValue.isEmpty && !vm.hasAnyPrice {
                    vm.fetchAllPrices()
                }
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
            Text("請前往行事曆頁面新增買入紀錄")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
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
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundStyle(AppColor.primary)
                Text("投資總覽")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                // 重新整理即時價 + 技術指標 + 52週統計
                Button {
                    vm.fetchAllPrices()
                    vm.fetchTechnicalSignals()
                    vm.fetchWeekStats()
                } label: {
                    if vm.isFetchingPrices || vm.isFetchingSignals || vm.isFetchingWeekStats {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .disabled(vm.isFetchingPrices || vm.isFetchingSignals || vm.isFetchingWeekStats)
            }

            AppColor.divider.frame(height: 1)

            HStack {
                Text("總投資成本")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.0f", vm.totalCost))
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textMain)
            }

            if vm.hasAnyPrice {
                HStack {
                    Text("目前市值")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(String(format: "$%.0f", vm.totalMarketValue))
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textMain)
                }
                HStack {
                    Text("未實現損益")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(vm.totalPL >= 0 ? "+" : "")$\(vm.totalPL, specifier: "%.0f")")
                            .font(.warmSubheadline())
                            .fontWeight(.bold)
                            .foregroundStyle(Color.profitLossColor(vm.totalPL))
                        Text("(\(vm.totalReturnPct >= 0 ? "+" : "")\(vm.totalReturnPct, specifier: "%.1f")%)")
                            .font(.warmCaption())
                            .fontWeight(.medium)
                            .foregroundStyle(Color.profitLossColor(vm.totalPL))
                    }
                }

                // 本日總損益增減
                if let dailyChange = vm.totalDailyPLChange {
                    AppColor.divider.frame(height: 1)
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.secondary)
                            Text("本日損益增減")
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        Spacer()
                        Text("\(dailyChange >= 0 ? "+" : "")$\(dailyChange, specifier: "%.0f")")
                            .font(.warmSubheadline())
                            .fontWeight(.bold)
                            .foregroundStyle(Color.profitLossColor(dailyChange))
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 群組卡片

    private func groupCard(for group: PortfolioGroup) -> some View {
        let isExpanded = vm.isExpanded(group.ticker)
        let currentPrice = vm.currentPrice(for: group.ticker)

        return VStack(alignment: .leading, spacing: 0) {
            // ── 摘要列（始終顯示）──
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    vm.toggleExpanded(group.ticker)
                }
            } label: {
                HStack(spacing: 12) {
                    // 左：中文名稱（主）+ 代號（副）+ 技術信號
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.displayName(for: group.ticker))
                            .font(.warmHeadline())
                            .foregroundStyle(AppColor.primary)
                        HStack(spacing: 4) {
                            Text(group.ticker)
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                            if let signal = vm.technicalSignals[group.ticker] {
                                compactSignalBadges(signal, ticker: group.ticker)
                            }
                        }
                    }
                    .frame(minWidth: 60, alignment: .leading)

                    // 中：股數 + 均價
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f 股", group.totalQuantity))
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textMain)
                        Text(String(format: "均價 $%.2f", group.weightedAverageCost))
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    Spacer()

                    // 個股分析按鈕
                    Button {
                        vm.openStockDetail(group)
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 28, height: 28)
                            .background(AppColor.primary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    // 右：即時價 + 漲跌 + 損益
                    if let price = currentPrice {
                        let pl = group.unrealizedProfitLoss(currentPrice: price)
                        let pct = group.returnPercentage(currentPrice: price)
                        let change = vm.dailyChangePoints[group.ticker]
                        let changePct = vm.dailyChangePercents[group.ticker]
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "$%.2f", price))
                                .font(.warmCaption())
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.textMain)
                            // 當日漲跌
                            if let change, let changePct {
                                Text("\(change >= 0 ? "▲" : "▼")\(abs(change), specifier: "%.2f") (\(changePct >= 0 ? "+" : "")\(changePct, specifier: "%.2f")%)")
                                    .font(.warmCaption2())
                                    .foregroundStyle(Color.profitLossColor(change))
                            }
                            Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f") (\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%)")
                                .font(.warmCaption2())
                                .foregroundStyle(Color.profitLossColor(pl))
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "$%.0f", group.totalInvested))
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .foregroundStyle(AppColor.textMain)
                            Text("無即時價")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                        }
                    }

                    // 展開指示箭頭
                    Image(systemName: "chevron.right")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── 展開的詳細內容 ──
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    AppColor.divider.frame(height: 1)
                        .padding(.horizontal, 14)

                    // 即時價格 & 損益區塊
                    if let price = currentPrice {
                        let pl = group.unrealizedProfitLoss(currentPrice: price)
                        let pct = group.returnPercentage(currentPrice: price)
                        let marketValue = price * group.totalQuantity

                        VStack(spacing: 8) {
                            // 即時價格列
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.secondary)
                                    Text("即時價")
                                        .font(.warmCaption())
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "$%.2f", price))
                                        .font(.warmHeadline())
                                        .foregroundStyle(AppColor.textMain)
                                    // 當日漲跌點數 & %
                                    if let change = vm.dailyChangePoints[group.ticker],
                                       let changePct = vm.dailyChangePercents[group.ticker] {
                                        Text("\(change >= 0 ? "▲" : "▼")\(abs(change), specifier: "%.2f") (\(changePct >= 0 ? "+" : "")\(changePct, specifier: "%.2f")%)")
                                            .font(.warmCaption())
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.profitLossColor(change))
                                    }
                                }
                            }

                            // 市值 & 損益列
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("市值")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text(String(format: "$%.0f", marketValue))
                                        .font(.warmCaption())
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppColor.textMain)
                                }
                                Spacer()
                                VStack(alignment: .center, spacing: 2) {
                                    Text("成本")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text(String(format: "$%.0f", group.totalInvested))
                                        .font(.warmCaption())
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppColor.textMain)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("未實現損益")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f") (\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%)")
                                        .font(.warmCaption())
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.profitLossColor(pl))
                                }
                            }

                            // 本日損益增減（單一標的）
                            if let dailyChange = vm.dailyPLChange(for: group.ticker, quantity: group.totalQuantity) {
                                AppColor.divider.frame(height: 1)
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.warmCaption2())
                                            .foregroundStyle(AppColor.secondary)
                                        Text("本日增減")
                                            .font(.warmCaption2())
                                            .foregroundStyle(AppColor.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(dailyChange >= 0 ? "+" : "")$\(dailyChange, specifier: "%.0f")")
                                        .font(.warmCaption())
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.profitLossColor(dailyChange))
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.profitLossColor(pl).opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 14)
                    }

                    // 資訊徽章列
                    HStack {
                        WarmInfoBadge(title: "均價", value: String(format: "$%.2f", group.weightedAverageCost))
                        Spacer()
                        WarmInfoBadge(title: "筆數", value: "\(group.investments.count) 筆")
                        Spacer()
                        WarmInfoBadge(title: "持有", value: "\(group.holdingDays) 天")
                    }
                    .padding(.horizontal, 14)

                    // 現價手動修正 & 整批賣出
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                        Text("現價")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                        TextField(
                            "手動輸入",
                            text: Binding(
                                get: { vm.priceBinding(for: group.ticker) },
                                set: { vm.setPrice($0, for: group.ticker) }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: 100)
                        Spacer()

                        // 盤中分析
                        NavigationLink(destination: IntradayAnalysisView(symbol: group.ticker)) {
                            Text("盤中")
                                .font(.warmCaption2())
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(AppColor.secondary)
                                .background(AppColor.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        // 整批賣出
                        Button {
                            vm.selectGroupForSell(group)
                        } label: {
                            Text("整批賣出")
                                .font(.warmCaption2())
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(AppColor.softUp)
                                .background(AppColor.softUp.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)

                    // 買入明細
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
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
                        let pl = investment.unrealizedProfitLoss(currentPrice: price)
                        let pct = investment.returnPercentage(currentPrice: price)
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
                        Text("賣出")
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
        .padding(10)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 技術指標信號顯示

    /// 摺疊狀態下的精簡信號徽章
    @ViewBuilder
    private func compactSignalBadges(_ signal: TechnicalIndicators.SignalSummary, ticker: String) -> some View {
        // 只顯示重要信號：超買超賣 或 KD 交叉
        if let rsiSig = signal.rsiSignal, let label = rsiSig.label {
            signalPill(label, color: rsiSig == .overbought ? AppColor.softUp : AppColor.softDown)
        }
        if let kdjSig = signal.kdjSignal, let label = kdjSig.label {
            signalPill(label, color: kdjSig == .goldenCross ? AppColor.secondary : AppColor.softDown)
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
        .padding(10)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 52 週區間顯示

    /// 展開狀態下的 52 週高低點區間
    private func weekStatsView(
        stats: PortfolioListViewModel.WeekStats,
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
        .padding(10)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    /// 信號膠囊標籤
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

#Preview {
    PortfolioListView()
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
