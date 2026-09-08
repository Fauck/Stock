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
                        displayName: vm.displayName(for: group.ticker),
                        highSinceBuy: vm.highSinceBuy[group.ticker],
                        institutionalData: vm.institutionalData[group.ticker],
                        sellRecommendation: vm.sellRecommendation(for: group.ticker, avgCost: group.weightedAverageCost)
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
                vm.loadData()
            }
            .onChange(of: investments) { _, newValue in
                vm.investments = newValue
                // 資料更新時重新載入（含首次 @Query 載入完成時）
                if !newValue.isEmpty && !vm.hasAnyPrice {
                    vm.loadData()
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
                // 重新整理即時價 + 技術指標 + 52週統計 + 法人
                Button {
                    vm.loadData(forceRefresh: true)
                } label: {
                    if vm.isFetchingPrices || vm.isFetchingSignals || vm.isFetchingWeekStats || vm.isFetchingInstitutional {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .disabled(vm.isFetchingPrices || vm.isFetchingSignals || vm.isFetchingWeekStats || vm.isFetchingInstitutional)
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
        let fees = TradingFeeSettings.load()
        let pl: Double? = currentPrice.map { group.unrealizedProfitLoss(currentPrice: $0, fees: fees) }
        // 損益色帶色
        let accentColor: Color = {
            guard let pl else { return AppColor.divider }
            return Color.profitLossColor(pl)
        }()

        return HStack(spacing: 0) {
            // ── 左側損益色帶 ──
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 0) {
                // ── 摘要列（始終顯示）──
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.toggleExpanded(group.ticker)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        // Row 1：名稱 + 代號（左）｜ 現價 + 分析按鈕（右）
                        HStack(alignment: .center, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(vm.displayName(for: group.ticker))
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColor.primary)
                                    .lineLimit(1)
                                Text(group.ticker)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppColor.textSecondary)
                            }

                            Spacer(minLength: 8)

                            if let price = currentPrice {
                                Text(String(format: "$%.2f", price))
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColor.textMain)
                            } else {
                                Text("--")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColor.textSecondary.opacity(0.3))
                            }

                            // 個股分析按鈕
                            Button { vm.openStockDetail(group) } label: {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColor.primary)
                                    .frame(width: 28, height: 28)
                                    .background(AppColor.primary.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        // Row 2：股數 · 均價（左）｜ 漲跌點數 & %（右）
                        HStack {
                            HStack(spacing: 0) {
                                Text(String(format: "%.0f股", group.totalQuantity))
                                    .foregroundStyle(AppColor.textMain)
                                Text("｜")
                                    .foregroundStyle(AppColor.divider)
                                Text(String(format: "均%.2f", group.weightedAverageCost))
                                    .foregroundStyle(AppColor.textSecondary)
                            }

                            Spacer(minLength: 8)

                            if let change = vm.dailyChangePoints[group.ticker],
                               let changePct = vm.dailyChangePercents[group.ticker] {
                                HStack(spacing: 3) {
                                    Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                        .font(.system(size: 7))
                                    Text(String(format: "%.2f (%.2f%%)", abs(change), abs(changePct)))
                                }
                                .foregroundStyle(Color.profitLossColor(change))
                            }
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .lineLimit(1)

                        // Row 3：持有天數（左）｜ 損益金額 & %（右）
                        HStack {
                            Text("\(group.holdingDays)天")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColor.textSecondary)

                            Spacer(minLength: 8)

                            if let price = currentPrice {
                                let plVal = group.unrealizedProfitLoss(currentPrice: price, fees: fees)
                                let pctVal = group.returnPercentage(currentPrice: price, fees: fees)
                                Text(String(format: "%@$%.0f (%@%.1f%%)", plVal >= 0 ? "+" : "", plVal, pctVal >= 0 ? "+" : "", pctVal))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.profitLossColor(plVal))
                            }
                        }
                        .lineLimit(1)

                        // 技術信號標籤列
                        if let signal = vm.technicalSignals[group.ticker] {
                            FlowLayout(spacing: 4) {
                                compactSignalBadges(signal, ticker: group.ticker, avgCost: group.weightedAverageCost)
                            }
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // ── 展開的詳細內容 ──
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        AppColor.divider.frame(height: 1)
                            .padding(.horizontal, 14)

                        // 數據格：市值 / 成本 / 損益 / 本日增減
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
                            .padding(.horizontal, 14)

                            // 本日增減
                            if let dailyChange = vm.dailyPLChange(for: group.ticker, quantity: group.totalQuantity) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AppColor.secondary)
                                    Text("本日增減")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(AppColor.textSecondary)
                                    Spacer()
                                    Text(String(format: "%@$%.0f", dailyChange >= 0 ? "+" : "", dailyChange))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.profitLossColor(dailyChange))
                                }
                                .padding(.horizontal, 14)
                            }

                            // 移動停利建議
                            trailingStopBanner(ticker: group.ticker, currentPrice: price, avgCost: group.weightedAverageCost)
                                .padding(.horizontal, 14)
                        }

                        // 法人買賣超摘要
                        if let inst = vm.institutionalData[group.ticker] {
                            institutionalBanner(inst)
                                .padding(.horizontal, 14)
                        }

                        // 操作列：現價輸入 + 按鈕
                        HStack(spacing: 8) {
                            // 現價手動修正
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColor.primary)
                                TextField(
                                    "現價",
                                    text: Binding(
                                        get: { vm.priceBinding(for: group.ticker) },
                                        set: { vm.setPrice($0, for: group.ticker) }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .frame(maxWidth: 110)

                            Spacer()

                            // 個股分析
                            Button { vm.openStockDetail(group) } label: {
                                Label("分析", systemImage: "chart.xyaxis.line")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(AppColor.primary)
                                    .background(AppColor.primary.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            // 盤中分析
                            NavigationLink(destination: IntradayAnalysisView(symbol: group.ticker)) {
                                Text("盤中")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(AppColor.secondary)
                                    .background(AppColor.secondary.opacity(0.10))
                                    .clipShape(Capsule())
                            }

                            // 整批賣出
                            Button { vm.selectGroupForSell(group) } label: {
                                Text("賣出")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(AppColor.softUp)
                                    .background(AppColor.softUp.opacity(0.10))
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
        }
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    /// 展開區塊的數據格子
    private func expandedMetricCell(title: String, value: String, subtitle: String? = nil, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppColor.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    /// 摺疊狀態下的精簡信號徽章（僅顯示重要觸發信號）
    @ViewBuilder
    private func compactSignalBadges(_ signal: TechnicalIndicators.SignalSummary, ticker: String, avgCost: Double) -> some View {
        // 均線交叉
        if let maCross = signal.maCross {
            signalPill(maCross.label, color: maCross == .goldenCross ? AppColor.softUp : AppColor.softDown)
        }
        // MACD 交叉
        if let macdSig = signal.macdSignal, let label = macdSig.label {
            signalPill(label, color: macdSig == .goldenCross ? AppColor.softUp : AppColor.softDown)
        }
        // 超買超賣
        if let rsiSig = signal.rsiSignal, let label = rsiSig.label {
            signalPill(label, color: rsiSig == .overbought ? AppColor.softUp : AppColor.softDown)
        }
        // KD 交叉
        if let kdjSig = signal.kdjSignal, let label = kdjSig.label {
            signalPill(label, color: kdjSig == .goldenCross ? AppColor.softUp : AppColor.softDown)
        }
        // 布林通道
        if let bbSig = signal.bollingerSignal, let label = bbSig.label {
            signalPill(label, color: bbSig == .nearLower ? AppColor.softDown : (bbSig == .nearUpper ? AppColor.softUp : AppColor.primary))
        }
        // 量能異動
        if let volSig = signal.volumeSignal, let label = volSig.label {
            signalPill(label, color: volSig == .surge ? AppColor.softUp : (volSig == .shrink ? AppColor.textSecondary : AppColor.secondary))
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
        // 法人買賣超連續天數
        if let inst = vm.institutionalData[ticker] {
            let fs = inst.foreignStreak
            if abs(fs) >= 2 {
                signalPill("外資連\(fs > 0 ? "買" : "賣")\(abs(fs))日",
                           color: fs > 0 ? AppColor.softUp : AppColor.softDown)
            }
            let ts = inst.trustStreak
            if abs(ts) >= 2 {
                signalPill("投信連\(ts > 0 ? "買" : "賣")\(abs(ts))日",
                           color: ts > 0 ? AppColor.softUp : AppColor.softDown)
            }
        }
        // 賣出建議（僅顯示偏空等級）
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
        .padding(10)
        .background(AppColor.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func institutionalCell(label: String, value: Int, streak: Int?) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
            Text("\(value >= 0 ? "+" : "")\(value)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.profitLossColor(Double(value)))
            if let streak, abs(streak) >= 2 {
                Text("連\(streak > 0 ? "買" : "賣")\(abs(streak))日")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(streak > 0 ? AppColor.secondary : AppColor.softDown)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 移動停利建議橫幅

    @ViewBuilder
    private func trailingStopBanner(ticker: String, currentPrice: Double, avgCost: Double) -> some View {
        if let high = vm.highSinceBuy[ticker], high > 0 {
            let pct = TradingFeeSettings.load().trailingStopPct
            let rawStop = high * (1 - pct / 100)
            // 停利線不低於買入均價（保本下限）
            let stopPrice = max(rawStop, avgCost)
            let drawdownPct = (high - currentPrice) / high * 100

            AppColor.divider.frame(height: 1)

            if currentPrice <= stopPrice {
                // 已跌破停利線
                trailingStopPill(
                    icon: "exclamationmark.triangle.fill",
                    color: AppColor.softDown,
                    text: String(format: "已跌破停利線 $%.1f（最高 $%.1f ↓%.1f%%）", stopPrice, high, drawdownPct)
                )
            } else if currentPrice <= stopPrice * 1.03 {
                // 接近停利線（3% 以內）
                trailingStopPill(
                    icon: "exclamationmark.circle.fill",
                    color: .orange,
                    text: String(format: "接近停利線 $%.1f（最高 $%.1f ↓%.1f%%）", stopPrice, high, drawdownPct)
                )
            } else {
                // 安全持有
                trailingStopPill(
                    icon: "shield.checkered",
                    color: AppColor.textSecondary,
                    text: String(format: "停利參考 $%.1f（最高 $%.1f）", stopPrice, high)
                )
            }
        }
    }

    private func trailingStopPill(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.warmCaption2())
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textMain)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }

    /// 信號膠囊標籤
    private func signalPill(_ text: String, color: Color, filled: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
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

#Preview {
    PortfolioListView()
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
